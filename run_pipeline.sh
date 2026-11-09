#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="$SCRIPT_DIR/check_poc_environment.sh"
TAURUS_SCENARIO="$SCRIPT_DIR/taurus-esxi-poc.yml"
ARTIFACT_ROOT="$SCRIPT_DIR/artifacts"

log() {
    printf '\n[PIPELINE] %s\n' "$1"
}

fail() {
    printf '\n[ERRO] %s\n' "$1" >&2
    exit 1
}

POST_AUDIT_REQUIRED=0

pipeline_exit() {
    local pipeline_status=$?
    local audit_status=0

    trap - EXIT

    if [[ "$POST_AUDIT_REQUIRED" -eq 1 ]]; then
        log "[ETAPA 5/5] Auditoria de integridade pós-carga"

        if "$CHECK_SCRIPT"; then
            log "Auditoria pós-carga concluída."
        else
            audit_status=$?

            printf '\n[ERRO] Auditoria pós-carga falhou (código %s).\n' \
                "$audit_status" >&2

            if [[ "$pipeline_status" -eq 0 ]]; then
                pipeline_status="$audit_status"
                [[ "$pipeline_status" -ne 0 ]] || pipeline_status=1
            fi
        fi

        log "Artefatos preservados em: $ARTIFACT_DIR"
        log "Nenhum serviço ou contêiner foi encerrado."
    fi

    if [[ "$pipeline_status" -eq 0 ]]; then
        log "Pipeline concluída com sucesso."
    else
        log "Pipeline encerrada com erro (código $pipeline_status)."
    fi

    exit "$pipeline_status"
}

trap pipeline_exit EXIT

for cmd in bzt curl jq python3 mktemp; do
    command -v "$cmd" >/dev/null 2>&1 ||
        fail "Dependência obrigatória ausente: $cmd"
done

[[ -x "$CHECK_SCRIPT" ]] ||
    fail "Script de auditoria ausente ou sem permissão de execução: $CHECK_SCRIPT"

[[ -f "$TAURUS_SCENARIO" ]] ||
    fail "Cenário Taurus não encontrado: $TAURUS_SCENARIO"

grid_status() {
    curl --silent --show-error --fail \
        --connect-timeout 3 \
        --max-time 8 \
        http://127.0.0.1:4444/status
}

count_active_sessions() {
    jq -er '
        if (.value.nodes | type) != "array" then
            error("Grid não retornou um array de Nodes")
        elif (all(.value.nodes[]; ((.sessions // []) | type) == "array") | not) then
            error("Grid retornou uma lista de sessões inválida")
        else
            [.value.nodes[].sessions // [] | length] | add // 0
        end
    '
}

cd "$SCRIPT_DIR"

log "[ETAPA 1/5] Auditoria de prontidão pré-carga"
"$CHECK_SCRIPT"

log "Preparando diretório exclusivo de artefatos"
mkdir -p "$ARTIFACT_ROOT"

ARTIFACT_DIR="$(mktemp -d "$ARTIFACT_ROOT/taurus-run-XXXXXXXX")"

log "Diretório desta execução: $ARTIFACT_DIR"

log "[ETAPA 2/5] Execução da campanha Taurus"
POST_AUDIT_REQUIRED=1
bzt -o "settings.artifacts-dir=$ARTIFACT_DIR" "$TAURUS_SCENARIO"

log "[ETAPA 3/5] Validação do relatório LDJSON"

shopt -s nullglob
REPORT_FILES=( "$ARTIFACT_DIR"/*.ldjson )
shopt -u nullglob

if [[ "${#REPORT_FILES[@]}" -ne 1 ]]; then
    fail "Esperado exatamente um relatório LDJSON; encontrados: ${#REPORT_FILES[@]}. Artefatos preservados em: $ARTIFACT_DIR"
fi

REPORT_FILE="${REPORT_FILES[0]}"

[[ -s "$REPORT_FILE" ]] ||
    fail "Relatório LDJSON vazio: $REPORT_FILE"

python3 - "$REPORT_FILE" <<'PY'
import json
import sys

report_file = sys.argv[1]

sample_count = 0
passed_count = 0
failed_samples = []

def inspect_sample(sample, location):
    global sample_count, passed_count

    if not isinstance(sample, dict):
        raise ValueError(f"{location}: amostra não é um objeto JSON")

    status = sample.get("status")

    if not isinstance(status, str):
        raise ValueError(f"{location}: status ausente ou inválido")

    sample_count += 1

    if status == "PASSED":
        passed_count += 1
    else:
        failed_samples.append((location, status))

    subsamples = sample.get("subsamples", [])

    if not isinstance(subsamples, list):
        raise ValueError(f"{location}: subsamples não é uma lista")

    for index, subsample in enumerate(subsamples):
        inspect_sample(subsample, f"{location}.subsamples[{index}]")


try:
    with open(report_file, "r", encoding="utf-8") as report:
        for line_number, line in enumerate(report, start=1):
            if not line.strip():
                raise ValueError(
                    f"Linha {line_number}: linha vazia no relatório"
                )

            try:
                sample = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(
                    f"Linha {line_number}: JSON inválido: {exc}"
                ) from exc

            inspect_sample(sample, f"linha {line_number}")

    if sample_count == 0:
        raise ValueError("Relatório não contém amostras")

except (OSError, ValueError) as exc:
    print(f"[ERRO] Validação LDJSON: {exc}", file=sys.stderr)
    sys.exit(1)

print(f"[LDJSON] Total de amostras: {sample_count}")
print(f"[LDJSON] Amostras PASSED: {passed_count}")

if failed_samples:
    print(
        f"[ERRO] Amostras com status diferente de PASSED: "
        f"{len(failed_samples)}",
        file=sys.stderr
    )

    for location, status in failed_samples:
        print(f"  - {location}: {status}", file=sys.stderr)

    sys.exit(1)

print("[PASS] Todas as amostras estão com status PASSED")
PY

log "Relatório aprovado: $REPORT_FILE"

log "[ETAPA 4/5] Verificação das sessões Selenium"

GRID_RESPONSE="$(grid_status)" ||
    fail "Não foi possível consultar o estado do Selenium Grid."

SESSIONS_COUNT="$(printf '%s' "$GRID_RESPONSE" | count_active_sessions)" ||
    fail "Não foi possível validar a quantidade de sessões."

if [[ "$SESSIONS_COUNT" -ne 0 ]]; then
    fail "Existem $SESSIONS_COUNT sessão(ões) ativa(s) no Grid após a campanha."
fi

log "Nenhuma sessão ativa retida no Grid."

