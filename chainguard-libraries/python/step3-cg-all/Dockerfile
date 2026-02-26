FROM cgr.dev/chainguard-private/python:latest-dev

WORKDIR /app

USER 0
# Copy dependency manifest
COPY requirements.txt .

# Create virtual environment
RUN uv venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

ENV UV_INDEX_URL="https://libraries.cgr.dev/python-remediated/simple"
ENV UV_EXTRA_INDEX_URL="https://libraries.cgr.dev/python/simple https://pypi.org/simple"

RUN --mount=type=secret,id=netrc,target=/root/.netrc \
    uv pip install --no-cache -r requirements.txt

# Copy application code
COPY app.py worker_process.py ./

USER 65532

EXPOSE 5055
ENTRYPOINT ["/app/venv/bin/python", "app.py"]
