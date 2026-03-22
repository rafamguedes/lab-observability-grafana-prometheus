package api_order.controller;

import api_order.dto.OrderRequest;
import api_order.dto.OrderResponse;
import api_order.service.OrderService;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.concurrent.atomic.AtomicInteger;

@RestController
@RequestMapping("/api/orders")
@Slf4j
public class OrderController {

  private final OrderService orderService;

  private final Timer requestTimer;
  private final Counter successCounter;
  private final Counter errorCounter;
  private final AtomicInteger activeRequests = new AtomicInteger(0);

  @Autowired
  public OrderController(OrderService orderService, MeterRegistry registry) {
    this.orderService = orderService;

    this.requestTimer =
        Timer.builder("http_request_duration_seconds")
            .description("Tempo de resposta das requisições HTTP")
            .publishPercentiles(0.5, 0.95, 0.99)
            .publishPercentileHistogram()
            .tag("endpoint", "/api/orders")
            .register(registry);

    this.successCounter =
        Counter.builder("http_requests_total")
            .tag("endpoint", "/api/orders")
            .tag("status", "success")
            .register(registry);

    this.errorCounter =
        Counter.builder("http_requests_total")
            .tag("endpoint", "/api/orders")
            .tag("status", "error")
            .register(registry);

    registry.gauge("http_requests_active", activeRequests);
  }

  @PostMapping
  public ResponseEntity<OrderResponse> createOrder(@Valid @RequestBody OrderRequest request) {
    activeRequests.incrementAndGet();
    try {
      return requestTimer.record(
          () -> {
            OrderResponse response = orderService.createOrder(request);
            successCounter.increment();
            log.info("Pedido criado: {}", response.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
          });
    } catch (Exception e) {
      errorCounter.increment();
      log.error("Erro ao criar pedido: {}", e.getMessage());
      throw e;
    } finally {
      activeRequests.decrementAndGet();
    }
  }

  @GetMapping("/{id}")
  public ResponseEntity<OrderResponse> getOrder(@PathVariable String id) {
    try {
      OrderResponse response = requestTimer.record(() -> orderService.getOrder(id));
      successCounter.increment();
      return ResponseEntity.ok(response);
    } catch (Exception e) {
      errorCounter.increment();
      throw e;
    }
  }
}
