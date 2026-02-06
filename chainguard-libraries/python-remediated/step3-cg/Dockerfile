FROM cgr.dev/chainguard-private/python:3.13-dev

WORKDIR /app

COPY pyproject.toml requirements.txt app.py ./

RUN --mount=type=secret,id=netrc,target=/home/nonroot/.netrc,uid=65532 \
	uv venv /app/venv && \
	export PATH="/app/venv/bin:$PATH" && \
	uv pip install --no-cache -r requirements.txt

ENTRYPOINT ["/app/venv/bin/python", "app.py"]
