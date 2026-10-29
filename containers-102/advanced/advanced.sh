#! env bash
. ../../base.sh

for i in $(docker images -q advanced); do
  docker rmi $i
done

clear
banner "Idea 1: Using the -dev tag variant and removing packages"
$BATCAT Dockerfile.1
pe "docker build . -t advanced:1 -f Dockerfile.1"
pe "docker images advanced"
pe "docker image history advanced:1"

wait
banner "Idea 2: Using a chroot'ed apk add"
$BATCAT Dockerfile.2
pe "docker build . -t advanced:2 -f Dockerfile.2"
pe "docker images advanced"
pe "docker image history advanced:2"

# The runtime image has no apk and no shell, but jq and its libraries are in place
pe "echo '{\"image\": \"advanced:2\", \"shell\": false}' | docker run --rm -i --entrypoint jq advanced:2 '.image'"
pe "docker run --rm --entrypoint sh advanced:2 -c 'echo there is no shell here'"

