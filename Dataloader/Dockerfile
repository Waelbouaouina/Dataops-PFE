FROM python:3.9-slim

ENV PYTHONUNBUFFERED=1
ENV PORT=8080

WORKDIR /app

# Copier et installer les dépendances
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt


# Copier le code de l’application
COPY dataloader.py .

EXPOSE 8080

# Commande de démarrage
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "dataloader:app"]
