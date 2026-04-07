#! env bash
. ../../base.sh

# Clean up any leftover images from a previous run
for tag in 1 2; do
  docker rmi "nocache:${tag}" 2>/dev/null
  docker rmi "cache:${tag}" 2>/dev/null
  docker rmi "secret:${tag}" 2>/dev/null
done

clear
banner "Exercise 3.1: Cache Mounts — Measure the difference"

$BATCAT Dockerfile.nocache
$BATCAT Dockerfile.cache

# Cold builds — both start with an empty pip cache
pe "docker build --progress=plain . -t nocache:1 -f Dockerfile.nocache 2>&1 | grep -E 'Downloading|Using cached'"
pe "docker build --progress=plain . -t cache:1 -f Dockerfile.cache 2>&1 | grep -E 'Downloading|Using cached'"

# Simulate adding a new dependency
pe "echo 'celery==5.4.0' >> requirements.txt"

# Without cache: layer invalidated — pip re-downloads every package
pe "docker build --progress=plain . -t nocache:2 -f Dockerfile.nocache 2>&1 | grep -E 'Downloading|Using cached'"
# With cache: layer invalidated — pip only downloads celery
pe "docker build --progress=plain . -t cache:2 -f Dockerfile.cache 2>&1 | grep -E 'Downloading|Using cached'"

wait
pe "git checkout requirements.txt"

banner "Exercise 3.2: Secret Mounts — Spot the difference in history"

echo "supersecrettoken" > token.txt

$BATCAT Dockerfile.secret
pe "docker build --secret id=pip_token,src=./token.txt -t secret:1 -f Dockerfile.secret ."
pe "docker image history secret:1"

wait

$BATCAT Dockerfile.nosecret
pe "docker build --build-arg PIP_TOKEN=supersecrettoken -t secret:2 -f Dockerfile.nosecret ."
pe "docker image history secret:2"

rm -f token.txt
