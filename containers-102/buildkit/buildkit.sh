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
pe "time docker build . -t cache:1 -f Dockerfile.nocache"
pe "echo '# invalidate cache' >> requirements.txt"
pe "time docker build . -t cache:1 -f Dockerfile.nocache"

wait
pe "git checkout requirements.txt"
pe "docker system prune -a"

$BATCAT Dockerfile.cache
pe "time docker build . -t cache:2 -f Dockerfile.cache"
pe "echo '# invalidate cache' >> requirements.txt"
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
