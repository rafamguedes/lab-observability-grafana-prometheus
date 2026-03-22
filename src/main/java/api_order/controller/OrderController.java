package api_order.controller;

import api_order.dto.OrderRequest;
import api_order.dto.OrderResponse;
import api_order.service.OrderService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {

  private final OrderService orderService;

  @PostMapping
  public ResponseEntity<OrderResponse> createOrder(@Valid @RequestBody OrderRequest request) {
    return ResponseEntity.status(HttpStatus.CREATED)
            .body(orderService.createOrder(request));
  }

  @GetMapping("/{id}")
  public ResponseEntity<OrderResponse> getOrder(@PathVariable String id) {
    return ResponseEntity.ok(orderService.getOrder(id));
  }
}