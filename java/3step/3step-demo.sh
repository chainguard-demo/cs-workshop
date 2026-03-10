#! env bash
. ../../base.sh

for i in $(docker ps -a --format '{{.Names}}' | grep java-example-); do
  docker rm -f $i
done

for i in $(docker images -q java-example); do
  docker rmi $i
done


clear
banner "Step 1: A simple Java app built and run in a single stage using the 'eclipse-temurin:21-jdk' image."
pe "$BATCAT ./step1-orig/Dockerfile"
pe "docker build -t java-example:1 ./step1-orig"
pe "docker run -d -p 8081:8080 --name java-example-1 java-example:1"
pe "curl http://localhost:8081"
echo

wait
clear
banner "Step 2: Multi-stage build — 'eclipse-temurin:21-jdk' to compile, 'eclipse-temurin:21-jre' to run."
pe "git diff --no-index -U1000 ./step1-orig/Dockerfile ./step2-orig-multi/Dockerfile"
pe "docker build -t java-example:2 ./step2-orig-multi"
pe "docker run -d -p 8082:8080 --name java-example-2 java-example:2"
pe "curl http://localhost:8082"
echo
pe "docker images java-example"
pe "grype java-example:1"
pe "grype java-example:2"

wait
clear
banner "Step 3: Multi-stage build using Chainguard 'jdk' and 'jre' images."
pe "git diff --no-index -U1000 ./step2-orig-multi/Dockerfile ./step3-cg-multi/Dockerfile"
pe "docker build -t java-example:3 ./step3-cg-multi"
pe "docker run -d -p 8083:8080 --name java-example-3 java-example:3"
pe "curl http://localhost:8083"
echo
pe "docker images java-example"
pe "grype java-example:3"
pe "grype cgr.dev/chainguard/jre"


