#!/bin/bash
# Teste de carga — order-service
# Uso: ./test.sh [rps] [duração_segundos] [workers]
# Exemplos:
#   ./test.sh           → 100 rps, 30s, 10 workers (padrão)
#   ./test.sh 1000 60   → 1000 rps, 60s
#   ./test.sh 5000 30 50 → 5000 rps, 30s, 50 workers

set -euo pipefail

# ── Configuração ────────────────────────────────────────────────────────────
BASE_URL="http://localhost:8080"
TARGET_RPS="${1:-100}"
DURATION="${2:-30}"
WORKERS="${3:-10}"

SUCCESS_LOG=$(mktemp)
ERROR_LOG=$(mktemp)
LATENCY_LOG=$(mktemp)
trap 'rm -f "$SUCCESS_LOG" "$ERROR_LOG" "$LATENCY_LOG"' EXIT

# ── Cores ───────────────────────────────────────────────────────────────────
G='\033[0;32m' R='\033[0;31m' Y='\033[1;33m' C='\033[0;36m' NC='\033[0m'

# ── Verificação de dependências ─────────────────────────────────────────────
for cmd in curl awk bc; do
  command -v "$cmd" &>/dev/null || { echo "Dependência ausente: $cmd"; exit 1; }
done

# ── Health check ─────────────────────────────────────────────────────────────
if ! curl -sf "$BASE_URL/actuator/health" | grep -q '"UP"'; then
  echo -e "${R}Serviço não está UP. Inicie com: docker-compose up -d${NC}"
  exit 1
fi

# ── Workers ──────────────────────────────────────────────────────────────────
# Cada worker envia requisições em loop até END_TIME.
# 95% sucesso, 5% erro intencional (validação).
worker() {
  local id="$1"
  local end="$2"
  local interval
  interval=$(awk "BEGIN{printf \"%.4f\", 1/($TARGET_RPS/$WORKERS)}")

  while (( $(date +%s) < end )); do
    local t0; t0=$(date +%s%3N)

    if (( RANDOM % 100 < 95 )); then
      local status
      status=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$BASE_URL/api/orders" \
        -H "Content-Type: application/json" \
        -d "{
          \"orderNumber\": \"T-$(date +%s%N)-$id\",
          \"supplierId\":  \"SUP-$((RANDOM % 10 + 1))\",
          \"productId\":   \"PROD-$((RANDOM % 50 + 1))\",
          \"quantity\":    $((RANDOM % 20 + 1)),
          \"unitPrice\":   $((RANDOM % 500 + 1)).$((RANDOM % 99 + 10))
        }")

      local t1; t1=$(date +%s%3N)
      echo $(( t1 - t0 )) >> "$LATENCY_LOG"

      if [[ "$status" == "201" ]]; then
        echo 1 >> "$SUCCESS_LOG"
      else
        echo 1 >> "$ERROR_LOG"
      fi
    else
      # Requisição inválida para gerar erro controlado
      curl -s -o /dev/null \
        -X POST "$BASE_URL/api/orders" \
        -H "Content-Type: application/json" \
        -d '{"orderNumber":"","quantity":-1}' || true
      echo 1 >> "$ERROR_LOG"
    fi

    sleep "$interval" 2>/dev/null || true
  done
}

# ── Início ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${C}Teste de carga — order-service${NC}"
echo "RPS alvo: $TARGET_RPS | Duração: ${DURATION}s | Workers: $WORKERS"
echo ""

START=$(date +%s)
END=$(( START + DURATION ))

for i in $(seq 1 "$WORKERS"); do
  worker "$i" "$END" &
done

# ── Monitor em tempo real ────────────────────────────────────────────────────
while (( $(date +%s) < END )); do
  sleep 1
  local_elapsed=$(( $(date +%s) - START ))
  ok=$(wc -l < "$SUCCESS_LOG" 2>/dev/null || echo 0)
  err=$(wc -l < "$ERROR_LOG"  2>/dev/null || echo 0)
  total=$(( ok + err ))
  rps=$(( total / (local_elapsed > 0 ? local_elapsed : 1) ))
  rate=$(awk "BEGIN{printf \"%.1f\", ($total>0) ? $err*100/$total : 0}")
  lat=$(awk '{s+=$1} END{printf "%.0f", (NR>0)?s/NR:0}' "$LATENCY_LOG" 2>/dev/null || echo 0)

  printf "\r[%2ds] rps: ${C}%4d${NC}  ok: ${G}%5d${NC}  err: ${R}%4d${NC}  erro: ${Y}%5s%%${NC}  lat_avg: %dms   " \
    "$local_elapsed" "$rps" "$ok" "$err" "$rate" "$lat"
done
echo ""

wait

# ── Resultado final ──────────────────────────────────────────────────────────
TOTAL_TIME=$(( $(date +%s) - START ))
OK_TOTAL=$(wc -l < "$SUCCESS_LOG" 2>/dev/null || echo 0)
ERR_TOTAL=$(wc -l < "$ERROR_LOG"  2>/dev/null || echo 0)
TOTAL=$(( OK_TOTAL + ERR_TOTAL ))

echo ""
echo "─────────────────────────────────────"
printf "Total:       %d req em %ds\n" "$TOTAL" "$TOTAL_TIME"
printf "RPS real:    %d\n" "$(( TOTAL / (TOTAL_TIME > 0 ? TOTAL_TIME : 1) ))"
printf "Sucesso:     %d\n" "$OK_TOTAL"
printf "Erro:        %d  (%.1f%%)\n" "$ERR_TOTAL" \
  "$(awk "BEGIN{printf \"%.1f\", ($TOTAL>0)?$ERR_TOTAL*100/$TOTAL:0}")"

# Percentis de latência
if [[ -s "$LATENCY_LOG" ]]; then
  echo ""
  echo "Latência (ms):"
  sort -n "$LATENCY_LOG" | awk -v n="$(wc -l < "$LATENCY_LOG")" '
    BEGIN { min=9999; sum=0 }
    {
      sum += $1
      if ($1 < min) min = $1
      max = $1
      lines[NR] = $1
    }
    END {
      avg = sum / NR
      p50 = lines[int(n*0.50)+1]
      p95 = lines[int(n*0.95)+1]
      p99 = lines[int(n*0.99)+1]
      printf "  min=%dms  p50=%dms  p95=%dms  p99=%dms  max=%dms  avg=%.0fms\n",
             min, p50, p95, p99, max, avg
    }'
fi

echo "─────────────────────────────────────"
echo "Grafana: http://localhost:3000  (admin/admin)"