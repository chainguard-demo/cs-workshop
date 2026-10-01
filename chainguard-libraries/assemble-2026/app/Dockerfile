FROM cgr.dev/chainguard-private/python:3.13-dev

WORKDIR /app

COPY pyproject.toml uv.lock ./

RUN uv sync --frozen --no-install-project --no-cache

COPY src ./src
ENV PYTHONPATH=/app/src

ENTRYPOINT ["/app/.venv/bin/python", "-m", "reportbot"]
