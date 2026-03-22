package api_order.controller;

import api_order.dto.OrderRequest;
import api_order.dto.OrderResponse;
import api_order.service.OrderService;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.Counter;
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
@Slf4j
public class OrderController {

  private final OrderService orderService;
  private final MeterRegistry meterRegistry;

  private final Timer orderCreationTimer;
  private final Timer requestTimer;

  private final Counter totalRequestsCounter;
  private final Counter successRequestsCounter;
  private final Counter errorRequestsCounter;

  private final AtomicInteger activeRequests = new AtomicInteger(0);

  @Autowired
  public OrderController(OrderService orderService, MeterRegistry meterRegistry) {
    this.orderService = orderService;
    this.meterRegistry = meterRegistry;

    this.orderCreationTimer = Timer.builder("order.create.duration")
            .description("Tempo para criar um pedido")
            .publishPercentiles(0.5, 0.95, 0.99)
            .publishPercentileHistogram()
            .sla(
                    Duration.ofMillis(50),
                    Duration.ofMillis(100),
                    Duration.ofMillis(500),
                    Duration.ofSeconds(1),
                    Duration.ofSeconds(2)
            )
            .register(meterRegistry);

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

    meterRegistry.gauge("http.requests.active", activeRequests);
  }

  @PostMapping
  public ResponseEntity<OrderResponse> createOrder(@Valid @RequestBody OrderRequest request) {
    int active = activeRequests.incrementAndGet();
    log.info("Requisições ativas: {}", active);

    totalRequestsCounter.increment();

    long startTime = System.nanoTime();

    try {
      OrderResponse response = orderService.createOrder(request);

      successRequestsCounter.increment();

      long duration = System.nanoTime() - startTime;
      orderCreationTimer.record(duration, TimeUnit.NANOSECONDS);
      requestTimer.record(duration, TimeUnit.NANOSECONDS);

      log.info("Pedido criado com sucesso em {}ms", duration / 1_000_000);

      return ResponseEntity.status(HttpStatus.CREATED).body(response);

    } catch (Exception e) {
      errorRequestsCounter.increment();

      long duration = System.nanoTime() - startTime;
      requestTimer.record(duration, TimeUnit.NANOSECONDS);

      log.error("Erro ao criar pedido após {}ms: {}", duration / 1_000_000, e.getMessage());
      throw e;

    } finally {
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