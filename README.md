# Order Service — Observabilidade

Laboratório em Spring Boot para gerenciamento de pedidos de compra, com foco nas 4 Golden Signals de monitoramento.

| Sinal | O que mede |
|---|---|
| Latência | Tempo de resposta das requisições (P50 / P95 / P99) |
| Tráfego | Volume de requisições por segundo |
| Erros | Taxa de falhas nas operações |
| Saturação | CPU, memória heap e conexões do pool |

---

## Instalação e execução

```bash
git clone https://github.com/yourusername/order-service.git
cd order-service
docker-compose up -d
```

Serviços disponíveis após a inicialização:

| Serviço | URL | Credenciais |
|---|---|---|
| Order Service API | http://localhost:8080 | — |
| Prometheus | http://localhost:9090 | — |
| Grafana | http://localhost:3000 | admin / admin |
| Grafana Tempo (tracing) | http://localhost:3200 | — |

---

## Monitoramento

### Dashboard Grafana

O dashboard é provisionado automaticamente via `grafana/provisioning/dashboards/golden-signals.json`. Basta acessar http://localhost:3000 após subir o stack.

Para importar manualmente:

1. Acesse http://localhost:3000 → login `admin / admin`
2. Menu lateral → **Dashboards → Import**
3. Cole o conteúdo de `grafana/provisioning/dashboards/golden-signals.json`
4. Selecione o datasource **Prometheus** e clique em **Import**

### Thresholds configurados

| Métrica | Atenção | Crítico |
|---|---|---|
| Latência | > 500ms | > 1s |
| Taxa de erro | > 1% | > 5% |
| CPU | > 70% | > 85% |

---

## Testes de carga

Dois scripts disponíveis, ambos com health check automático antes de iniciar.

### `test.sh` — volume configurável

Envia carga por um período fixo. Útil para popular métricas no Grafana e verificar comportamento sob carga conhecida.

```bash
chmod +x test.sh

./test.sh                  # padrão: 100 rps, 30s, 10 workers
./test.sh 500 60           # 500 rps por 60 segundos
./test.sh 2000 30 20       # 2000 rps, 30s, 20 workers concorrentes
```

A distribuição é 95% requisições válidas e 5% inválidas, para gerar taxa de erro controlada visível no dashboard.

Saída durante o teste:
```
[ 5s] rps:   98  ok:   489  err:   26  erro:  5.1%  lat_avg: 42ms
[10s] rps:   97  ok:   972  err:   53  erro:  5.2%  lat_avg: 45ms
```

Resumo ao final:
```
─────────────────────────────────────
Total:       2950 req em 30s
RPS real:    98
Sucesso:     2802
Erro:        148  (5.0%)

Latência (ms):
  min=18ms  p50=38ms  p95=112ms  p99=198ms  max=340ms  avg=42ms
─────────────────────────────────────
```

### `test-progressive.sh` — descoberta de limite

```bash
chmod +x load-test-progressive.sh
./test-progressive.sh
```

Configurações padrão (editáveis no início do script):

| Parâmetro | Valor padrão |
|---|---|
| RPS inicial | 100 |
| Incremento por estágio | 200 |
| RPS máximo | 5000 |
| Duração por estágio | 30s |
| Parar se erro > | 5% |
| Parar se P95 > | 1000ms |

Saída durante o teste:
```
Teste progressivo — order-service
Estágios: 100 → 5000 RPS (+200 por estágio, 30s cada)
Parar se: erro > 5%  ou  P95 > 1000ms

[Estágio 1]  100 RPS ... total: 2847  erros: 5.1%  P95: 48ms   OK
[Estágio 2]  300 RPS ... total: 8640  erros: 4.9%  P95: 61ms   OK
[Estágio 3]  500 RPS ... total: 14203 erros: 5.2%  P95: 89ms   OK
[Estágio 4]  700 RPS ... total: 18901 erros: 8.1%  P95: 1240ms ← limite atingido

─────────────────────────────────────
Pico sustentado:  500 RPS
Parou por:        erro 8.1% > 5%
Resultados:       progressive-20250101-120000.csv
─────────────────────────────────────
```