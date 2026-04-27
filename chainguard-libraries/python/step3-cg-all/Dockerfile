FROM cgr.dev/chainguard-private/python:latest-dev

WORKDIR /app

USER 0
RUN apk add --no-cache zlib-dev libjpeg-dev
# Copy dependency manifest
COPY requirements.txt .

# Create virtual environment
RUN uv venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

ENV UV_INDEX="https://libraries.cgr.dev/python/simple https://pypi.org/simple"

RUN --mount=type=secret,id=netrc,target=/root/.netrc \
    uv pip install --no-cache -r requirements.txt

# Copy application code
COPY app.py worker_process.py ./

USER 65532

EXPOSE 5055
ENTRYPOINT ["/app/venv/bin/python", "app.py"]
