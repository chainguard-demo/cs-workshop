ARG BUILDER_IMAGE="maven"
ARG RUNTIME_IMAGE="eclipse-temurin"

FROM ${BUILDER_IMAGE} AS builder
WORKDIR /work

# Define a build argument with a default value for upstream maven image
ARG MAVEN_SETTINGS_PATH=/usr/share/maven/conf/settings.xml
ENV MAVEN_SETTINGS_PATH=${MAVEN_SETTINGS_PATH}

# update mvn settings.xml
USER root

COPY settings.xml ${MAVEN_SETTINGS_PATH}

COPY src/ src/
COPY pom.xml pom.xml

#Read secrets from /run/secrets during build
RUN --mount=type=secret,id=cgr_user,target=/run/secrets/cgr_user \
    --mount=type=secret,id=cgr_pass,target=/run/secrets/cgr_pass \
    export CGR_MAVEN_USER=$(cat /run/secrets/cgr_user) && \
    export CGR_MAVEN_PASS=$(cat /run/secrets/cgr_pass) && \
    mvn clean package -U

ENTRYPOINT ["java", "-jar", "java-demo-app-1.0.0.jar"]

FROM ${RUNTIME_IMAGE} AS runner
WORKDIR /app

COPY --from=builder /work/target/java-demo-app-1.0.0.jar .

ENTRYPOINT ["java", "-jar", "java-demo-app-1.0.0.jar"]