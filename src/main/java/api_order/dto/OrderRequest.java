package api_order.dto;

import jakarta.validation.constraints.*;
import lombok.Data;
import java.math.BigDecimal;

@Data
public class OrderRequest {

  @NotBlank(message = "Order number is required")
  private String orderNumber;

  @NotBlank(message = "Supplier ID is required")
  private String supplierId;

  @NotBlank(message = "Product ID is required")
  private String productId;

  @NotNull(message = "Quantity is required")
  @Min(value = 1, message = "Quantity must be at least 1")
  private Integer quantity;

  @NotNull(message = "Unit price is required")
  @DecimalMin(value = "0.01", message = "Unit price must be greater than 0")
  private BigDecimal unitPrice;

  private String notes;
}
