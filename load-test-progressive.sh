# load-test-progressive.sh
#!/bin/bash

echo "========================================="
echo "   TESTE DE CARGA PROGRESSIVO"
echo "   Descobrindo o limite da aplicação"
echo "========================================="
echo ""

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações
BASE_URL="http://localhost:8080"
ENDPOINT="/api/orders"
DURATION_PER_STAGE=30  # segundos por estágio
START_RPS=100          # começar com 100 RPS
MAX_RPS=10000          # máximo a testar
STEP=500               # aumentar 500 RPS por estágio
ERROR_THRESHOLD=5      # parar se erro > 5%
LATENCY_THRESHOLD=1000 # parar se latência > 1000ms

# Arquivos de log
RESULT_FILE="load-test-results-$(date +%Y%m%d-%H%M%S).csv"
echo "timestamp,rps,success,errors,error_rate,avg_latency,p95_latency,cpu_usage,memory_mb" > $RESULT_FILE

# Função para coletar métricas atuais
collect_metrics() {
    local rps=$1

    # Coletar métricas do Prometheus
    local total_before=$(curl -s "http://localhost:9090/api/v1/query?query=http_requests_total" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 0)
    local error_before=$(curl -s "http://localhost:9090/api/v1/query?query=http_requests_error_total" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 0)

    sleep $DURATION_PER_STAGE

    local total_after=$(curl -s "http://localhost:9090/api/v1/query?query=http_requests_total" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 0)
    local error_after=$(curl -s "http://localhost:9090/api/v1/query?query=http_requests_error_total" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 0)

    local total_requests=$(echo "$total_after - $total_before" | bc)
    local error_requests=$(echo "$error_after - $error_before" | bc)
    local error_rate=0

    if [ $total_requests -gt 0 ]; then
        error_rate=$(echo "scale=2; $error_requests * 100 / $total_requests" | bc)
    fi

    # Coletar latência
    local latency=$(curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,sum(rate(http_request_duration_seconds_bucket[1m]))by(le))" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 0)
    latency_ms=$(echo "$latency * 1000" | bc | cut -d. -f1)

    # Coletar CPU e memória
    local cpu=$(curl -s "http://localhost:9090/api/v1/query?query=process_cpu_usage*100" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 0)
    local memory=$(curl -s "http://localhost:9090/api/v1/query?query=jvm_memory_used_bytes{area='heap'}/1048576" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 0)

    echo "$(date +%H:%M:%S),$rps,$total_requests,$error_requests,$error_rate,$latency_ms,$latency_ms,$cpu,$memory" >> $RESULT_FILE

    echo -e "   📊 RPS: ${BLUE}$rps${NC} | Total: $total_requests | Erros: $error_requests | Taxa: ${YELLOW}${error_rate}%${NC}"
    echo -e "   ⏱️  Latência P95: ${latency_ms}ms | CPU: ${cpu}% | Memória: ${memory}MB"

    # Retornar status
    if (( $(echo "$error_rate > $ERROR_THRESHOLD" | bc -l) )) || [ $latency_ms -gt $LATENCY_THRESHOLD ]; then
        return 1
    fi
    return 0
}

# Função para gerar carga
generate_load() {
    local target_rps=$1
    local duration=$2
    local sleep_time=$(echo "scale=6; 1 / $target_rps" | bc)

    local end_time=$(( $(date +%s) + duration ))
    local count=0

    while [ $(date +%s) -lt $end_time ]; do
        # Requisição com sucesso (95%) ou erro (5%)
        if [ $((RANDOM % 100)) -lt 95 ]; then
            curl -s -X POST $BASE_URL$ENDPOINT \
                -H "Content-Type: application/json" \
                -d "{
                    \"orderNumber\": \"LOAD-$(date +%s%N)-$count\",
                    \"supplierId\": \"SUP-$((RANDOM % 10 + 1))\",
                    \"productId\": \"PROD-$((RANDOM % 50 + 1))\",
                    \"quantity\": $((RANDOM % 20 + 1)),
                    \"unitPrice\": $((RANDOM % 1000 + 1)).$((RANDOM % 99))
                }" > /dev/null 2>&1
        else
            curl -s -X POST $BASE_URL$ENDPOINT \
                -H "Content-Type: application/json" \
                -d "{}" > /dev/null 2>&1
        fi

        ((count++))
        sleep $sleep_time
    done
}

# Função para mostrar progresso
show_progress() {
    local current=$1
    local total=$2
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))

    printf "\r["
    for i in $(seq 1 $filled); do printf "█"; done
    for i in $(seq 1 $empty); do printf "░"; done
    printf "] %3d%% - RPS: %d" "$percent" "$current"
}

echo "📊 Configuração do Teste"
echo "========================================="
echo "⏱️  Duração por estágio: ${DURATION_PER_STAGE}s"
echo "📈 RPS inicial: ${START_RPS}"
echo "📈 RPS máximo: ${MAX_RPS}"
echo "📊 Incremento: ${STEP} RPS por estágio"
echo "⚠️  Parar se erro > ${ERROR_THRESHOLD}% ou latência > ${LATENCY_THRESHOLD}ms"
echo "========================================="
echo ""

echo "🚀 Iniciando teste de carga progressivo..."
echo ""

# Teste progressivo
current_rps=$START_RPS
stage=1
max_reached=0
peak_rps=0

while [ $current_rps -le $MAX_RPS ]; do
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Estágio $stage: Testando com ${current_rps} RPS${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Iniciar gerador de carga em background
    generate_load $current_rps $DURATION_PER_STAGE &
    LOAD_PID=$!

    # Mostrar contador regressivo
    for i in $(seq $DURATION_PER_STAGE -1 1); do
        printf "\r⏳ Aguardando ${i} segundos... "
        sleep 1
    done
    echo ""

    # Coletar métricas
    echo -e "\n📊 Coletando métricas do estágio $stage:"
    if collect_metrics $current_rps; then
        echo -e "${GREEN}✅ Estágio $stage concluído com sucesso!${NC}"
        peak_rps=$current_rps
        current_rps=$((current_rps + STEP))
        stage=$((stage + 1))
    else
        echo -e "${RED}❌ Limite atingido em ${current_rps} RPS!${NC}"
        max_reached=$current_rps
        break
    fi

    # Aguardar recuperação
    echo "🔄 Aguardando recuperação do sistema (10s)..."
    sleep 10
    echo ""
done

# Resultados finais
echo ""
echo "========================================="
echo "📈 RESULTADOS DO TESTE DE CARGA"
echo "========================================="
echo -e "🏆 Pico máximo sustentado: ${GREEN}${peak_rps}${NC} RPS"
echo -e "⚠️  Limite encontrado: ${RED}${max_reached}${NC} RPS (ou superior)"
echo ""
echo "📊 Análise por estágio:"
echo "========================================="
column -t -s, $RESULT_FILE | head -20
echo ""
echo "📁 Resultados salvos em: $RESULT_FILE"
echo ""

# Gerar gráfico com gnuplot se disponível
if command -v gnuplot &> /dev/null; then
    echo "📈 Gerando gráfico de performance..."
    cat > plot.gnuplot <<EOF
set terminal png size 1200,800
set output 'load-test-chart.png'
set title 'Teste de Carga - Performance do Sistema'
set xlabel 'Estágio (RPS)'
set ylabel 'Métricas'
set grid
plot '$RESULT_FILE' using 2:5 with lines title 'Erro (%)', \
     '' using 2:6 with lines title 'Latência (ms)', \
     '' using 2:8 with lines title 'CPU (%)'
EOF
    gnuplot plot.gnuplot
    echo "✅ Gráfico gerado: load-test-chart.png"
fi

echo ""
echo "🔍 Próximos passos:"
echo "1. Analise o arquivo CSV para ver a degradação"
echo "2. Verifique no Grafana os picos de CPU e memória"
echo "3. Identifique gargalos (banco de dados, CPU, etc.)"
echo "4. Considere escalar horizontalmente se necessário"