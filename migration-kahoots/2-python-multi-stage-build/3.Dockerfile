FROM cgr.dev/chainguard/python:latest-dev AS dev

# The python image on DockerHub includes mariadb packages as standard but we
# need to add them explicitly.
USER root
RUN apk add --no-cache mariadb-connector-c-dev mariadb

# Install the packages into a root derived from the distroless image.
COPY --from=cgr.dev/chainguard/python:latest / /base-chroot
RUN apk add --no-commit-hooks --no-cache --root /base-chroot  mariadb-connector-c-dev mariadb
USER 65532

# Install python packages into /app
WORKDIR /app
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir --target /app -r requirements.txt \
  && rm requirements.txt

FROM cgr.dev/chainguard/python:latest

# Copy the mariadb package from the base-chroot to the runtime stage
COPY --from=dev /base-chroot /

# Copy /app from the 'dev' stage
WORKDIR /app
COPY --from=dev /app /app

COPY run.py run.py

ENTRYPOINT ["python", "run.py"]
