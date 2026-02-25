FROM python 

WORKDIR /app

# Install uv (fast static installer)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Copy dependency manifest
COPY requirements.txt .

# Create virtual environment
RUN uv venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Install dependencies (defaults to PyPI)
RUN uv pip install --no-cache -r requirements.txt

# Copy application code
COPY app.py worker_process.py ./

EXPOSE 5055
ENTRYPOINT ["/app/venv/bin/python", "app.py"]
