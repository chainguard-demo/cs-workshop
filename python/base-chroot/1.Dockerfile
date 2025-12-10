ARG CHAINGUARD_ORG="cs-ttt-demo.dev"
FROM cgr.dev/${CHAINGUARD_ORG}/python:3.13-dev AS dev

# Install python packages into /app
WORKDIR /app
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir --target /app -r requirements.txt \
  && rm requirements.txt

FROM cgr.dev/${CHAINGUARD_ORG}/python:3.13

# Copy /app from the 'dev' stage
WORKDIR /app
COPY --from=dev /app /app

COPY run.py run.py

ENTRYPOINT ["python", "run.py"]
