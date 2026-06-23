#! env bash

. ../../base.sh

for i in $(docker images -q dotnet-example); do
  docker rmi $i
done

clear

banner "Here's a simple .NET application and its Dockerfile."
pe "$BATCAT Program.cs"
pe "$BATCAT 0.Dockerfile"

banner "Build the image and run it."
pe "docker build -t dotnet-example:0 -f 0.Dockerfile ."
pe "docker run --rm dotnet-example:0"

banner "Check the size."
pe "docker images dotnet-example:0"

banner "And the vulnerabilities."
pe "grype dotnet-example:0"

banner "Let's migrate it to a Chainguard image."
pe "git diff --no-index -U1000 0.Dockerfile 1.Dockerfile"
pe "docker build -t dotnet-example:1 -f 1.Dockerfile ."
pe "docker run --rm dotnet-example:1"

banner "It should be signficantly smaller."
pe "docker images dotnet-example"

banner "And it should have a lot less CVEs."
pe "grype dotnet-example:1"
