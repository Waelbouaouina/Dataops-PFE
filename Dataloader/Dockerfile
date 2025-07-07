FROM python:3.10-slim

ENV PYTHONUNBUFFERED=1
ENV PORT=8080

WORKDIR /app

COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

COPY dataloader.py .

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "dataloader:app"]
