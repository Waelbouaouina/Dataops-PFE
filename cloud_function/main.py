import os
import csv
import logging
import pandas as pd
from google.cloud import storage, pubsub_v1
import great_expectations as ge

def validate_csv(event, context):
    """
    Fonction Cloud Function déclenchée sur l'arrivée d'un objet dans le bucket.
    Elle télécharge le fichier CSV, le valide via Great Expectations et publie un message sur Pub/Sub.
    """
    file_name = event.get("name")
    bucket_name = event.get("bucket")
    logging.info(f"Traitement du fichier : {file_name} depuis le bucket : {bucket_name}")

    # Initialise le client Cloud Storage et récupère le contenu du fichier.
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_name)

    try:
        content = blob.download_as_text()
    except Exception as e:
        logging.error(f"Erreur lors du téléchargement du fichier {file_name} : {e}")
        publish_message("error", f"Erreur téléchargement {file_name}: {e}")
        return

    # Lecture du CSV et validation
    try:
        # Conversion du contenu CSV en DataFrame
        reader = csv.DictReader(content.splitlines())
        data = list(reader)
        if not data:
            raise ValueError("Le fichier CSV est vide ou le format est invalide.")

        df = pd.DataFrame(data)

        # Création d'un DataFrame Great Expectations
        df_ge = ge.from_pandas(df)

        # Exemple d'attente : aucun ResourceID ne doit être nul
        result = df_ge.expect_column_values_to_not_be_null("ResourceID")
        if not result.get("success"):
            raise ValueError("Validation échouée : des valeurs NULL détectées dans 'ResourceID'.")
        
        logging.info("Validation du CSV réussie.")
        publish_message("success", f"Validation réussie pour le fichier : {file_name}")
    except Exception as ve:
        logging.error(f"Erreur de validation pour le fichier {file_name} : {ve}")
        publish_message("error", f"Erreur de validation pour {file_name} : {ve}")

def publish_message(status, message):
    """
    Publie le message sur le topic Pub/Sub correspondant.
    Les variables d'environnement SUCCESS_TOPIC et ERROR_TOPIC doivent contenir
    le chemin complet du topic (ex: projects/<project_id>/topics/<topic_name>).
    """
    publisher = pubsub_v1.PublisherClient()
    
    if status == "success":
        topic_name = os.environ.get("SUCCESS_TOPIC")
    else:
        topic_name = os.environ.get("ERROR_TOPIC")
    
    if not topic_name:
        logging.error("Le topic Pub/Sub n'est pas défini dans les variables d'environnement.")
        return
    
    try:
        future = publisher.publish(topic_name, message.encode("utf-8"))
        logging.info(f"Message publié sur {topic_name} : {message}")
        future.result()  # Optionnel : attendre la confirmation de publication
    except Exception as e:
        logging.error(f"Erreur lors de la publication du message : {e}")
