# Entrypoint Scripts

Existing containers often run entrypoint scripts that perform steps before
running the main application process. Chainguard Containers commonly don’t
include a shell and so entrypoint scripts won’t work.


This is a demonstration of adapting existing workloads to run without an
entrypoint script.

## Requirements

- `envsubst`
- `git`
- `kind`
- `kubectl`

## Automated Demo

Run `./demo.sh`.
