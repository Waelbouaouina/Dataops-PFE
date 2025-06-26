import os
import json
import base64
import requests

# URL de ton service Cloud Run (à surcharger via variable d’environnement)
CLOUD_RUN_URL = os.environ.get(
    "CLOUD_RUN_URL",
    "https://inventory-dataloader-<hash>.a.run.app"
)

def make_pubsub_payload(bucket: str, name: str) -> dict:
    """Construit le JSON tel que Pub/Sub le push vers Cloud Run."""
    msg = {"bucket": bucket, "name": name}
    data_b64 = base64.b64encode(json.dumps(msg).encode("utf-8")).decode("utf-8")
    return {"message": {"data": data_b64}}

def test_successful_ingest():
    """Quand le CSV existe, on doit obtenir un 200 OK."""
    url     = f"{CLOUD_RUN_URL}/"
    payload = make_pubsub_payload("tmt-storage-01", "RAPToR_Azure_Resources_Inventory_02-03-2024.csv")
    resp    = requests.post(url, json=payload, timeout=30)
    assert resp.status_code == 200

def test_invalid_payload():
    """Sans 'message.data', la fonction renvoie 400 Bad Request."""
    url  = f"{CLOUD_RUN_URL}/"
    resp = requests.post(url, json={}, timeout=10)
    assert resp.status_code == 400

def test_download_failure():
    """Si le bucket/fichier n’existe pas, on obtient une erreur 500."""
    url     = f"{CLOUD_RUN_URL}/"
    payload = make_pubsub_payload("nonexistent-bucket", "no-file.csv")
    resp    = requests.post(url, json=payload, timeout=30)
    assert resp.status_code == 500
