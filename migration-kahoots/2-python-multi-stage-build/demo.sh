#! env bash

. ../../base.sh

for i in $(docker images -q python-example); do
  docker rmi $i
done

clear

banner "Here's a simple python application and its Dockerfile."
pe "$BATCAT run.py"
pe "$BATCAT requirements.txt"
pe "$BATCAT 0.Dockerfile"

banner "Build the image and run it."
pe "docker build -t python-example:0 -f 0.Dockerfile ."
pe "docker run --rm python-example:0"

banner "Check the size."
pe "docker images python-example:0"

banner "And the vulnerabilities."
pe "grype python-example:0"

banner "Let's migrate it to a Chainguard image."
pe "git diff --no-index -U1000 0.Dockerfile 1.Dockerfile"
pe "docker build -t python-example:1 -f 1.Dockerfile ."

banner "We need to install mariadb in the dev stage."
pe "git diff --no-index -U1000 1.Dockerfile 2.Dockerfile"
pe "docker build -t python-example:2 -f 2.Dockerfile ."
pe "docker run --rm python-example:2"

banner "We need to install mariadb in the runtime stage as well."
pe "git diff --no-index -U1000 2.Dockerfile 3.Dockerfile"
pe "docker build -t python-example:3 -f 3.Dockerfile ."
pe "docker run --rm python-example:3"

banner "It should be signficantly smaller."
pe "docker images python-example:0"
pe "docker images python-example:3"

banner "And it should have a lot less CVEs."
pe "grype python-example:3"
