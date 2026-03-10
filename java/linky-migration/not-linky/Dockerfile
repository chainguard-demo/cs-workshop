FROM maven:latest
WORKDIR /app
COPY pom.xml image.jpg ./
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests
ENTRYPOINT ["java", "-jar", "target/ascii-converter-1.0-SNAPSHOT.jar", "./image.jpg", "120", "60"]
