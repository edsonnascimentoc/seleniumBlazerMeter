#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# Executar na raiz do repositório seleniumBlazerMeter.
GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:3000}"
GRAFANA_URL="${GRAFANA_URL%/}"

BASE_DIR="dashboards/originals"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_DIR="${BASE_DIR}/export-${TIMESTAMP}"

DASHBOARDS=(
  "poc-selenium-infra"
  "investigacao-esxi-latencia"
  "qaops-selenium-perf"
)

for cmd in curl jq sha256sum; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERRO: comando obrigatório não encontrado: $cmd" >&2
    exit 1
  fi
done

if [[ ! -f "docker-compose.yml" || ! -f "README.md" ]]; then
  echo "ERRO: execute o script na raiz do repositório." >&2
  exit 1
fi

if [[ -e "$OUTPUT_DIR" ]]; then
  echo "ERRO: diretório de saída já existe: $OUTPUT_DIR" >&2
  exit 1
fi

printf "Token de serviço Grafana (não será gravado no arquivo): "
read -r -s GRAFANA_TOKEN
printf "\n"

if [[ -z "$GRAFANA_TOKEN" ]]; then
  echo "ERRO: token não informado." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo
echo "===== EXPORTAÇÃO DOS DASHBOARDS ====="
echo "Grafana: $GRAFANA_URL"
echo "Destino: $OUTPUT_DIR"
echo

for uid in "${DASHBOARDS[@]}"; do
  echo "Exportando UID: $uid"

  RESPONSE="${OUTPUT_DIR}/${uid}.api-response.json"
  DASHBOARD="${OUTPUT_DIR}/${uid}.json"

  if ! printf 'header = "Authorization: Bearer %s"\n' "$GRAFANA_TOKEN" |
    curl --config - \
      --fail \
      --silent \
      --show-error \
      "${GRAFANA_URL}/api/dashboards/uid/${uid}" \
      -o "$RESPONSE"; then
    echo "ERRO: falha ao consultar dashboard $uid" >&2
    exit 1
  fi

  if ! jq -e --arg uid "$uid" \
    '.dashboard.uid == $uid' "$RESPONSE" >/dev/null; then
    echo "ERRO: UID retornado não corresponde a $uid" >&2
    exit 1
  fi

  jq '.dashboard' "$RESPONSE" > "$DASHBOARD"

  TITLE="$(jq -r '.dashboard.title' "$RESPONSE")"
  VERSION="$(jq -r '.dashboard.version' "$RESPONSE")"

  echo "  Título: $TITLE"
  echo "  Versão: $VERSION"
  echo "  JSON: validado"
done

jq -n \
  --arg exported_at "$(date --iso-8601=seconds)" \
  --arg grafana_url "$GRAFANA_URL" \
  --argjson dashboards "$(
    for uid in "${DASHBOARDS[@]}"; do
      jq -c --arg uid "$uid" \
        '{uid: $uid, title: .dashboard.title,
          version: .dashboard.version}' \
        "${OUTPUT_DIR}/${uid}.api-response.json"
    done | jq -s .
  )" \
  '{
    exported_at: $exported_at,
    grafana_url: $grafana_url,
    dashboards: $dashboards
  }' > "${OUTPUT_DIR}/manifest.json"

(
  cd "$OUTPUT_DIR"
  sha256sum ./*.json > SHA256SUMS
)

echo
echo "===== RESULTADO ====="
echo "Diretório: $OUTPUT_DIR"
echo "Dashboards exportados: ${#DASHBOARDS[@]}"
echo
cat "${OUTPUT_DIR}/manifest.json"
echo
echo "===== SHA-256 ====="
cat "${OUTPUT_DIR}/SHA256SUMS"
