FROM python:3.13

WORKDIR /app

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

COPY requirements.txt app.py ./

# Create virtual environment
RUN uv venv /app/venv
ENV PATH="/app/venv/bin:$PATH"
RUN uv pip install --no-cache -r requirements.txt

ENTRYPOINT ["/app/venv/bin/python", "app.py"]
