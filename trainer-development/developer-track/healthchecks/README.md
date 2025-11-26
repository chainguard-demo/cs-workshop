# Healthchecks

Some systems (AWS ECS, Docker Compose) require you to execute scripts or
commands inside the container to perform healthchecks.

This becomes a problem for Chainguard Containers which typically don't include
shells or unnecessary utilities which could be used for running healthchecks.

This example demonstrates the issue and a solution.

## Automated Demo

Run `./demo.sh`.
