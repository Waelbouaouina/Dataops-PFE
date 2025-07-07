# Utilisation d'une image Python 3.9 légère
FROM python:3.9-slim

# Ne pas bufferiser les logs Python
ENV PYTHONUNBUFFERED=1
# Port sur lequel Cloud Run attend le service
ENV PORT=8080

WORKDIR /app

# 1) Copier et installer les dépendances
COPY requirements.txt .
RUN pip install --no-cache-dir -requirements.txt

# 2) Copier la suite Great Expectations (si tu as un dossier great_expectations/)
COPY great_expectations/ ./great_expectations/

# 3) Copier le code de l'application
COPY dataloader.py .

# 4) Exposer le port
EXPOSE 8080

# 5) Lancer avec Gunicorn pour la prod Cloud Run
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "dataloader:app"]
