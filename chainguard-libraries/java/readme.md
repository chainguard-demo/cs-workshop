# Chainguard Libraries for Java Workshop
- [Chainguard Libraries for Java Workshop](#chainguard-libraries-for-java-workshop)
  - [🧩 Overview](#-overview)
  - [🧰 Prerequisites](#-prerequisites)
  - [⚙️ Setup](#️-setup)
  - [🧱 Step 1 — Baseline Build (Upstream Maven Central)](#-step-1--baseline-build-upstream-maven-central)
    - [1. Inspect dependencies](#1-inspect-dependencies)
    - [2. View the Dockerfile](#2-view-the-dockerfile)
    - [3. Set build variables](#3-set-build-variables)
    - [4. Build the image](#4-build-the-image)
    - [5. Run and test](#5-run-and-test)
    - [6. Copy the built JAR and scan](#6-copy-the-built-jar-and-scan)
    - [7. Cleanup](#7-cleanup)
  - [🧱 Step 2 — Build Using Chainguard Libraries](#-step-2--build-using-chainguard-libraries)
    - [1. Mint a short-lived token](#1-mint-a-short-lived-token)
    - [2. Review `settings.xml`](#2-review-settingsxml)
    - [3. Set build variables](#3-set-build-variables-1)
    - [4. Review the updated Dockerfile](#4-review-the-updated-dockerfile)
    - [5. Build using Chainguard Libraries](#5-build-using-chainguard-libraries)
    - [6. Run, test, and scan](#6-run-test-and-scan)
    - [7. Cleanup](#7-cleanup-1)
  - [🧱 Step 3 — Full Chainguard Build](#-step-3--full-chainguard-build)
    - [1. Set variables](#1-set-variables)
    - [2. Build with Chainguard Maven and JRE](#2-build-with-chainguard-maven-and-jre)
    - [3. Run and test](#3-run-and-test)
    - [4. Scan with chainctl](#4-scan-with-chainctl)
    - [5. Cleanup](#5-cleanup)
  - [🧱 Step 4 — Java Library Provenance](#-step-4--java-library-provenance)
    - [1. View Java library provenance](#1-view-java-library-provenance)
  - [🧹 Final Cleanup](#-final-cleanup)
  - [🧩 Troubleshooting Tips](#-troubleshooting-tips)


This walkthrough demonstrates:
1. How to rebuild an existing Java application using Chainguard’s verified Maven repository.
2. How to compare dependency sourcing before and after migration.
3. How to build and scan the application using Chainguard's dev and runtime containers.
4. How to view provenance data for Chainguard Java Libraries

**Note:** To run the guided demo magic script instead of following this readme, simply execute the `demo.sh` script in this directory.

---

## 🧩 Overview

We’ll work through three main stages:

1. **Baseline Build (Upstream Maven & Temurin Images):**  
   Build an existing Java app using upstream Maven and Eclipse Temurin images with dependencies from Maven Central.

2. **Chainguard Libraries Migration (Same Upstream Builders):**  
   Build the same app using Chainguard Libraries for dependencies, while keeping the same upstream Maven and Temurin images.

3. **Chainguard Build & Runtime Containers:**  
   Fully rebuild using Chainguard dev and runtime containers with Chainguard Libraries.

4. **View Provenance for Chainguard Java Libraries:**  
   Demonstrate how to view Provenance details for Chainguard Java Libraries.

For this demo all builds will use **containerized environments** to avoid needing to have a local Maven.

---

## 🧰 Prerequisites

- **chainctl** installed and logged in (`chainctl auth login`) as a user with access to the Chainguard org's Java ecosystem entitlements.
> NOTE: The user must have the `libraries.java.pull` role in order to access libraries from `https://libraries.cgr.dev/java/` e.g. `owner` role. Chainctl install docs can be found [here](https://edu.chainguard.dev/chainguard/chainctl-usage/how-to-install-chainctl/)
- **jq** installed for JSON parsing  
- A **Chainguard organization name** (e.g. `myorg.com`) that has Java ecosystem entitlements. 
- Network Access to `https://libraries.cgr.dev/java/`
- Docker installed to run images
---

## ⚙️ Setup
Set the Chainguard organization with entitlements to the Java ecosystem.

```bash
export ORG_NAME="<YOUR Chainguard ORG name>"
```

---

## 🧱 Step 1 — Baseline Build (Upstream Maven Central)
This first stage builds and runs the application exactly as most Java developers would today — using upstream Maven and Eclipse Temurin images and pulling all dependencies from Maven Central.
It provides a baseline for functionality and scanning before any Chainguard content is introduced.


### 1. Inspect dependencies
View the Java dependencies in the pom file:

```bash
# Change Directory into the step1-orig folder
cd cs-workshop/chainguard-libraries/java/step1-orig

# Print only the <dependencies> section from pom.xml to see what the app depends on.
awk '/<dependencies>/,/<\/dependencies>/' pom.xml
```

### 2. View the Dockerfile
View the dockerfile, this is a straightforward dockerfile that builds the app in the first stage and copies it to the runtime image.

```bash
cat Dockerfile
```

### 3. Set build variables

```bash
# Define image tags and names for the baseline build.
TAG="upstream"
BUILDER_IMAGE="maven"
RUNTIME_IMAGE="eclipse-temurin"
```

### 4. Build the image

```bash
# Build the app using the upstream Maven builder and Temurin runtime.
docker build \
  --build-arg BUILDER_IMAGE=$BUILDER_IMAGE \
  --build-arg RUNTIME_IMAGE=$RUNTIME_IMAGE \
  -t java-lib-example:$TAG .
```

### 5. Run and test

```bash
# Start the container and expose port 8081.
docker run -d -p 8081:8080 --name java-lib-example-1 java-lib-example:$TAG

# Verify that the app is responding correctly.
curl http://localhost:8081
```

### 6. Copy the built JAR and scan

```bash
# Copy the generated JAR file out of the running container.
docker cp java-lib-example-1:/app/java-demo-app-1.0.0.jar .

# Analyze the JAR with chainctl to confirm dependencies come from Maven Central.
chainctl libraries verify --parent $ORG_NAME java-demo-app-1.0.0.jar
```

### 7. Cleanup

```bash
# Stop and remove the running container, and delete the copied JAR.
docker stop java-lib-example-1 && docker rm java-lib-example-1 && rm java-demo-app-1.0.0.jar
```

---

## 🧱 Step 2 — Build Using Chainguard Libraries
In this step, you’ll rebuild the same application but redirect Maven to pull its dependencies from Chainguard Libraries.
The build and runtime containers remain the same, proving that you can switch dependency sources without breaking builds or changing code.
After the build, you’ll scan to verify that dependencies now originate from Chainguard’s repository.

### 1. Mint a short-lived token

This is a bearer token from your current chainctl session, narrowed to your
organization. It expires with the session, about an hour, and creates no
identity, so there is nothing to revoke afterwards. For CI systems that cannot
log in interactively, use `chainctl auth pull-token` instead.

```bash
export CGR_TOKEN=$(chainctl auth token --audience=libraries.cgr.dev --scope "$ORG_NAME")
```

### 2. Review `settings.xml`
The settings file declares a mirror of `*` pointing at `https://libraries.cgr.dev/java/`, so every repository request, Maven Central included, goes to Chainguard. There is no client-side fallback: anything Chainguard cannot serve fails the build rather than quietly coming from Maven Central. The token is referenced as an environment variable, which the Dockerfile supplies from a build secret, and the registry ignores the username when the password is a session token.

```bash
cat settings.xml
```

### 3. Set build variables

```bash
# Define a new tag to differentiate this build.
TAG="upstream-cg-libs"
BUILDER_IMAGE="maven"
RUNTIME_IMAGE="eclipse-temurin"
```

### 4. Review the updated Dockerfile
Compared with step 1, the Dockerfile copies `settings.xml` into the build and mounts the token as a build secret that is exposed to the `mvn` step as the `CGR_TOKEN` environment variable. It never lands in a layer or in the build log.

```bash
git diff --no-index -U1000 Dockerfile ../step2-cg-build/Dockerfile
```

### 5. Build using Chainguard Libraries

```bash
# Build the app using Maven with Chainguard Libraries for dependency resolution.
docker build \
  -t java-lib-example:$TAG \
  --build-arg BUILDER_IMAGE=$BUILDER_IMAGE \
  --build-arg RUNTIME_IMAGE=$RUNTIME_IMAGE \
  --secret id=cgr_token,env=CGR_TOKEN \
  -f ../step2-cg-build/Dockerfile .
```

### 6. Run, test, and scan

```bash
# Start the container and verify it still functions as before.
docker run -d -p 8081:8080 --name java-lib-example-1 java-lib-example:$TAG
curl http://localhost:8081

# Copy the JAR file out for scanning with chainctl.
docker cp java-lib-example-1:/app/java-demo-app-1.0.0.jar .

# Scan with chainctl to determine dependency coverage sourced from Chainguard.
chainctl libraries verify --parent $ORG_NAME java-demo-app-1.0.0.jar
```

### 7. Cleanup

```bash
# Stop and remove the container, then delete the JAR file.
docker stop java-lib-example-1 && docker rm java-lib-example-1 && rm java-demo-app-1.0.0.jar
```

---

## 🧱 Step 3 — Full Chainguard Build
This stage runs the full “secure supply chain” build: using Chainguard’s Maven image as the builder and Chainguard’s JRE as the runtime.
The result is an application where the entire toolchain — builder, runtime, and dependencies — comes from Chainguard.

### 1. Set variables
The same Dockerfile, `settings.xml` and `pom.xml` are used as in step 2; only the images change.

```bash
# Use Chainguard's Maven and JRE images for builder and runtime.
TAG="chainguard-cg-libs"
BUILDER_IMAGE="cgr.dev/chainguard/maven:latest"
RUNTIME_IMAGE="cgr.dev/chainguard/jre:latest"
```

### 2. Build with Chainguard Maven and JRE

```bash
# Build the app using Chainguard’s Maven builder and JRE runtime images.
docker build \
  -t java-lib-example:$TAG \
  --build-arg BUILDER_IMAGE=$BUILDER_IMAGE \
  --build-arg RUNTIME_IMAGE=$RUNTIME_IMAGE \
  --secret id=cgr_token,env=CGR_TOKEN \
  -f ../step2-cg-build/Dockerfile .

```

### 3. Run and test

```bash
# Start the app using the Chainguard-built container.
docker run -d -p 8081:8080 --name java-lib-example-1 java-lib-example:$TAG
sleep 3
curl http://localhost:8081

# Copy the JAR so that we can scan it with chainctl.
docker cp java-lib-example-1:/app/java-demo-app-1.0.0.jar .
```

### 4. Scan with chainctl

Re-scan the jar with chainctl, this should reveal the same results as the previous scan.

```bash
# Scan with chainctl to determine dependency coverage sourced from Chainguard.
chainctl libraries verify --parent $ORG_NAME java-demo-app-1.0.0.jar
```

### 5. Cleanup

```bash
docker stop java-lib-example-1 && docker rm java-lib-example-1 && rm java-demo-app-1.0.0.jar
```
---

## 🧱 Step 4 — Java Library Provenance
### 1. View Java library provenance

Each Java library built by Chainguard is accompanied by an SBOM, the SBOMs are published alongside each artifact as an SPDX JSON file named artifactId-version.spdx.json in the Chainguard Maven Repository. The related files for Chainguard Libraries for Java are located in the same location as the .pom, .jar, and other artifacts for a specific library version. For example, the file location for artifactId spring-boot-starter-web and version 3.3.5 is

`https://libraries.cgr.dev/java/org/springframework/boot/spring-boot-starter-web/3.3.5/.`.

Inspect provenance for a specific package, note that the SBOM indicates that the dependency was built by Chainguard, and the git url and commit hash can be verified.

Download the SBOM for the spring-boot-starter-web library:

```bash
curl -L --user "_token:$CGR_TOKEN" \
  -O https://libraries.cgr.dev/java/org/springframework/boot/spring-boot-starter-web/3.3.5/spring-boot-starter-web-3.3.5.spdx.json
```

View the SBOM file, **Note:** We will use a jq query to only print what we want to look at:

```bash
jq '{spdxVersion, dataLicense, SPDXID, name, documentNamespace, creationInfo, packages: [.packages[0]]}' spring-boot-starter-web-3.3.5.spdx.json | jq .
```

---

## 🧹 Final Cleanup
This removes the images and files created during the workshop. The token expires with your chainctl session, so there is nothing to revoke.

```bash
rm -f spring-boot-starter-web-3.3.5.spdx.json

# Remove the Docker images that were created
docker image ls | grep java-lib-example | awk '{print $3}' | xargs docker image rm $1
```
---

## 🧩 Troubleshooting Tips

- **Docker BuildKit required:**  
  Make sure BuildKit is enabled (`DOCKER_BUILDKIT=1 docker build …`) when using secrets.
- **Credential issues:**  
  If you see 401 or 403 errors from `libraries.cgr.dev`, the token has probably expired with your chainctl session, about an hour. Re-run `chainctl auth token` and rebuild.
- **Port conflicts:**  
  If port `8081` is in use, update the `docker run` command (e.g., `-p 8082:8080`).
- **Missing artifacts:**  
  With the `*` mirror there is no Maven Central fallback, so a 404 from `libraries.cgr.dev` means Chainguard has not built that version and the org's upstream fallback policy did not serve it. Check with `chainctl libraries packages versions maven:<groupId>:<artifactId>`.
