# test-low-throughput.sh
#!/bin/bash

echo "========================================="
echo "     TESTE COMPLETO DE MÉTRICAS"
echo "========================================="
echo ""

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
SUCCESS_COUNT=1000
ERROR_COUNT=100
DELAY=0.01  # 10ms entre requisições

# Contadores
SUCCESS_DONE=0
ERROR_DONE=0
START_TIME=$(date +%s)

# Função para criar pedidos com sucesso
create_success_order() {
    local id=$1
    local quantity=$((RANDOM % 10 + 1))
    local price=$((RANDOM % 100 + 1)).$((RANDOM % 99))

    curl -s -X POST http://localhost:8080/api/orders \
        -H "Content-Type: application/json" \
        -d "{
            \"orderNumber\": \"SUCCESS-$(date +%s)-$id\",
            \"supplierId\": \"SUP-$(($RANDOM % 5 + 1))\",
            \"productId\": \"PROD-$(($RANDOM % 20 + 1))\",
            \"quantity\": $quantity,
            \"unitPrice\": $price,
            \"notes\": \"Teste automatizado\"
        }" > /dev/null 2>&1

    return $?
}

# Função para criar pedidos com erro
create_error_order() {
    local id=$1
    local error_type=$((RANDOM % 3))

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
                    \"orderNumber\": \"ERROR-$id\",
                    \"supplierId\": \"SUP-001\",
                    \"productId\": \"PROD-001\",
                    \"quantity\": -5,
                    \"unitPrice\": 99.90
                }" > /dev/null 2>&1
            ;;
        2)
            # Erro: preço inválido
            curl -s -X POST http://localhost:8080/api/orders \
                -H "Content-Type: application/json" \
                -d "{
                    \"orderNumber\": \"ERROR-$id\",
                    \"supplierId\": \"SUP-001\",
                    \"productId\": \"PROD-001\",
                    \"quantity\": 10,
                    \"unitPrice\": 0
                }" > /dev/null 2>&1
            ;;
    esac

    return $?
}

# Função para mostrar barra de progresso
show_progress() {
    local current=$1
    local total=$2
    local type=$3
    local percent=$((current * 100 / total))
    local completed=$((percent / 2))
    local remaining=$((50 - completed))

    if [ "$type" == "success" ]; then
        printf "\r${GREEN}["
    else
        printf "\r${RED}["
    fi

    for i in $(seq 1 $completed); do printf "="; done
    for i in $(seq 1 $remaining); do printf " "; done

    if [ "$type" == "success" ]; then
        printf "] ${GREEN}%3d%%${NC} - %d/%d pedidos com sucesso" "$percent" "$current" "$total"
    else
        printf "] ${RED}%3d%%${NC} - %d/%d pedidos com erro" "$percent" "$current" "$total"
    fi
}

echo "📊 Configuração do teste:"
echo "   ✅ Pedidos com sucesso: ${SUCCESS_COUNT}"
echo "   ❌ Pedidos com erro: ${ERROR_COUNT}"
echo "   📈 Total de pedidos: $((SUCCESS_COUNT + ERROR_COUNT))"
echo "   ⏱️  Delay entre requisições: ${DELAY}s"
echo ""
echo "🚀 Iniciando teste de carga..."
echo ""

# Gerar pedidos com sucesso
echo -e "${GREEN}▶️  Gerando ${SUCCESS_COUNT} pedidos com sucesso...${NC}"
for i in $(seq 1 $SUCCESS_COUNT); do
    create_success_order $i
    if [ $? -eq 0 ]; then
        ((SUCCESS_DONE++))
    fi
    show_progress $SUCCESS_DONE $SUCCESS_COUNT "success"
    sleep $DELAY
done
echo -e "\n${GREEN}✅ ${SUCCESS_DONE} pedidos com sucesso criados!${NC}"
echo ""

# Gerar pedidos com erro
echo -e "${RED}▶️  Gerando ${ERROR_COUNT} pedidos com erro...${NC}"
for i in $(seq 1 $ERROR_COUNT); do
    create_error_order $i
    if [ $? -eq 0 ]; then
        ((ERROR_DONE++))
    fi
    show_progress $ERROR_DONE $ERROR_COUNT "error"
    sleep $DELAY
done
echo -e "\n${RED}✅ ${ERROR_DONE} pedidos com erro gerados!${NC}"
echo ""

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
TOTAL_REQUESTS=$((SUCCESS_DONE + ERROR_DONE))

echo "========================================="
echo "📈 RESUMO DO TESTE"
echo "========================================="
echo "✅ Pedidos com sucesso: ${SUCCESS_DONE}"
echo "❌ Pedidos com erro: ${ERROR_DONE}"
echo "📊 Total de requisições: ${TOTAL_REQUESTS}"
echo "⏱️  Tempo total: ${TOTAL_TIME} segundos"
echo "🚀 Taxa média: $((TOTAL_REQUESTS / TOTAL_TIME)) req/segundo"
echo "📉 Taxa de erro: $(echo "scale=2; $ERROR_DONE * 100 / $TOTAL_REQUESTS" | bc)%"
echo "========================================="
echo ""

# Aguardar processamento das métricas
echo "⏳ Aguardando processamento das métricas (5 segundos)..."
sleep 5

# Coletar métricas atuais
echo ""
echo "📊 COLETANDO MÉTRICAS ATUAIS"
echo "========================================="

# Função para formatar números
format_number() {
    printf "%'.0f" $1 2>/dev/null || echo $1
}

# Verificar métricas via API
echo ""
echo "🔍 Métricas via API do Order Service:"
METRICS_RESPONSE=$(curl -s http://localhost:8080/api/orders/metrics 2>/dev/null)

if [ ! -z "$METRICS_RESPONSE" ]; then
    TOTAL=$(echo $METRICS_RESPONSE | grep -o '"total_requests":[0-9]*' | cut -d':' -f2)
    SUCCESS=$(echo $METRICS_RESPONSE | grep -o '"success_requests":[0-9]*' | cut -d':' -f2)
    ERRORS=$(echo $METRICS_RESPONSE | grep -o '"error_requests":[0-9]*' | cut -d':' -f2)
    ERROR_RATE=$(echo $METRICS_RESPONSE | grep -o '"error_rate":[0-9.]*' | cut -d':' -f2)
    AVG_LATENCY=$(echo $METRICS_RESPONSE | grep -o '"avg_latency_ms":[0-9.]*' | cut -d':' -f2)

    echo "   Total de requisições: $(format_number $TOTAL)"
    echo "   Requisições com sucesso: $(format_number $SUCCESS)"
    echo "   Requisições com erro: $(format_number $ERRORS)"
    echo "   Taxa de erro: ${ERROR_RATE}%"
    echo "   Latência média: ${AVG_LATENCY}ms"
else
    echo "   ⚠️  API de métricas não disponível"
fi

echo ""
echo "🔍 Métricas via Prometheus:"
echo "   Acesse: http://localhost:9090"
echo "   Queries sugeridas:"
echo "   - http_requests_total"
echo "   - http_requests_error_total"
echo "   - http_requests_success_total"
echo "   - rate(http_requests_total[1m])"
echo ""

echo "🔍 Métricas via Actuator:"
curl -s http://localhost:8080/actuator/metrics/http.requests.total 2>/dev/null | grep -E "value|COUNT" | head -3

echo ""
echo "========================================="
echo "📊 DASHBOARD GRAFANA"
echo "========================================="
echo "🌐 Acesse: http://localhost:3000"
echo "👤 Login: admin / admin"
echo ""
echo "📈 Golden Signals Dashboard:"
echo "   1. LATÊNCIA - Deve mostrar valores entre 10ms e 500ms"
echo "   2. TRÁFEGO - Deve mostrar picos de até ${TOTAL_REQUESTS} requisições"
echo "   3. TAXA DE ERRO - Deve mostrar aproximadamente $(echo "scale=1; $ERROR_DONE * 100 / $TOTAL_REQUESTS" | bc)%"
echo "   4. SATURAÇÃO - CPU e memória devem aumentar durante o teste"
echo ""
echo "🔍 Queries para verificar no Grafana:"
echo "   - Taxa de Erro: (http_requests_error_total / http_requests_total) * 100"
echo "   - Tráfego: rate(http_requests_total[1m])"
echo "   - Latência P95: histogram_quantile(0.95, sum(rate(http_request_duration_bucket[5m])) by (le))"
echo ""

# Teste adicional com mais carga
echo "========================================="
echo "🚀 TESTE DE CARGA ADICIONAL (Opcional)"
echo "========================================="
read -p "Deseja executar um teste de carga adicional com 1000 requisições? (s/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "Executando teste de carga adicional..."
    ADDITIONAL=1000

    echo -n "Gerando ${ADDITIONAL} requisições: "
    for i in $(seq 1 $ADDITIONAL); do
        if [ $((i % 20)) -eq 0 ]; then
            create_error_order $i
            echo -n "${RED}x${NC}"
        else
            create_success_order $i
            echo -n "${GREEN}.${NC}"
        fi
        sleep 0.005
    done
    echo ""
    echo "✅ Teste adicional concluído!"
fi

echo ""
echo "✨ Teste finalizado! Acesse o Grafana para visualizar as métricas."
echo ""
echo "💡 Dica: Atualize a página do Grafana a cada 10-15 segundos para ver as métricas em tempo real."