#! env bash

. ../../../base.sh

docker-compose -f docker-compose-0.yml down
docker-compose -f docker-compose-1.yml down
docker-compose -f docker-compose-2.yml down
docker-compose -f docker-compose-3.yml down

clear

banner "Here's a docker compose file that healthchecks nginx with curl."
pe "$BATCAT docker-compose-0.yml"
pe "docker-compose -f docker-compose-0.yml up -d --remove-orphans"
pe "sleep 5"
pe "curl localhost:8080"
pe "docker inspect --format='{{json .State.Health}}' healthchecks-nginx-example-0-1"

banner "Let's try to migrate it to Chainguard."
pe "git diff --no-index -U1000 docker-compose-0.yml docker-compose-1.yml"
pe "docker-compose -f docker-compose-1.yml up -d --remove-orphans"
pe "sleep 5"
pe "curl localhost:8081"
pe "docker inspect --format='{{json .State.Health}}' healthchecks-nginx-example-1-1"

banner "Let's try with CMD."
pe "git diff --no-index -U1000 docker-compose-1.yml docker-compose-2.yml"
pe "docker-compose -f docker-compose-2.yml up -d --remove-orphans"
pe "sleep 5"
pe "curl localhost:8082"
pe "docker inspect --format='{{json .State.Health}}' healthchecks-nginx-example-2-1"

banner "Let's add curl to the nginx image."
pe "$BATCAT Dockerfile"
pe "git diff --no-index -U1000 docker-compose-2.yml docker-compose-3.yml"
pe "docker-compose -f docker-compose-3.yml up -d --remove-orphans"
pe "sleep 5"
pe "curl localhost:8083"
pe "docker inspect --format='{{json .State.Health}}' healthchecks-nginx-example-3-1"

banner "We've added curl but we still don't have a shell"
pe "docker exec -it healthchecks-nginx-example-3-1 sh"
pe "docker exec -it healthchecks-nginx-example-3-1 bash"
