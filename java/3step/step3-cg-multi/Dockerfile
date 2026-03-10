# Multi-stage build using Chainguard images.
# Same structure as before — but the base images are minimal and hardened.

# --- Build stage ---
# Chainguard JDK: compile the app using a hardened JDK base image
FROM cgr.dev/chainguard/jdk:latest AS builder

WORKDIR /build

COPY src/ src/

# Compile the source code, then package it into a runnable JAR
RUN mkdir out && \
    javac -d out src/HelloServer.java && \
    jar cfe app.jar HelloServer -C out .

# --- Run stage ---
# Chainguard JRE: minimal, hardened runtime — ships with far fewer CVEs
FROM cgr.dev/chainguard/jre:latest AS runner

WORKDIR /app

# Copy only the finished JAR from the build stage
COPY --from=builder /build/app.jar .

ENTRYPOINT ["java", "-jar", "app.jar"]
