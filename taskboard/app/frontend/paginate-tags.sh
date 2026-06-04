#!/usr/bin/env bash
set -euo pipefail

BASE="https://cgr.dev"
URL="${BASE}/v2/rob.best/python/tags/list"
TOKEN="$(chainctl auth token --audience=cgr.dev)"

while :; do
  HEADERS="$(mktemp)"
  BODY="$(curl -sS -D "$HEADERS" -H "Authorization: Bearer ${TOKEN}" "$URL")"

  NEXT="$({ grep -i '^link:' "$HEADERS" || true; } | sed -n 's/.*<\([^>]*\)>; *rel="next".*/\1/p' | head -n1)"
  rm -f "$HEADERS"

  if [[ -z "$NEXT" ]]; then
    printf '%s\n' "$BODY"
    break
  fi

  if [[ "$NEXT" == http* ]]; then
    URL="$NEXT"
  else
    URL="${BASE}${NEXT}"
  fi
done
