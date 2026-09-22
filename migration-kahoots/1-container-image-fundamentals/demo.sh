#! env bash
. ../../base.sh
TAGS=$(docker images layers --format json  | jq -r .Tag)
for tag in $TAGS; do
  docker rmi layers:$tag
done

clear
banner "Step 1: Get a big file, untar it, and remove the tarball"
pe "$BATCAT 0.Dockerfile"
pe "docker build . -t layers:0 -f 0.Dockerfile"
pe "docker images layers:0"
pe "docker image history layers:0"
pe "dive layers:0"
wait

banner "Step 2: Concatenate operations into a single RUN line"
pe "git diff --no-index -U1000 0.Dockerfile 1.Dockerfile"
pe "docker build . -t layers:1 -f 1.Dockerfile"
pe "docker images layers"
pe "docker image history layers:0"
pe "docker image history layers:1"
pe "dive layers:1"

banner "Step 3: Use multiple stages"
pe "git diff --no-index -U1000 0.Dockerfile 2.Dockerfile"
pe "docker build . -t layers:2 -f 2.Dockerfile"
pe "docker images layers"
pe "docker image history layers:0"
pe "docker image history layers:2"
pe "dive layers:2"
