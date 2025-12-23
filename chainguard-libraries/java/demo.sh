#! env bash

###############################################################################
# Demo Magic Script: Java Libraries Workshop
# This script uses demo-magic to simulate a live terminal demo.
###############################################################################

# Load demo-magic
# Ensure demo-magic.sh is in the same directory or adjust the path accordingly
. ../../base.sh

pei cd step1-orig/

# Speed (lower = faster). Use -w for waits and ENTER manually if you prefer.
TYPE_SPEED=100
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
clear

###############################################################################
# Intro
###############################################################################
echo -e "
🧰 Demo: Converting a Java App to Use Chainguard Libraries

This demo walks through taking an existing sample Java application and rebuilding it using Chainguard Libraries for Java.
We’ll demonstrate how to transition from using Maven Central to Chainguard’s trusted library source — without modifying your source code or build process — while gaining improved security and provenance.

To keep everything portable and reproducible, the demo uses containerized builds rather than local Maven setups.

The application is a simple Java Spring Boot application that returns a string when a post is sent.

The demo includes three main stages:
1. Baseline Build (Upstream Maven & Temurin Images):
   - Build the Java application using upstream Maven build containers and an Eclipse Temurin runtime container.
   - This represents a typical Java build pipeline that relies on Maven Central for dependencies.
   - Verify the application runs successfully, then scan the resulting image to confirm that all dependencies are sourced from Maven Central.

2. Chainguard Libraries Migration (Same Upstream Builders):
   - Rebuild the same application using Chainguard Libraries for Java, keeping the same upstream Maven and Temurin containers.
   - Demonstrate that switching dependency sources has no impact on functionality.
   - Re-scan the image to show that dependencies are now covered by Chainguard’s verified library set.

3. Chainguard Build & Runtime Containers:
   - Rebuild and run the application using both Chainguard’s build and runtime container images together with Chainguard Libraries.
   - Perform a final scan to confirm full coverage from Chainguard’s trusted ecosystem and show that the application still functions as expected.

4. Lastly we will look at how to view provenance for Chainguard Libraries for Java. We will look at an SBOM for one of the dependencies and discuss some key attributes.

Let's get started!
"
wait

###############################################################################
# Setup
###############################################################################

banner "# Let's start by setting up some environment variables."
pei "ECOSYSTEM=\"java\""
pei "TOKEN_NAME=\"java-libraries-workshop-token-$USER\""
pei "TTL=\"8760h\""
pei ""
pei ""

read -p "Enter your Chainguard organization name (e.g. myorg.com): " ORG_NAME
export ORG_NAME

###############################################################################
# Step 1: Build with Upstream and Maven Central
###############################################################################
banner "Step 1: Build and run using upstream Java images and Maven Central - Let's get a baseline by building our app as is, without using Chainguard Libraries"

pei "# We will build a sample Java app using Maven Central for dependencies and the upstream maven image."
pei "# Lets take a look at the pom file first, if you focus on the dependencies you'll see some standard spring boot dependencies are needed for the build:"
pe "awk '/<dependencies>/,/<\/dependencies>/' pom.xml"
pei ""

p "# Let's take a look at the dockerfile:"
pei 'cat Dockerfile'
pei ""

p '# Now lets set our builder and runtime image and build the project. This is a simple spring boot app that returns a sting when sending a request.'
pei "TAG=\"upstream\""
pei "BUILDER_IMAGE=\"maven\""
pei "RUNTIME_IMAGE=\"eclipse-temurin\""

pei 'docker build --build-arg BASE_IMAGE=$BUILDER_IMAGE --build-arg RUNTIME_IMAGE=$RUNTIME_IMAGE -t java-lib-example:$TAG .'

p "# Run the container and test it."
pei 'docker run -d -p 8081:8080 --name java-lib-example-1 java-lib-example:$TAG'

pe 'curl http://localhost:8081'
pei ""

p "# Copy the built jar file from the container locally so we can scan it with chainctl."
pei 'docker cp java-lib-example-1:/app/java-demo-app-1.0.0.jar .'

p "# Analyze the image and jar with chainctl."
pei 'chainctl libraries verify --parent $ORG_NAME java-demo-app-1.0.0.jar'

# clean up
pei "# Stop the running container and remove the local jar file:"
pei 'docker stop java-lib-example-1 && docker rm java-lib-example-1 && rm java-demo-app-1.0.0.jar'

###############################################################################
# Step 2: Build with Chainguard Libraries (Upstream Maven)
###############################################################################
banner "Step 2: Build using Chainguard Libraries with upstream Maven and Temurin Images."

p "# In order to use Chainguard Libraries for Java to build our app, we will need to create a pull token for the Java ecosystem. Press enter to create your token."
pei 'CREDS_OUTPUT=$(chainctl auth pull-token --library-ecosystem="${ECOSYSTEM}" --parent="${ORG_NAME}" --name="${TOKEN_NAME}" --ttl="${TTL}" -o json)'
pei 'CGR_MAVEN_USER=$(echo $CREDS_OUTPUT | jq -r ".identity_id")'
pei 'CGR_MAVEN_PASS=$(echo $CREDS_OUTPUT | jq -r ".token")'

pe "# Now that we have our credentials we need to create a settings.xml file to configure it to use the Chainguard repo, notice that we are referencing our credentials in the file as environment variables:"
pei 'cat settings.xml'
pei ""


pe '# Now lets set our tag, builder and runtime image and build the same app as before but using chainguard libraries.'
pei "TAG=\"upstream-cg-libs\""
pei "BUILDER_IMAGE=\"maven\""
pei "RUNTIME_IMAGE=\"eclipse-temurin\""

pe "# Lets take a look at the dockerfile as it is slightly different from before, notice that we will be passing in our credentials as build secrets so that they are not stored in the layers or in the builder logs:"
pei 'cat ../step2-cg-build/Dockerfile'
pei ""

pei "# Below is the command we will use to build the image, notice we are passing in the credentials as build secrets."
pe "docker build \
  -t java-lib-example:\$TAG \
  --build-arg BUILDER_IMAGE=\$BUILDER_IMAGE \
  --build-arg RUNTIME_IMAGE=\$RUNTIME_IMAGE \
  --secret id=cgr_user,src=<(echo -n \"\$CGR_MAVEN_USER\") \
  --secret id=cgr_pass,src=<(echo -n \"\$CGR_MAVEN_PASS\") \
  -f ../step2-cg-build/Dockerfile ."

p "# Run the container and test it."
pei 'docker run -d -p 8081:8080 --name java-lib-example-1 java-lib-example:$TAG'
pe 'curl http://localhost:8081'
pei ""

p "# Copy the built jar file from the container locally so we can scan it with chainctl."
pei 'docker cp java-lib-example-1:/app/java-demo-app-1.0.0.jar .'

p "# Analyze the image and jar with chainctl."
pei 'chainctl libraries verify --parent $ORG_NAME java-demo-app-1.0.0.jar'

# clean up
pei "# Stop the running container and remove the local jar file:"
pei 'docker stop java-lib-example-1 && docker rm java-lib-example-1 && rm java-demo-app-1.0.0.jar'

###############################################################################
# Step 3: Build Fully Chainguard (Image + Libraries)
###############################################################################
banner "Step 3: Full Chainguard Build (Chainguard Java images + Chainguard Libraries for Java)"
pei "# In this step we will use the same app but this time we will build with Chainguard libraries, using the Chainguard maven image and jre runtime."
pe '# Now lets set our tag, builder and runtime image and build the same app as before but using chainguard libraries.'
pei "TAG=\"chainguard-cg-libs\""
pei "BUILDER_IMAGE=\"cgr.dev/chainguard/maven:latest\""
pei "RUNTIME_IMAGE=\"cgr.dev/chainguard/jre:latest\""
pei "MAVEN_SETTINGS_PATH=\"/usr/share/java/maven/conf/settings.xml\""

pei "# For this build we will use the same settings.xml and pom.xml file as in the previous step."
pe "docker build \
  -t java-lib-example:\$TAG \
  --build-arg BUILDER_IMAGE=\$BUILDER_IMAGE \
  --build-arg RUNTIME_IMAGE=\$RUNTIME_IMAGE \
  --build-arg MAVEN_SETTINGS_PATH=\$MAVEN_SETTINGS_PATH \
  --secret id=cgr_user,src=<(echo -n \"\$CGR_MAVEN_USER\") \
  --secret id=cgr_pass,src=<(echo -n \"\$CGR_MAVEN_PASS\") \
  -f ../step2-cg-build/Dockerfile ."

p "# Run the container and test it."
pei 'docker run -d -p 8081:8080 --name java-lib-example-1 java-lib-example:$TAG'
pe 'curl http://localhost:8081'
pei ""

p "# Copy the built jar file from the container locally so we can scan it with chainctl."
pei 'docker cp java-lib-example-1:/app/java-demo-app-1.0.0.jar .'

p "# Analyze the image and jar with chainctl."
pei 'chainctl libraries verify --parent $ORG_NAME java-demo-app-1.0.0.jar'

p "# Cleanup: Stop the container and delete the jar."
pei 'docker stop java-lib-example-1 && docker rm java-lib-example-1 && rm java-demo-app-1.0.0.jar'

###############################################################################
# Step 4. Provenance
###############################################################################
banner "Step 4: View Java Library Provenance"
pei "# Each Java dependency built by Chainguard is accompanied by an SBOM, the SBOMs are published alongside each artifact as an SPDX JSON file named artifactId-version.spdx.json in the Chainguard Maven Repository."
pei '# chainctl compares the package checksum with the one listed in the SBOM to determine if the package was built by Chainguard or not. Lets take a look at the SBOM for the spring-boot-starter-web dependency, we will start by downloading the SBOM from the Chainguard Maven repository:'
pei "curl -L --user \"\$CGR_MAVEN_USER:\$CGR_MAVEN_PASS\" \
  -O https://libraries.cgr.dev/java/org/springframework/boot/spring-boot-starter-web/3.3.5/spring-boot-starter-web-3.3.5.spdx.json"
pei '# Now lets take a look at the relevant section of the SBOM:'
pe "jq '{spdxVersion, dataLicense, SPDXID, name, documentNamespace, creationInfo, packages: [.packages[0]]}' spring-boot-starter-web-3.3.5.spdx.json | jq ."
pei ""

###############################################################################
# Final Cleanup
###############################################################################
banner "Final cleanup delete local files and delete the Chainguard pull token"
pei "ID=\$(chainctl iam ids ls --parent=\"\${ORG_NAME}\" -o json | jq -r --arg name \"\${TOKEN_NAME}\" '.items[] | select(.name | startswith(\$name)) | .id')"
pei 'chainctl iam identities delete "$ID" --parent "$ORG_NAME" --yes'
pei 'rm spring-boot-starter-web-3.3.5.spdx.json'

p "# Demo complete!"
exit 0