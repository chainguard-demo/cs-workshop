# Single-stage build: one image handles both compiling and running.
# The JDK (Java Development Kit) includes everything needed — compiler + runtime.
FROM eclipse-temurin:21-jdk

WORKDIR /app

# Copy the source code into the image
COPY src/ src/

# Compile the source code, then package it into a runnable JAR
RUN mkdir out && \
    javac -d out src/HelloServer.java && \
    jar cfe app.jar HelloServer -C out .

ENTRYPOINT ["java", "-jar", "app.jar"]
