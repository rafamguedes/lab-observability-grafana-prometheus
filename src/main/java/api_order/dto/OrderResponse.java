package api_order.dto;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
public class OrderResponse {
  private String id;
  private String orderNumber;
  private String supplierId;
  private String productId;
  private Integer quantity;
  private BigDecimal unitPrice;
  private BigDecimal totalAmount;
  private String status;
  private String notes;
  private LocalDateTime createdAt;
  private LocalDateTime updatedAt;
}
