#! env bash
. ../../base.sh
export GIT_PAGER=cat

# Clean up any leftover images from a previous run
for tag in 1 2 3; do
  docker rmi "nocache:${tag}" 2>/dev/null
  docker rmi "cache:${tag}" 2>/dev/null
  docker rmi "secret:${tag}" 2>/dev/null
done
# Empty the pip cache mount so the first cache build really is cold. This prunes every
# cache mount on the machine. Do not reach for --no-cache instead: with uid= on the mount
# it makes BuildKit hand each build a fresh, empty cache mount.
docker builder prune -f --filter type=exec.cachemount >/dev/null

clear
banner "Exercise 3.1: Cache Mounts — Measure the difference"

# The only change is on the RUN line: a cache mount that outlives the layer
pe "git diff --no-index -U1000 Dockerfile.nocache Dockerfile.cache"

# Make requirements.txt unique to this run so Docker's layer cache cannot skip the install step
pei "echo '# run $(date +%s)' >> requirements.txt"

# Cold builds — both start with an empty pip cache
pe "docker build --progress=plain . -t nocache:1 -f Dockerfile.nocache 2>&1 | grep -E 'Downloading|Using cached'"
pe "docker build --progress=plain . -t cache:1 -f Dockerfile.cache 2>&1 | grep -E 'Downloading|Using cached'"

# Simulate adding a new dependency
pe "echo 'celery==5.4.0' >> requirements.txt"

# Without cache: layer invalidated — pip re-downloads every package
pe "docker build --progress=plain . -t nocache:2 -f Dockerfile.nocache 2>&1 | grep -E 'Downloading|Using cached'"
# With cache: layer invalidated — pip only downloads celery
pe "docker build --progress=plain . -t cache:2 -f Dockerfile.cache 2>&1 | grep -E 'Downloading|Using cached'"

# Rebuild the layer once more without changing any package: everything now comes from the cache mount
pei "echo '# rebuild' >> requirements.txt"
pe "docker build --progress=plain . -t cache:3 -f Dockerfile.cache 2>&1 | grep -E 'Downloading|Using cached'"

wait
pe "git checkout requirements.txt"

banner "Exercise 3.2: Secret Mounts — Pass a token to pip without baking it in"

echo -n "supersecrettoken" > token.txt

# Both Dockerfiles hand pip the same PIP_INDEX_URL. One sets it with ARG + ENV, which lands in
# the image; the other exposes it from a secret mount for the one RUN step that needs it.
pe "git diff --no-index -U1000 Dockerfile.nosecret Dockerfile.secret"

pe "docker build --build-arg PIP_TOKEN=supersecrettoken -t secret:1 -f Dockerfile.nosecret ."
# The token shows up in the layer history, in the image config, and in every container's environment
pe "docker image history secret:1 | grep -n supersecrettoken"
pe "docker inspect secret:1 --format '{{.Config.Env}}'"
pe "docker run --rm --entrypoint env secret:1 | grep PIP"

wait

pe "docker build --secret id=pip_token,src=./token.txt -t secret:2 -f Dockerfile.secret ."
# Same checks: nothing to find
pe "docker image history secret:2 | grep -c supersecrettoken"
pe "docker inspect secret:2 --format '{{.Config.Env}}'"
pe "docker run --rm --entrypoint env secret:2 | grep PIP"

rm -f token.txt
