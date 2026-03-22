#!/bin/bash
# Teste progressivo — descobre o limite sustentável da aplicação
# Aumenta o RPS em estágios e para quando erro > threshold ou latência > threshold

set -euo pipefail

# ── Configuração ─────────────────────────────────────────────────────────────
BASE_URL="http://localhost:8080"
START_RPS=100
STEP_RPS=200
MAX_RPS=5000
STAGE_DURATION=30    # segundos por estágio
ERROR_THRESHOLD=5    # % — parar se taxa de erro ultrapassar
LATENCY_THRESHOLD=1000  # ms — parar se P95 ultrapassar

RESULT_FILE="progressive-$(date +%Y%m%d-%H%M%S).csv"
echo "rps,total,errors,error_pct,p95_ms" > "$RESULT_FILE"

# ── Cores ────────────────────────────────────────────────────────────────────
G='\033[0;32m' R='\033[0;31m' Y='\033[1;33m' C='\033[0;36m' NC='\033[0m'

# ── Verificações ──────────────────────────────────────────────────────────────
for cmd in curl awk bc jq; do
  command -v "$cmd" &>/dev/null || { echo "Dependência ausente: $cmd"; exit 1; }
done

if ! curl -sf "$BASE_URL/actuator/health" | grep -q '"UP"'; then
  echo -e "${R}Serviço não está UP. Inicie com: docker-compose up -d${NC}"
  exit 1
fi

# ── Funções auxiliares ────────────────────────────────────────────────────────

# Envia carga por STAGE_DURATION segundos com TARGET_RPS de alvo
run_stage() {
  local target_rps="$1"
  local end=$(( $(date +%s) + STAGE_DURATION ))
  local interval; interval=$(awk "BEGIN{printf \"%.4f\", 1/$target_rps}")
  local lat_log; lat_log=$(mktemp)
  local ok_log; ok_log=$(mktemp)
  local err_log; err_log=$(mktemp)

  trap "rm -f '$lat_log' '$ok_log' '$err_log'" RETURN

  # Singlethread — para RPS altos use test.sh com workers
  while (( $(date +%s) < end )); do
    local t0; t0=$(date +%s%3N)

    if (( RANDOM % 100 < 95 )); then
      local status
      status=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$BASE_URL/api/orders" \
        -H "Content-Type: application/json" \
        -d "{
          \"orderNumber\": \"P-$(date +%s%N)\",
          \"supplierId\":  \"SUP-$((RANDOM % 5 + 1))\",
          \"productId\":   \"PROD-$((RANDOM % 20 + 1))\",
          \"quantity\":    $((RANDOM % 10 + 1)),
          \"unitPrice\":   $((RANDOM % 200 + 10)).$((RANDOM % 99 + 10))
        }")
      local t1; t1=$(date +%s%3N)
      echo $(( t1 - t0 )) >> "$lat_log"
      [[ "$status" == "201" ]] && echo 1 >> "$ok_log" || echo 1 >> "$err_log"
    else
      curl -s -o /dev/null \
        -X POST "$BASE_URL/api/orders" \
        -H "Content-Type: application/json" \
        -d '{"orderNumber":"","quantity":-1}' || true
      echo 1 >> "$err_log"
    fi

    sleep "$interval" 2>/dev/null || true
  done

  # Calcular resultado do estágio
  local total_ok; total_ok=$(wc -l < "$ok_log"  2>/dev/null || echo 0)
  local total_err; total_err=$(wc -l < "$err_log" 2>/dev/null || echo 0)
  local total=$(( total_ok + total_err ))

  local error_pct p95
  error_pct=$(awk "BEGIN{printf \"%.1f\", ($total>0)?$total_err*100/$total:0}")
  p95=$(sort -n "$lat_log" 2>/dev/null | awk -v n="$(wc -l < "$lat_log")" \
    'END{print lines[int(n*0.95)+1]}' 2>/dev/null || echo 0)
  p95=$(sort -n "$lat_log" | awk -v n="$(wc -l < "$lat_log")" \
    '{lines[NR]=$1} END{print (lines[int(n*0.95)+1]?lines[int(n*0.95)+1]:0)}')

  # Exportar para uso no caller via arquivo temporário
  echo "$target_rps $total $total_err $error_pct $p95" > /tmp/_stage_result

  echo "$target_rps,$total,$total_err,$error_pct,$p95" >> "$RESULT_FILE"
}

# ── Loop de estágios ──────────────────────────────────────────────────────────
echo ""
echo -e "${C}Teste progressivo — order-service${NC}"
echo "Estágios: ${START_RPS} → ${MAX_RPS} RPS (+${STEP_RPS} por estágio, ${STAGE_DURATION}s cada)"
echo "Parar se: erro > ${ERROR_THRESHOLD}%  ou  P95 > ${LATENCY_THRESHOLD}ms"
echo ""

current_rps=$START_RPS
peak_rps=0
stage=1
stop_reason=""

while (( current_rps <= MAX_RPS )); do
  printf "${C}[Estágio %d]${NC} %d RPS ... " "$stage" "$current_rps"

  run_stage "$current_rps"

  read -r rps total errors error_pct p95 < /tmp/_stage_result

  printf "total: %d  erros: %s%%  P95: %dms" "$total" "$error_pct" "$p95"

  # Verificar thresholds
  over_error=$(awk "BEGIN{print ($error_pct > $ERROR_THRESHOLD)?1:0}")
  over_latency=$(( p95 > LATENCY_THRESHOLD ))

  if (( over_error || over_latency )); then
    echo -e "  ${R}← limite atingido${NC}"
    [[ $over_error    == 1 ]] && stop_reason="erro ${error_pct}% > ${ERROR_THRESHOLD}%"
    [[ $over_latency  == 1 ]] && stop_reason="P95 ${p95}ms > ${LATENCY_THRESHOLD}ms"
    break
  fi

  echo -e "  ${G}OK${NC}"
  peak_rps=$current_rps
  current_rps=$(( current_rps + STEP_RPS ))
  stage=$(( stage + 1 ))

  # Pausa entre estágios para o sistema estabilizar
  sleep 5
done

# ── Resumo ────────────────────────────────────────────────────────────────────
echo ""
echo "─────────────────────────────────────"
printf "Pico sustentado:  ${G}%d RPS${NC}\n" "$peak_rps"
[[ -n "$stop_reason" ]] && printf "Parou por:        ${R}%s${NC}\n" "$stop_reason"
printf "Resultados:       %s\n" "$RESULT_FILE"
echo "─────────────────────────────────────"
echo "Grafana: http://localhost:3000  (admin/admin)"
echo ""
echo "Queries úteis no Grafana:"
echo "  rate(http_requests_total[1m])"
echo "  histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))"
echo "  rate(http_requests_total{status='error'}[1m]) / sum(rate(http_requests_total[1m])) * 100"