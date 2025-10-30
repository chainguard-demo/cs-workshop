# syntax=docker/dockerfile:1.7

FROM cgr.dev/chainguard-private/python:3-dev AS build

USER 0

RUN apk add --no-cache curl 

FROM cgr.dev/chainguard-private/python:3 

ENV TZ="America/New_York"

COPY --from=build /usr/bin/curl /usr/bin/curl

USER 65532