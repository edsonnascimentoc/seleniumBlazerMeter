#!/usr/bin/env bash
# Auditoria pré/pós-carga do ambiente PoC Taurus + Selenium Grid + observabilidade.
# Host de referência: loadtester-lab (Debian 13 trixie).

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
ERRORS=0
WARNINGS=0

log_pass() { printf '[%bPASS%b] %s\n' "$GREEN" "$NC" "$1"; }
log_fail() { printf '[%bFAIL%b] %s\n' "$RED" "$NC" "$1"; ERRORS=$((ERRORS + 1)); }
log_warn() { printf '[%bWARN%b] %s\n' "$YELLOW" "$NC" "$1"; WARNINGS=$((WARNINGS + 1)); }

require_cmd() {
  if command -v "$1" >/dev/null 2>&1; then return 0; fi
  log_fail "Dependência obrigatória ausente: $1"
  return 1
}

http_body() {
  curl --silent --show-error --fail --connect-timeout "${2:-3}" --max-time "${3:-10}" "$1" 2>/dev/null
}

echo "======================================================================"
echo "      AUDITORIA DO AMBIENTE POC (loadtester-lab)"
echo "======================================================================"

echo
echo "--- [1/5] Host Debian, recursos e concorrência ---"
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${PRETTY_NAME:-}" == *Debian* ]]; then
    log_pass "Sistema operacional: ${PRETTY_NAME}"
  else
    log_warn "Sistema operacional diferente do host de referência: ${PRETTY_NAME:-desconhecido}"
  fi
else
  log_fail "Não foi possível ler /etc/os-release."
fi

CPU_COUNT=$(nproc 2>/dev/null || printf '0')
RAM_MIB=$(awk '/^MemTotal:/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null || printf '0')
if [[ "$CPU_COUNT" -gt 0 && "$RAM_MIB" -gt 0 ]]; then
  log_pass "Recursos detectados: ${CPU_COUNT} vCPUs / ${RAM_MIB} MiB RAM"
else
  log_fail "Não foi possível detectar CPU e memória."
fi

LOAD_1MIN=$(awk '{print $1}' /proc/loadavg 2>/dev/null || printf 'desconhecido')
if [[ "$LOAD_1MIN" != desconhecido ]]; then
  log_pass "Load Average (1m): $LOAD_1MIN"
  LOAD_INT=${LOAD_1MIN%%.*}
  if [[ "$CPU_COUNT" -gt 0 && "$LOAD_INT" -gt "$CPU_COUNT" ]]; then
    log_warn "Load average inteiro excede a quantidade de vCPUs; interpretar como possível pressão transitória."
  fi
else
  log_warn "Load average indisponível."
fi

if pgrep -af '[f]irefox' >/dev/null 2>&1; then
  log_warn "Firefox do operador está ativo e pode consumir recursos durante a campanha."
else
  log_pass "Nenhum processo Firefox concorrente detectado."
fi

echo
echo "--- [2/5] Docker Engine e ferramentas de diagnóstico ---"
for cmd in docker curl jq; do require_cmd "$cmd" || true; done

if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet docker; then
  DOCKER_VER=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
  log_pass "Docker Engine ativo (${DOCKER_VER:-versão não identificada})."
else
  log_fail "Docker Engine não está ativo ou systemctl indisponível."
fi

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  log_pass "Acesso ao Docker Engine pelo usuário atual confirmado."
else
  log_fail "Sem acesso ao Docker Engine; conferir serviço e permissões do socket."
fi

echo
echo "--- [3/5] Selenium Grid 4: readiness e Nodes ---"
GRID_STATUS=$(http_body "http://127.0.0.1:4444/status" 3 8 || true)
if [[ -z "$GRID_STATUS" ]] || ! printf '%s' "$GRID_STATUS" | jq -e '.value.ready | type == "boolean"' >/dev/null 2>&1; then
  log_fail "Selenium Hub inacessível ou resposta /status inválida."
else
  GRID_READY=$(printf '%s' "$GRID_STATUS" | jq -r '.value.ready')
  NODE_COUNT=$(printf '%s' "$GRID_STATUS" | jq -r '(.value.nodes // []) | length')
  if [[ "$GRID_READY" == true ]]; then
    log_pass "Selenium Hub ready=true; Nodes registrados: $NODE_COUNT."
  else
    log_fail "Selenium Hub respondeu, mas ready=false."
  fi
  if [[ "$NODE_COUNT" -ge 2 ]]; then
    log_pass "Quantidade de Nodes atende à PoC (mínimo 2)."
  else
    log_fail "Esperados pelo menos 2 Nodes; encontrados: $NODE_COUNT."
  fi
  DOWN_NODES=$(printf '%s' "$GRID_STATUS" | jq '[.value.nodes[]? | select(.availability != "UP")] | length')
  if [[ "$DOWN_NODES" -eq 0 && "$NODE_COUNT" -ge 2 ]]; then
    log_pass "Todos os Nodes registrados estão com availability=UP."
  else
    log_fail "$DOWN_NODES Node(s) sem availability=UP."
  fi
fi

echo
echo "--- [4/5] PID 1 e processos zombies nos Chrome Nodes ---"
for NODE in chrome-node-1 chrome-node-2; do
  if ! command -v docker >/dev/null 2>&1 || ! docker inspect -f '{{.State.Running}}' "$NODE" 2>/dev/null | grep -qx true; then
    log_fail "Container $NODE não está em execução ou Docker inacessível."
    continue
  fi

  PID1_COMM=$(docker exec "$NODE" sh -c 'ps -p 1 -o comm=' 2>/dev/null | tr -d '\r' || true)
  if [[ "$PID1_COMM" == *init* || "$PID1_COMM" == *tini* ]]; then
    log_pass "$NODE: PID 1 gerenciado por init ($PID1_COMM)."
  else
    log_fail "$NODE: PID 1 inesperado ('$PID1_COMM'); verificar init: true."
  fi

  if ZOMBIE_OUTPUT=$(docker exec "$NODE" sh -c "ps -eo stat=,args= | awk '\$1 ~ /^Z/ {print}'" 2>/dev/null); then
    if [[ -z "$ZOMBIE_OUTPUT" ]]; then
      log_pass "$NODE: nenhum processo zombie detectado."
    else
      ZOMBIE_COUNT=$(printf '%s\n' "$ZOMBIE_OUTPUT" | wc -l)
      log_fail "$NODE: $ZOMBIE_COUNT processo(s) zombie(s) detectado(s): $ZOMBIE_OUTPUT"
    fi
  else
    log_fail "$NODE: não foi possível inspecionar a tabela de processos."
  fi
done

echo
echo "--- [5/5] Exporters, Prometheus e conectividade ESXi ---"
NODE_METRICS=$(http_body "http://127.0.0.1:9100/metrics" 2 8 || true)
if [[ "$NODE_METRICS" == *"node_"* ]]; then
  log_pass "Node Exporter responde com métricas node_*."
else
  log_fail "Node Exporter indisponível ou sem métricas node_*."
fi

CADVISOR_METRICS=$(http_body "http://127.0.0.1:8080/metrics" 2 8 || true)
if [[ "$CADVISOR_METRICS" == *"container_"* ]]; then
  log_pass "cAdvisor responde com métricas container_*."
else
  log_fail "cAdvisor indisponível ou sem métricas container_*."
fi

PROM_TARGETS=$(http_body "http://127.0.0.1:9090/api/v1/targets" 3 8 || true)
if [[ -n "$PROM_TARGETS" ]] && printf '%s' "$PROM_TARGETS" | jq -e '.status == "success" and (.data.activeTargets | type == "array")' >/dev/null 2>&1; then
  TARGET_COUNT=$(printf '%s' "$PROM_TARGETS" | jq '.data.activeTargets | length')
  UNHEALTHY=$(printf '%s' "$PROM_TARGETS" | jq '[.data.activeTargets[] | select(.health != "up")] | length')
  if [[ "$TARGET_COUNT" -gt 0 && "$UNHEALTHY" -eq 0 ]]; then
    log_pass "Prometheus: $TARGET_COUNT alvo(s) ativo(s), todos health=up."
  else
    log_fail "Prometheus: $TARGET_COUNT alvo(s), $UNHEALTHY com health diferente de up."
  fi
else
  log_fail "Prometheus API /api/v1/targets inacessível ou resposta inválida."
fi

HTTP_CODE=000
if command -v docker >/dev/null 2>&1; then
  HTTP_CODE=$(docker exec chrome-node-1 curl -sk --connect-timeout 5 --max-time 10 -o /dev/null -w '%{http_code}' https://10.1.100.102/ 2>/dev/null || printf '000')
fi
if [[ "$HTTP_CODE" == 200 ]]; then
  log_pass "Chrome Node acessa ESXi com HTTP 200."
else
  log_fail "Acesso do chrome-node-1 ao ESXi retornou HTTP $HTTP_CODE (esperado 200)."
fi

echo "======================================================================"
if [[ "$ERRORS" -eq 0 ]]; then
  printf '%bRESULTADO: APROVADO%b — %s falha(s), %s aviso(s).\n' "$GREEN" "$NC" "$ERRORS" "$WARNINGS"
  echo "======================================================================"
  exit 0
fi
printf '%bRESULTADO: REPROVADO%b — %s falha(s), %s aviso(s).\n' "$RED" "$NC" "$ERRORS" "$WARNINGS"
echo "Corrija as falhas antes de iniciar a campanha Taurus."
echo "======================================================================"
exit 1
