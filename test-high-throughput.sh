# test-high-throughput.sh
#!/bin/bash

echo "========================================="
echo "   TESTE DE ALTA PERFORMANCE - 10K RPS"
echo "========================================="
echo ""

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configurações de Performance
TARGET_RPS=10000                    # 10.000 requisições por segundo
TEST_DURATION=10                    # 10 segundos de teste
SUCCESS_RATIO=95                    # 95% sucesso, 5% erro
CONCURRENT_WORKERS=50               # 50 workers concorrentes

# Cálculos
TOTAL_REQUESTS=$((TARGET_RPS * TEST_DURATION))
SUCCESS_COUNT=$((TOTAL_REQUESTS * SUCCESS_RATIO / 100))
ERROR_COUNT=$((TOTAL_REQUESTS - SUCCESS_COUNT))
DELAY_NS=$((1000000000 / TARGET_RPS))  # Nanosegundos entre requisições

# Contadores
SUCCESS_DONE=0
ERROR_DONE=0
START_TIME=0
END_TIME=0

# Arquivos temporários para logs
SUCCESS_LOG="/tmp/success.log"
ERROR_LOG="/tmp/error.log"
LATENCY_LOG="/tmp/latency.log"
rm -f $SUCCESS_LOG $ERROR_LOG $LATENCY_LOG

# Função para criar pedidos com sucesso (otimizada)
create_success_order() {
    local id=$1
    local start_ns=$(date +%s%N)

    local response=$(curl -s -X POST http://localhost:8080/api/orders \
        -H "Content-Type: application/json" \
        -d "{
            \"orderNumber\": \"HIGH-$(date +%s)-$id\",
            \"supplierId\": \"SUP-$((RANDOM % 10 + 1))\",
            \"productId\": \"PROD-$((RANDOM % 50 + 1))\",
            \"quantity\": $((RANDOM % 20 + 1)),
            \"unitPrice\": $((RANDOM % 1000 + 1)).$((RANDOM % 99)),
            \"notes\": \"High throughput test\"
        }" 2>/dev/null)

    local end_ns=$(date +%s%N)
    local latency=$((($end_ns - $start_ns) / 1000000))  # ms

    echo "$latency" >> $LATENCY_LOG

    if [[ "$response" == *"id"* ]]; then
        echo "1" >> $SUCCESS_LOG
        return 0
    else
        echo "1" >> $ERROR_LOG
        return 1
    fi
}

# Função para criar pedidos com erro (otimizada)
create_error_order() {
    local id=$1
    local error_type=$((RANDOM % 4))

    case $error_type in
        0)
            # Erro: campos vazios
            curl -s -X POST http://localhost:8080/api/orders \
                -H "Content-Type: application/json" \
                -d "{}" > /dev/null 2>&1
            ;;
        1)
            # Erro: quantidade inválida
            curl -s -X POST http://localhost:8080/api/orders \
                -H "Content-Type: application/json" \
                -d "{
                    \"orderNumber\": \"ERR-$id\",
                    \"supplierId\": \"SUP-001\",
                    \"productId\": \"PROD-001\",
                    \"quantity\": -10,
                    \"unitPrice\": 99.90
                }" > /dev/null 2>&1
            ;;
        2)
            # Erro: preço inválido
            curl -s -X POST http://localhost:8080/api/orders \
                -H "Content-Type: application/json" \
                -d "{
                    \"orderNumber\": \"ERR-$id\",
                    \"supplierId\": \"SUP-001\",
                    \"productId\": \"PROD-001\",
                    \"quantity\": 10,
                    \"unitPrice\": -50
                }" > /dev/null 2>&1
            ;;
        3)
            # Erro: orderNumber vazio
            curl -s -X POST http://localhost:8080/api/orders \
                -H "Content-Type: application/json" \
                -d "{
                    \"orderNumber\": \"\",
                    \"supplierId\": \"SUP-001\",
                    \"productId\": \"PROD-001\",
                    \"quantity\": 10,
                    \"unitPrice\": 99.90
                }" > /dev/null 2>&1
            ;;
    esac

    echo "1" >> $ERROR_LOG
    return 1
}

# Worker function para enviar requisições
worker() {
    local worker_id=$1
    local start_time=$2
    local end_time=$3
    local success_ratio=$4

    while [ $(date +%s) -lt $end_time ]; do
        local rand=$((RANDOM % 100))

        if [ $rand -lt $success_ratio ]; then
            create_success_order "${worker_id}_$(date +%s%N)"
        else
            create_error_order "${worker_id}_$(date +%s%N)"
        fi
    done
}

# Função para mostrar métricas em tempo real
show_realtime_metrics() {
    local duration=$1
    local start=$2

    for i in $(seq 1 $duration); do
        sleep 1
        local current_time=$(date +%s)
        local elapsed=$((current_time - start))
        local success_count=$(wc -l < $SUCCESS_LOG 2>/dev/null || echo 0)
        local error_count=$(wc -l < $ERROR_LOG 2>/dev/null || echo 0)
        local total=$((success_count + error_count))
        local current_rps=$((total / elapsed))
        local error_rate=0

        if [ $total -gt 0 ]; then
            error_rate=$(echo "scale=2; $error_count * 100 / $total" | bc)
        fi

        # Calcular latência média
        local avg_latency=0
        if [ -f $LATENCY_LOG ] && [ $(wc -l < $LATENCY_LOG) -gt 0 ]; then
            avg_latency=$(awk '{sum+=$1} END {printf "%.0f", sum/NR}' $LATENCY_LOG)
        fi

        # Limpar linha e mostrar métricas
        printf "\r${CYAN}[%2ds]${NC} RPS: ${GREEN}%5d${NC} | Total: %6d | ✅: %6d | ❌: %5d | 📊 Erro: ${YELLOW}%5.2f%%${NC} | ⏱️  Latência: ${BLUE}%4dms${NC}     " \
            "$elapsed" "$current_rps" "$total" "$success_count" "$error_count" "$error_rate" "$avg_latency"
    done
    echo ""
}

echo "📊 CONFIGURAÇÃO DO TESTE DE ALTA PERFORMANCE"
echo "========================================="
echo "🎯 Target RPS: ${CYAN}${TARGET_RPS}${NC} requisições/segundo"
echo "⏱️  Duração: ${CYAN}${TEST_DURATION}${NC} segundos"
echo "📈 Total de requisições: ${CYAN}${TOTAL_REQUESTS}${NC}"
echo "✅ Taxa de sucesso: ${GREEN}${SUCCESS_RATIO}%${NC} (${SUCCESS_COUNT} requisições)"
echo "❌ Taxa de erro: ${RED}$((100 - SUCCESS_RATIO))%${NC} (${ERROR_COUNT} requisições)"
echo "🔄 Workers concorrentes: ${CYAN}${CONCURRENT_WORKERS}${NC}"
echo "⏱️  Delay entre requisições: ${CYAN}$(echo "scale=2; $DELAY_NS / 1000" | bc)µs${NC}"
echo "========================================="
echo ""

# Verificar se o serviço está respondendo
echo "🔍 Verificando serviço..."
if ! curl -s http://localhost:8080/api/orders/test > /dev/null 2>&1; then
    echo -e "${RED}❌ Serviço não está respondendo!${NC}"
    echo "Inicie a aplicação primeiro: docker-compose up -d"
    exit 1
fi
echo -e "${GREEN}✅ Serviço OK${NC}"
echo ""

# Preparar para o teste
echo "🚀 PREPARANDO PARA O TESTE..."
echo "⚠️  ATENÇÃO: Serão geradas ${TOTAL_REQUESTS} requisições em ${TEST_DURATION} segundos!"
echo "📊 Isso representa ${TARGET_RPS} req/segundo"
echo ""
read -p "Pressione ENTER para iniciar o teste de alta performance... " -r

echo ""
echo "🚀 INICIANDO TESTE DE CARGA..."
echo "========================================="
echo ""

# Iniciar workers em background
START_TIME=$(date +%s)
END_TIME=$((START_TIME + TEST_DURATION))

# Exportar funções para subshells
export -f worker create_success_order create_error_order
export SUCCESS_LOG ERROR_LOG LATENCY_LOG

# Iniciar workers
for i in $(seq 1 $CONCURRENT_WORKERS); do
    worker $i $START_TIME $END_TIME $SUCCESS_RATIO &
done

# Mostrar métricas em tempo real
show_realtime_metrics $TEST_DURATION $START_TIME

# Aguardar todos os workers terminarem
wait

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

# Coletar resultados finais
SUCCESS_DONE=$(wc -l < $SUCCESS_LOG 2>/dev/null || echo 0)
ERROR_DONE=$(wc -l < $ERROR_LOG 2>/dev/null || echo 0)
TOTAL_DONE=$((SUCCESS_DONE + ERROR_DONE))

echo ""
echo "========================================="
echo "📈 RESUMO DO TESTE DE ALTA PERFORMANCE"
echo "========================================="
echo "✅ Requisições bem sucedidas: ${GREEN}${SUCCESS_DONE}${NC}"
echo "❌ Requisições com erro: ${RED}${ERROR_DONE}${NC}"
echo "📊 Total de requisições: ${CYAN}${TOTAL_DONE}${NC}"
echo "🎯 Target RPS: ${CYAN}${TARGET_RPS}${NC}"
echo "📊 RPS alcançado: ${CYAN}$((TOTAL_DONE / TOTAL_TIME))${NC} req/segundo"
echo "⏱️  Tempo total: ${CYAN}${TOTAL_TIME}${NC} segundos"
echo "📉 Taxa de erro real: ${YELLOW}$(echo "scale=2; $ERROR_DONE * 100 / $TOTAL_DONE" | bc)%${NC}"
echo "========================================="

# Estatísticas de latência
if [ -f $LATENCY_LOG ] && [ $(wc -l < $LATENCY_LOG) -gt 0 ]; then
    echo ""
    echo "⏱️  ESTATÍSTICAS DE LATÊNCIA"
    echo "========================================="

    # Calcular percentis
    SORTED_LATENCY=$(sort -n $LATENCY_LOG)
    TOTAL_LATENCY=$(wc -l < $LATENCY_LOG)

    P50=$(echo "$SORTED_LATENCY" | awk "NR==int($TOTAL_LATENCY*0.5)" 2>/dev/null || echo 0)
    P95=$(echo "$SORTED_LATENCY" | awk "NR==int($TOTAL_LATENCY*0.95)" 2>/dev/null || echo 0)
    P99=$(echo "$SORTED_LATENCY" | awk "NR==int($TOTAL_LATENCY*0.99)" 2>/dev/null || echo 0)
    MIN=$(echo "$SORTED_LATENCY" | head -1 2>/dev/null || echo 0)
    MAX=$(echo "$SORTED_LATENCY" | tail -1 2>/dev/null || echo 0)
    AVG=$(awk '{sum+=$1} END {printf "%.0f", sum/NR}' $LATENCY_LOG 2>/dev/null || echo 0)

    echo "   Mínimo: ${GREEN}${MIN}ms${NC}"
    echo "   P50 (Mediana): ${GREEN}${P50}ms${NC}"
    echo "   P95: ${YELLOW}${P95}ms${NC}"
    echo "   P99: ${RED}${P99}ms${NC}"
    echo "   Máximo: ${RED}${MAX}ms${NC}"
    echo "   Média: ${CYAN}${AVG}ms${NC}"
    echo "========================================="
fi

echo ""
echo "📊 COLETANDO MÉTRICAS DO SISTEMA"
echo "========================================="

# Aguardar processamento do Prometheus
echo "⏳ Aguardando Prometheus processar os dados (10 segundos)..."
sleep 10

# Verificar métricas no Prometheus
echo ""
echo "🔍 Métricas via Prometheus:"
curl -s 'http://localhost:9090/api/v1/query?query=http_requests_total' | jq -r '.data.result[0].value[1]' 2>/dev/null && echo "   Total de requisições registradas" || echo "   ⚠️  Aguardando dados no Prometheus..."

echo ""
echo "🔍 Métricas via Actuator:"
curl -s http://localhost:8080/actuator/metrics/http.requests.total 2>/dev/null | jq -r '.measurements[0].value' 2>/dev/null && echo "   Total de requisições no Actuator" || echo "   ⚠️  Dados não disponíveis"

echo ""
echo "========================================="
echo "📊 DASHBOARD GRAFANA"
echo "========================================="
echo "🌐 Acesse: http://localhost:3000"
echo "👤 Login: admin / admin"
echo ""
echo "📈 Resultados Esperados no Dashboard:"
echo "   1. LATÊNCIA P95: ${YELLOW}${P95}ms${NC} (deve estar < 500ms)"
echo "   2. TRÁFEGO: ${CYAN}$((TOTAL_DONE / TOTAL_TIME))${NC} req/segundo (target: ${TARGET_RPS})"
echo "   3. TAXA DE ERRO: ${YELLOW}$(echo "scale=2; $ERROR_DONE * 100 / $TOTAL_DONE" | bc)%${NC} (target: $((100 - SUCCESS_RATIO))%)"
echo "   4. SATURAÇÃO: CPU e memória devem mostrar picos durante o teste"
echo ""
echo "🔍 Queries para verificar no Grafana:"
echo "   - Taxa de Erro: (http_requests_error_total / http_requests_total) * 100"
echo "   - Tráfego: rate(http_requests_total[1m])"
echo "   - Latência P95: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))"
echo "   - RPS Atual: rate(http_requests_total[5s])"
echo ""

# Limpar arquivos temporários
read -p "Deseja limpar os arquivos temporários de log? (s/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Ss]$ ]]; then
    rm -f $SUCCESS_LOG $ERROR_LOG $LATENCY_LOG
    echo "✅ Arquivos temporários removidos!"
fi

echo ""
echo "✨ Teste de 10.000 RPS concluído!"
echo "💡 Dica: Atualize o Grafana para ver as métricas em tempo real"