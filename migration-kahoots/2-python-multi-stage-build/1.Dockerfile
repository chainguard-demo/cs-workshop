FROM cgr.dev/chainguard/python:latest-dev AS dev

# Install python packages into /app
WORKDIR /app
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir --target /app -r requirements.txt \
  && rm requirements.txt

FROM cgr.dev/chainguard/python:latest

# Copy /app from the 'dev' stage
WORKDIR /app
COPY --from=dev /app /app

COPY run.py run.py

ENTRYPOINT ["python", "run.py"]
