FROM python:latest

COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY run.py run.py

CMD ["python", "run.py"]
