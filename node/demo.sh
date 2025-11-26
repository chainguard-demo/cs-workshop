#! env bash
. ../base.sh

for i in $(docker images -q node-example); do
  docker rmi $i
done

clear
banner "Here's an existing application and its Dockerfile."
pe "$BATCAT index.js"
pe "$BATCAT notlinky.Dockerfile"

banner "Build and run the image."
pe "docker build -t node-example:notlinky -f notlinky.Dockerfile --build-arg IMAGE=notlinky.jpg ."
pe "docker run --rm node-example:notlinky"

banner "Let's migrate it to a Chainguard image."
pe "git diff --no-index -U1000 notlinky.Dockerfile linky.Dockerfile"
pe "docker build -t node-example:linky -f linky.Dockerfile --build-arg IMAGE=linky.jpg ."
pe "docker run --rm node-example:linky"

banner "It should be significantly smaller."
pe "docker images node-example"

banner "And have significantly less vulnerabilities."
pe "grype node-example:notlinky"
pe "grype node-example:linky"
