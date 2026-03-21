# Visão Geral

API REST desenvolvida em Spring Boot para gerenciamento de pedidos de compra, com foco em observabilidade e monitoramento. O sistema expõe métricas detalhadas que permitem acompanhar as 4 Golden Signals de monitoramento:

- Latência - Tempo de resposta das requisições

- Tráfego - Volume de requisições por segundo

- Erros - Taxa de falhas nas operações

- Saturação - Uso de CPU, memória e conexões

## Instalação e Execução

1. Clone o repositório

```
git clone https://github.com/yourusername/order-service.git
cd order-service
```

2. Execute com Docker Compose

```
docker-compose up -d

docker-compose ps
    
docker-compose logs -f
```

3. Acessar os serviços

- Order Service API	http://localhost:8080
- Prometheus	http://localhost:9090
- Grafana	http://localhost:3000	admin / admin
- Tempo	http://localhost:3200

## Monitoramento

Dashboards do Grafana
Importe o dashboard pré-configurado:

1. Acesse http://localhost:3000
2. Login: admin / admin
3. Menu lateral → Dashboards → Import
4. Cole o JSON do dashboard (disponível em grafana/provisioning/dashboards/golden-signals.json)
5. Selecione o datasource Prometheus
6. Clique em Import

### Métricas Disponíveis no Dashboard

1. 📊 LATÊNCIA (P50, P95, P99)

    - Tempo de resposta das requisições

    - Percentis para análise de performance

    - Alertas configurados para > 1s
---
2. 📈 TRÁFEGO (Requests por Segundo)
   
    - Total de requisições por segundo

    - Requisições bem sucedidas vs com erro

    - Picos de tráfego
---
3. ❌ TAXA DE ERRO (%)

    - Percentual de requisições com falha

    - Thresholds: <1% (bom), 1-5% (atenção), >5% (crítico)
---
4. ⚙️ SATURAÇÃO
   
    - CPU: Uso do processador (%)

    - Memória: Heap usado vs máximo

    - Conexões: Pool do banco de dados

## Testes de Carga

Esta seção explica como usar os scripts de teste de carga para descobrir a capacidade máxima da sua aplicação.

**Teste de Carga Progressivo**

Este teste aumenta gradualmente a carga até encontrar o limite da aplicação. É útil para descobrir o ponto de degradação do sistema.

**Como executar:**

```
# Dar permissão de execução
chmod +x load-test-progressive.sh

# Executar o teste
./load-test-progressive.sh
```

**O que o teste faz:**

- Começa com 50 RPS (requisições por segundo)
- Aumenta 100 RPS a cada estágio
- Cada estágio dura 15 segundos 
- Para quando taxa de erro > 5% ou latência > 1000ms
- Salva os resultados em um arquivo CSV

**Exemplo de saída:**

```
=========================================
   TESTE DE CARGA PROGRESSIVO
   Descobrindo o limite da aplicação
=========================================

📊 Configuração do Teste
=========================================
⏱️  Duração por estágio: 15s
📈 RPS inicial: 50
📈 RPS máximo: 2000
📊 Incremento: 100 RPS por estágio
=========================================

🚀 Iniciando teste de carga progressivo...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Estágio 1: Testando com 50 RPS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏳ Aguardando 15 segundos... 

📊 Coletando métricas do estágio atual:
   📊 RPS: 50
   📈 Total: 750 | Erros: 0 | Taxa: 0%
   ⏱️  Latência média: 0.023s | P95: ~34ms
   💻 CPU: 0.092% | Memória: 89.2MB
✅ Estágio 1 concluído com sucesso!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Estágio 2: Testando com 150 RPS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
...
```

**Resultados:**

O teste gera um arquivo load-test-results-YYYYMMDD-HHMMSS.csv com:

* timestamp
* rps testado
* total de requisições
* erros
* taxa de erro
* latência média e P95
* CPU e memória

## Teste de Estresse

Este teste aplica carga máxima por um período prolongado para verificar a estabilidade do sistema.

**Como executar:**

```
# Dar permissão de execução
chmod +x stress-test.sh

# Executar o teste (cuidado! pode sobrecarregar o sistema)
./stress-test.sh
```

**Configurações padrão:**

* RPS máximo: 5000
* Duração: 30 segundos
* Workers concorrentes: 50

**Exemplo de saída:**

```
=========================================
   TESTE DE ESTRESSE - LIMITE MÁXIMO
=========================================

🚨 ATENÇÃO: Este teste pode sobrecarregar o sistema!
⏱️  Duração: 30s
📈 RPS máximo: 5000
🔄 Workers: 50

Deseja continuar? (s/n): s

🚀 Iniciando teste de estresse...

⏳ Teste em andamento... 30 segundos restantes
⏳ Teste em andamento... 15 segundos restantes
⏳ Teste em andamento... 0 segundos restantes

✅ Teste de estresse concluído!

📊 Verifique os resultados no Grafana: http://localhost:3000
```