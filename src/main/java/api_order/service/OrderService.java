package api_order.service;

import api_order.dto.OrderRequest;
import api_order.dto.OrderResponse;
import api_order.entity.OrderEntity;
import api_order.repository.OrderRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.observation.annotation.Observed;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.concurrent.atomic.AtomicInteger;

@Slf4j
@Service
public class OrderService {

  private final OrderRepository orderRepository;

  private final Timer requestTimer;
  private final Counter successCounter;
  private final Counter errorCounter;
  private final AtomicInteger activeRequests = new AtomicInteger(0);

  public OrderService(OrderRepository orderRepository, MeterRegistry registry) {
    this.orderRepository = orderRepository;

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

  @Observed(
      name = "order.create",
      contextualName = "creating-order",
      lowCardinalityKeyValues = {"orderType", "purchase"})
  @Transactional
  public OrderResponse createOrder(OrderRequest request) {
    activeRequests.incrementAndGet();
    try {
      return requestTimer.record(
          () -> {
            log.info("Criando pedido: {}", request.getOrderNumber());

            BigDecimal totalAmount =
                request.getUnitPrice().multiply(BigDecimal.valueOf(request.getQuantity()));

            OrderEntity order = new OrderEntity();
            order.setOrderNumber(request.getOrderNumber());
            order.setSupplierId(request.getSupplierId());
            order.setProductId(request.getProductId());
            order.setQuantity(request.getQuantity());
            order.setUnitPrice(request.getUnitPrice());
            order.setTotalAmount(totalAmount);
            order.setStatus("PENDING");
            order.setNotes(request.getNotes());
            order.setCreatedAt(LocalDateTime.now());
            order.setUpdatedAt(LocalDateTime.now());

            OrderEntity saved = orderRepository.save(order);
            log.info("Pedido salvo com ID: {}", saved.getId());

            successCounter.increment();
            return toResponse(saved);
          });
    } catch (Exception e) {
      errorCounter.increment();
      log.error("Erro ao criar pedido: {}", e.getMessage());
      throw e;
    } finally {
      activeRequests.decrementAndGet();
    }
  }

  @Observed(name = "order.get", contextualName = "getting-order")
  @Transactional(readOnly = true)
  public OrderResponse getOrder(String id) {
    log.info("Buscando pedido ID: {}", id);
    return orderRepository
        .findById(id)
        .map(this::toResponse)
        .orElseThrow(
            () -> {
              log.error("Pedido não encontrado: {}", id);
              return new RuntimeException("Order not found");
            });
  }

  private OrderResponse toResponse(OrderEntity order) {
    return OrderResponse.builder()
        .id(order.getId())
        .orderNumber(order.getOrderNumber())
        .supplierId(order.getSupplierId())
        .productId(order.getProductId())
        .quantity(order.getQuantity())
        .unitPrice(order.getUnitPrice())
        .totalAmount(order.getTotalAmount())
        .status(order.getStatus())
        .notes(order.getNotes())
        .createdAt(order.getCreatedAt())
        .updatedAt(order.getUpdatedAt())
        .build();
  }
}
