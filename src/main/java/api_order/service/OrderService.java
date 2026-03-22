package api_order.service;

import api_order.dto.OrderRequest;
import api_order.dto.OrderResponse;
import api_order.entity.OrderEntity;
import api_order.repository.OrderRepository;
import io.micrometer.observation.annotation.Observed;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Slf4j
@Service
@RequiredArgsConstructor
public class OrderService {

  private final OrderRepository orderRepository;

  @Observed(
      name = "order.create",
      contextualName = "creating-order",
      lowCardinalityKeyValues = {"orderType", "purchase"})
  @Transactional
  public OrderResponse createOrder(OrderRequest request) {
    log.info("Creating new purchase order: {}", request.getOrderNumber());

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

    OrderEntity savedOrder = orderRepository.save(order);
    log.info("Order created successfully with ID: {}", savedOrder.getId());

    return toResponse(savedOrder);
  }

  @Observed(name = "order.get", contextualName = "getting-order")
  @Transactional(readOnly = true)
  public OrderResponse getOrder(String id) {
    log.info("Fetching order with ID: {}", id);

    OrderEntity order =
        orderRepository
            .findById(id)
            .orElseThrow(
                () -> {
                  log.error("Order not found with ID: {}", id);
                  return new RuntimeException("Order not found");
                });

    return toResponse(order);
  }

  private static OrderResponse toResponse(OrderEntity savedOrder) {
    return OrderResponse.builder()
        .id(savedOrder.getId())
        .orderNumber(savedOrder.getOrderNumber())
        .supplierId(savedOrder.getSupplierId())
        .productId(savedOrder.getProductId())
        .quantity(savedOrder.getQuantity())
        .unitPrice(savedOrder.getUnitPrice())
        .totalAmount(savedOrder.getTotalAmount())
        .status(savedOrder.getStatus())
        .notes(savedOrder.getNotes())
        .createdAt(savedOrder.getCreatedAt())
        .updatedAt(savedOrder.getUpdatedAt())
        .build();
  }
}
