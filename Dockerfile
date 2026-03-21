# Dockerfile.fixed
FROM maven:3.9.5-eclipse-temurin-17 AS builder
WORKDIR /build

# Copiar arquivos do projeto
COPY pom.xml .
COPY src ./src

# Baixar dependências e construir
RUN mvn clean package -DskipTests

# Criar diretório de destino
RUN mkdir -p /app

# Copiar o JAR para o diretório de destino
RUN cp target/*.jar /app/app.jar

# Verificar se o JAR foi copiado
RUN ls -la /app

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Copiar JAR da fase anterior
COPY --from=builder /app/app.jar .

# Verificar se o JAR está presente
RUN ls -la /app

EXPOSE 8080

# Usar array syntax para melhor handling de sinais
ENTRYPOINT ["java", "-jar", "app.jar"]