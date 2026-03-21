package api_order.service;

import api_order.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class DatabaseHealthIndicator implements HealthIndicator {

  private final OrderRepository orderRepository;

  @Override
  public Health health() {
    try {
      long count = orderRepository.count();
      return Health.up()
          .withDetail("database", "PostgreSQL")
          .withDetail("records_count", count)
          .build();
    } catch (Exception e) {
      return Health.down().withDetail("error", e.getMessage()).build();
    }
  }
}
