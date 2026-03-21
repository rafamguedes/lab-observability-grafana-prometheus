# stress-test-fixed.sh
#!/bin/bash

echo "========================================="
echo "   TESTE DE ESTRESSE - LIMITE MÁXIMO"
echo "========================================="
echo ""

# Configurações
MAX_RPS=5000  # Reduzido para não sobrecarregar muito
DURATION=30   # 30 segundos
CONCURRENT_WORKERS=50

echo "🚨 ATENÇÃO: Este teste pode sobrecarregar o sistema!"
echo "⏱️  Duração: ${DURATION}s"
echo "📈 RPS máximo: ${MAX_RPS}"
echo "🔄 Workers: ${CONCURRENT_WORKERS}"
echo ""
read -p "Deseja continuar? (s/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Teste cancelado."
    exit 1
fi

# Função worker
worker() {
    local id=$1
    local end_time=$(($(date +%s) + DURATION))
    local count=0

    # Calcular intervalo entre requisições (em milissegundos)
    local interval_ms=$((1000 / MAX_RPS))
    if [ $interval_ms -lt 1 ]; then
        interval_ms=1
    fi

    while [ $(date +%s) -lt $end_time ]; do
        curl -s -X POST http://localhost:8080/api/orders \
            -H "Content-Type: application/json" \
            -d "{
                \"orderNumber\": \"STRESS-$(date +%s%N)-$id-$count\",
                \"supplierId\": \"SUP-001\",
                \"productId\": \"PROD-001\",
                \"quantity\": 10,
                \"unitPrice\": 99.90
            }" > /dev/null 2>&1

        ((count++))
        sleep 0.001  # 1ms de espera
    done
}

echo "🚀 Iniciando teste de estresse..."
echo ""

# Criar arquivo temporário para PID dos workers
WORKER_PIDS=""

# Iniciar workers
for i in $(seq 1 $CONCURRENT_WORKERS); do
    worker $i &
    WORKER_PIDS="$WORKER_PIDS $!"
done

# Monitorar progresso
for i in $(seq $DURATION -1 1); do
    printf "\r⏳ Teste em andamento... %d segundos restantes" $i
    sleep 1
done
echo ""

# Aguardar workers finalizarem
echo "Aguardando finalização dos workers..."
wait $WORKER_PIDS 2>/dev/null

echo ""
echo "✅ Teste de estresse concluído!"
echo ""
echo "📊 Verifique os resultados no Grafana: http://localhost:3000"
echo "   Métricas importantes:"
echo "   - Taxa de erro"
echo "   - Latência P95"
echo "   - Uso de CPU e memória"