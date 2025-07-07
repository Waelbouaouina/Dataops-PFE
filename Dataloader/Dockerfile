FROM python:3.9-slim

# Empêche le buffering pour voir les logs directement
ENV PYTHONUNBUFFERED=1
ENV PORT=8080

# Dossier de travail
WORKDIR /app

# Installer les dépendances
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copier les fichiers nécessaires
COPY dataloader.py .

# Ne copie le dossier que s'il existe
COPY great_expectations/ ./great_expectations/

# Exposer le port utilisé par Flask/Gunicorn
EXPOSE 8080

# Commande de démarrage
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "dataloader:app"]
