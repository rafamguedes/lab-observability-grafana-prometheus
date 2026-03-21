package api_order.repository;

import api_order.entity.OrderEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface OrderRepository extends JpaRepository<OrderEntity, String> {
  Optional<OrderEntity> findByOrderNumber(String orderNumber);

  List<OrderEntity> findBySupplierId(String supplierId);

  List<OrderEntity> findByStatus(String status);
}
