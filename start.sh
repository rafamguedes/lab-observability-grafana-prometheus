# start.sh
#!/bin/bash

echo "Starting Order Service Observability Stack..."

# Create necessary directories
mkdir -p prometheus grafana/provisioning/datasources logs tempo

# Set environment variables
export $(cat .env | xargs)

# Build the application
echo "Building application..."
./mvnw clean package -DskipTests

# Build Docker image
echo "Building Docker image..."
docker build -t order-service:latest .

# Start services
echo "Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Check health
echo "Checking service health..."
curl -s http://localhost:8080/actuator/health | jq .

echo ""
echo "Services are running:"
echo "- Order Service: http://localhost:8080"
echo "- Prometheus: http://localhost:9090"
echo "- Grafana: http://localhost:3000 (admin/admin)"
echo "- Tempo: http://localhost:3200"
echo ""
echo "To view logs: docker-compose logs -f"
echo "To stop: docker-compose down"