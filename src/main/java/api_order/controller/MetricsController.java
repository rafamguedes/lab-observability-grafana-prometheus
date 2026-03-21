package api_order.controller;

import io.micrometer.core.instrument.MeterRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/metrics")
@RequiredArgsConstructor
public class MetricsController {

  private final MeterRegistry meterRegistry;

  @GetMapping
  public Map<String, Object> getCustomMetrics() {
    Map<String, Object> metrics = new HashMap<>();

    metrics.put("orders_created_total", meterRegistry.counter("order.create.total").count());
    metrics.put("orders_created_success", meterRegistry.counter("order.create.success").count());
    metrics.put("orders_created_errors", meterRegistry.counter("order.create.error").count());

    return metrics;
  }
}
