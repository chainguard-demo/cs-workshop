# Build stage
FROM maven:3-jdk-8-slim AS build
WORKDIR /app

COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn dependency:go-offline -B

COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn clean package -DskipTests

FROM amazoncorretto:8u192
WORKDIR /app

COPY --from=build /app/target/chat-app-1.0.0.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-Dcom.sun.jndi.ldap.object.trustURLCodebase=true", "-Dcom.sun.jndi.rmi.object.trustURLCodebase=true", "-jar", "app.jar"]
