# Stage 1: Build the app and create a minimal JRE with jlink
FROM cgr.dev/chainguard-private/jdk:openjdk-25-dev AS builder

COPY --from=cgr.dev/chainguard-private/glibc-dynamic / /base-chroot
USER root
RUN apk add --no-commit-hooks --no-cache --root /base-chroot zlib
USER 65532

WORKDIR /app

# Copy source and compile
COPY src/ src/
RUN javac -d out src/Hello.java

# Package into a JAR
RUN jar --create --file app.jar --main-class Hello -C out .

# Use jdeps to discover required modules, then jlink to assemble a minimal JRE
RUN MODULES=$(jdeps --ignore-missing-deps --print-module-deps app.jar 2>/dev/null | tail -1) && \
    jlink \
    --no-header-files \
    --no-man-pages \
    --add-modules "$MODULES" \
    --output custom-jre

# Stage 2: Minimal runtime — only the glibc dynamic linker base + our custom JRE
FROM cgr.dev/chainguard-private/glibc-dynamic

WORKDIR /app

COPY --from=builder /base-chroot /
COPY --from=builder /app/custom-jre /opt/jre
COPY --from=builder /app/app.jar .

ENTRYPOINT ["/opt/jre/bin/java", "-jar", "app.jar"]
