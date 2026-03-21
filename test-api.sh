# test-api.sh
#!/bin/bash

echo "Testing Order Service API..."

# Create an order
echo "Creating order..."
CREATE_RESPONSE=$(curl -s -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "orderNumber": "PO-2024-001",
    "supplierId": "SUP-001",
    "productId": "PROD-001",
    "quantity": 10,
    "unitPrice": 99.90,
    "notes": "Urgent order"
  }')

echo "Create Response: $CREATE_RESPONSE"

# Extract order ID
ORDER_ID=$(echo $CREATE_RESPONSE | jq -r '.id')
echo "Order ID: $ORDER_ID"

# Get order by ID
echo "Getting order by ID..."
curl -s http://localhost:8080/api/orders/$ORDER_ID | jq .

# Get metrics
echo ""
echo "Prometheus metrics endpoint:"
curl -s http://localhost:8080/actuator/metrics | jq '.names | .[] | select(contains("order"))'

echo ""
echo "Health check:"
curl -s http://localhost:8080/actuator/health | jq .