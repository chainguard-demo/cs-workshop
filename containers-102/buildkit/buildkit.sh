#! env bash
. ../../base.sh

# Clean up any leftover images from a previous run
for tag in 1 2; do
  docker rmi "cache:${tag}" 2>/dev/null
  docker rmi "secret:${tag}" 2>/dev/null
done

clear
banner "Exercise 3.1: Cache Mounts — Measure the difference"

$BATCAT Dockerfile.nocache
p "docker build . -t cache:1 -f Dockerfile.nocache"
docker build . -t cache:1 -f Dockerfile.nocache --quiet

pe "touch requirements.txt"
pe "time docker build . -t cache:1 -f Dockerfile.nocache"

wait

$BATCAT Dockerfile.cache
p "docker build . -t cache:2 -f Dockerfile.cache"
docker build . -t cache:2 -f Dockerfile.cache --quiet

pe "touch requirements.txt"
pe "time docker build . -t cache:2 -f Dockerfile.cache"

wait

banner "Exercise 3.2: Secret Mounts — Spot the difference in history"

echo "supersecrettoken" > token.txt

$BATCAT Dockerfile.secret
pe "docker build --secret id=pip_token,src=./token.txt -t secret:1 ."
pe "docker image history secret:1"

wait

$BATCAT Dockerfile.nosecret
pe "docker build --build-arg PIP_TOKEN=supersecrettoken -t secret:2 -f Dockerfile.nosecret ."
pe "docker image history secret:2"

rm -f token.txt
