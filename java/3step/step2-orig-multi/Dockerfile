# Multi-stage build: use a larger image to build, then copy only what's needed into a smaller image to run.

# --- Build stage ---
# The JDK (Java Development Kit) includes the compiler (javac) needed to build the app.
FROM eclipse-temurin:25-jdk AS builder

WORKDIR /build

COPY src/ src/

# Compile the source code, then package it into a runnable JAR
RUN mkdir out && \
    javac -d out src/HelloServer.java && \
    jar cfe app.jar HelloServer -C out .

# --- Run stage ---
# The JRE (Java Runtime Environment) can run Java apps but cannot compile them.
# It is smaller than the JDK, so the final image is leaner.
FROM eclipse-temurin:25-jre AS runner

WORKDIR /app

# Copy only the finished JAR from the build stage — nothing else comes along
COPY --from=builder /build/app.jar .

ENTRYPOINT ["java", "-jar", "app.jar"]
