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