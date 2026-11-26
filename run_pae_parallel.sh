#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-$SCRIPT_DIR/artifacts}"
SCENARIO_A="$SCRIPT_DIR/taurus-pae-a.yml"
SCENARIO_B="$SCRIPT_DIR/taurus-pae-b.yml"
TEST_A="test_sessao_pae_a"
TEST_B="test_sessao_pae_b"

log() { printf '\n[PAE-PARALLEL] %s\n' "$1"; }
fail() { printf '\n[ERRO] %s\n' "$1" >&2; }

BZT_BIN="${BZT_BIN:-$(command -v bzt || true)}"
[[ -n "$BZT_BIN" && -x "$BZT_BIN" ]] || {
    fail "Taurus CLI (bzt) não encontrado. Ajuste PATH ou BZT_BIN."
    exit 1
}

for cmd in curl jq python3 mktemp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        fail "Dependência obrigatória ausente: $cmd"
        exit 1
    }
done

for file in "$SCENARIO_A" "$SCENARIO_B"; do
    [[ -f "$file" ]] || { fail "Manifesto ausente: $file"; exit 1; }
done

cd "$SCRIPT_DIR"

# O runner Taurus precisa localizar pages/ e tests/.
PYTHONPATH_VALUE="$SCRIPT_DIR"
if [[ -n "${BZT_PYTHONPATH:-}" ]]; then
    PYTHONPATH_VALUE="$PYTHONPATH_VALUE:$BZT_PYTHONPATH"
fi
if [[ -n "${PYTHONPATH:-}" ]]; then
    PYTHONPATH_VALUE="$PYTHONPATH_VALUE:$PYTHONPATH"
fi
export PYTHONPATH="$PYTHONPATH_VALUE"

grid_status() {
    curl --silent --show-error --fail --connect-timeout 3 --max-time 8 \
        http://127.0.0.1:4444/status
}

log "Validando Selenium Grid."
GRID_BEFORE="$(grid_status)" || {
    fail "Grid indisponível em http://127.0.0.1:4444/status."
    exit 1
}

if ! printf '%s' "$GRID_BEFORE" | jq -e '
    (.value.ready == true)
    and ([.value.nodes[]? | select(.availability == "UP")] | length >= 2)
    and ([.value.nodes[]?.slots[]? | select(.session == null)] | length >= 2)
' >/dev/null; then
    fail "Grid precisa estar pronto, com dois Nodes UP e dois slots livres."
    printf '%s\n' "$GRID_BEFORE" | jq -C . >&2 || true
    exit 1
fi

mkdir -p "$ARTIFACT_ROOT"
RUN_DIR="$(mktemp -d "$ARTIFACT_ROOT/pae-parallel-XXXXXXXX")"
DIR_A="$RUN_DIR/a"
DIR_B="$RUN_DIR/b"
mkdir -p "$DIR_A/taurus" "$DIR_B/taurus"

log "Artefatos: $RUN_DIR"
log "Iniciando dois processos Taurus independentes."

run_taurus() {
    local scenario="$1" artifact_dir="$2" log_file="$3"
    "$BZT_BIN" -o "settings.artifacts-dir=$artifact_dir" "$scenario" \
        >"$log_file" 2>&1
}

run_taurus "$SCENARIO_A" "$DIR_A/taurus" "$DIR_A/taurus-console.log" &
PID_A=$!
run_taurus "$SCENARIO_B" "$DIR_B/taurus" "$DIR_B/taurus-console.log" &
PID_B=$!

log "Processos iniciados: A=$PID_A; B=$PID_B."
STATUS_A=0
STATUS_B=0

if wait "$PID_A"; then
    log "Taurus A terminou com código 0."
else
    STATUS_A=$?
    fail "Taurus A terminou com código $STATUS_A."
fi

if wait "$PID_B"; then
    log "Taurus B terminou com código 0."
else
    STATUS_B=$?
    fail "Taurus B terminou com código $STATUS_B."
fi

validate_report() {
    local artifact_dir="$1" expected_test="$2"

    python3 - "$artifact_dir" "$expected_test" <<'PY'
import json
import pathlib
import sys

artifact_dir = pathlib.Path(sys.argv[1])
expected_test = sys.argv[2]
reports = sorted(artifact_dir.rglob("*.ldjson"))

if len(reports) != 1:
    print(f"[ERRO] Esperado um LDJSON; encontrados: {len(reports)}", file=sys.stderr)
    raise SystemExit(1)

samples = []
try:
    with reports[0].open("r", encoding="utf-8") as stream:
        for line_number, line in enumerate(stream, start=1):
            if not line.strip():
                raise ValueError(f"linha {line_number} vazia")
            sample = json.loads(line)
            if not isinstance(sample, dict):
                raise ValueError(f"linha {line_number}: amostra não é objeto")
            samples.append(sample)
except (OSError, ValueError, json.JSONDecodeError) as exc:
    print(f"[ERRO] Relatório inválido: {exc}", file=sys.stderr)
    raise SystemExit(1)

if len(samples) != 1:
    print(f"[ERRO] Esperada uma amostra; encontradas: {len(samples)}", file=sys.stderr)
    raise SystemExit(1)

sample = samples[0]
if sample.get("status") != "PASSED":
    print(f"[ERRO] Status da amostra: {sample.get('status')!r}", file=sys.stderr)
    raise SystemExit(1)
if sample.get("test_case") != expected_test:
    print(f"[ERRO] Caso inesperado: {sample.get('test_case')!r}", file=sys.stderr)
    raise SystemExit(1)

duration = sample.get("duration")
if not isinstance(duration, (int, float)) or duration < 0:
    print("[ERRO] Duração ausente ou inválida.", file=sys.stderr)
    raise SystemExit(1)

print(f"[PASS] {expected_test}: PASSED; duração Taurus: {duration:.3f}s")
print(f"[LDJSON] {reports[0]}")
PY
}

VALIDATION_STATUS=0
log "Validando relatório A."
validate_report "$DIR_A/taurus" "$TEST_A" || VALIDATION_STATUS=1
log "Validando relatório B."
validate_report "$DIR_B/taurus" "$TEST_B" || VALIDATION_STATUS=1

log "Verificando sessões remanescentes no Grid."
GRID_AFTER="$(grid_status)" || {
    fail "Não foi possível consultar o Grid após os testes."
    GRID_AFTER=""
    VALIDATION_STATUS=1
}

if [[ -n "$GRID_AFTER" ]]; then
    ACTIVE_SESSIONS="$(printf '%s' "$GRID_AFTER" | jq -er '
        if (.value.nodes | type) != "array" then
            error("lista de Nodes inválida")
        elif (all(.value.nodes[]; ((.slots // []) | type) == "array") | not) then
            error("lista de slots inválida")
        else
            [.value.nodes[].slots[]?.session | select(. != null)] | length
        end
    ')" || {
        fail "Não foi possível contar sessões ativas."
        ACTIVE_SESSIONS="-1"
        VALIDATION_STATUS=1
    }

    if [[ "$ACTIVE_SESSIONS" != "0" ]]; then
        fail "Grid apresenta $ACTIVE_SESSIONS sessão(ões) ativas."
        VALIDATION_STATUS=1
    else
        log "Nenhuma sessão ativa remanescente."
    fi
fi

log "Log A: $DIR_A/taurus-console.log"
log "Log B: $DIR_B/taurus-console.log"
log "Artefatos preservados em: $RUN_DIR"

if [[ "$STATUS_A" -ne 0 || "$STATUS_B" -ne 0 || "$VALIDATION_STATUS" -ne 0 ]]; then
    fail "Execução paralela PAE REPROVADA. Consulte os artefatos preservados."
    exit 1
fi

log "Execução paralela PAE APROVADA pelos critérios automatizados."
