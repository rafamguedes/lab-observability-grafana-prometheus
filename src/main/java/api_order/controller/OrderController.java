package api_order.controller;

import api_order.dto.OrderRequest;
import api_order.dto.OrderResponse;
import api_order.service.OrderService;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.DistributionSummary;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Duration;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
@Slf4j
public class OrderController {

  private final OrderService orderService;
  private final MeterRegistry meterRegistry;

  // Métricas de Latência
  private final Timer orderCreationTimer;
  private final Timer requestTimer;

  // Métricas de Tráfego
  private final Counter totalRequestsCounter;
  private final Counter successRequestsCounter;
  private final Counter errorRequestsCounter;

  // Métricas de Saturação
  private final AtomicInteger activeRequests = new AtomicInteger(0);

  @Autowired
  public OrderController(OrderService orderService, MeterRegistry meterRegistry) {
    this.orderService = orderService;
    this.meterRegistry = meterRegistry;

    // Latência - Timer para medir tempo de criação de pedido
    this.orderCreationTimer = Timer.builder("order.create.duration")
            .description("Tempo para criar um pedido")
            .publishPercentiles(0.5, 0.95, 0.99)  // P50, P95, P99
            .publishPercentileHistogram()
            .sla(
                    Duration.ofMillis(50),   // 50ms
                    Duration.ofMillis(100),  // 100ms
                    Duration.ofMillis(500),  // 500ms
                    Duration.ofSeconds(1),   // 1s
                    Duration.ofSeconds(2)    // 2s
            )
            .register(meterRegistry);

    // Latência - Timer geral para todas as requisições
    this.requestTimer = Timer.builder("http.request.duration")
            .description("Tempo total das requisições HTTP")
            .publishPercentiles(0.5, 0.95, 0.99)
            .publishPercentileHistogram()
            .sla(
                    Duration.ofMillis(50),
                    Duration.ofMillis(100),
                    Duration.ofMillis(500),
                    Duration.ofSeconds(1),
                    Duration.ofSeconds(2)
            )
            .tag("endpoint", "/api/orders")
            .register(meterRegistry);

    // Tráfego - Contadores
    this.totalRequestsCounter = Counter.builder("http.requests.total")
            .description("Total de requisições HTTP")
            .tag("endpoint", "/api/orders")
            .register(meterRegistry);

    this.successRequestsCounter = Counter.builder("http.requests.success")
            .description("Requisições bem sucedidas")
            .tag("endpoint", "/api/orders")
            .register(meterRegistry);

    this.errorRequestsCounter = Counter.builder("http.requests.error")
            .description("Requisições com erro")
            .tag("endpoint", "/api/orders")
            .register(meterRegistry);

    // Saturação - Gauge para requisições ativas
    meterRegistry.gauge("http.requests.active", activeRequests);

    // Saturação - CPU e Memória já são expostas pelo Spring Boot Actuator
  }

  @PostMapping
  public ResponseEntity<OrderResponse> createOrder(@Valid @RequestBody OrderRequest request) {
    // Saturação: incrementa contador de requisições ativas
    int active = activeRequests.incrementAndGet();
    log.info("Requisições ativas: {}", active);

    // Tráfego: incrementa contador total
    totalRequestsCounter.increment();

    // Latência: inicia timer
    Timer.Sample sample = Timer.start(meterRegistry);
    long startTime = System.nanoTime();

    try {
      // Processa a requisição
      OrderResponse response = orderService.createOrder(request);

      // Tráfego: sucesso
      successRequestsCounter.increment();

      // Latência: registra tempo de criação específico
      long duration = System.nanoTime() - startTime;
      orderCreationTimer.record(duration, TimeUnit.NANOSECONDS);
      requestTimer.record(duration, TimeUnit.NANOSECONDS);

      log.info("Pedido criado com sucesso em {}ms", duration / 1_000_000);

      return ResponseEntity.status(HttpStatus.CREATED).body(response);

    } catch (Exception e) {
      // Tráfego: erro
      errorRequestsCounter.increment();

      // Latência: registra tempo mesmo com erro
      long duration = System.nanoTime() - startTime;
      requestTimer.record(duration, TimeUnit.NANOSECONDS);

      log.error("Erro ao criar pedido após {}ms: {}", duration / 1_000_000, e.getMessage());
      throw e;

    } finally {
      // Saturação: decrementa requisições ativas
      activeRequests.decrementAndGet();
    }
  }

  @GetMapping("/{id}")
  public ResponseEntity<OrderResponse> getOrder(@PathVariable String id) {
    Timer.Sample sample = Timer.start(meterRegistry);
    totalRequestsCounter.increment();

    try {
      OrderResponse response = orderService.getOrder(id);
      successRequestsCounter.increment();
      return ResponseEntity.ok(response);
    } catch (Exception e) {
      errorRequestsCounter.increment();
      throw e;
    } finally {
      sample.stop(requestTimer);
    }
  }

  @GetMapping("/metrics/latency")
  public ResponseEntity<Object> getLatencyMetrics() {
    return ResponseEntity.ok(meterRegistry.get("order.create.duration").timer().takeSnapshot());
  }
}