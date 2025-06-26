#!/usr/bin/env python3
import os
import re
import json
import base64
import tempfile
import logging

from flask import Flask, request
from google.cloud import storage, bigquery, pubsub_v1

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger("dataloader")

# ── CONFIGURATION ───────────────────────────────────────────────────────────────
PROJECT_ID    = os.getenv("GCP_PROJECT", "tmtrackdev01")
PUBSUB_SUCCESS= os.getenv("PUBSUB_SUCCESS_TOPIC", "inventory-success-topic")
PUBSUB_ERROR  = os.getenv("PUBSUB_ERROR_TOPIC",   "inventory-error-topic")
DATA_BUCKET   = os.getenv("DATA_BUCKET",          "tmt-storage-01")
BQ_DATASET    = os.getenv("BQ_DATASET",           "inventory_dataset")
BQ_TABLE      = os.getenv("BQ_TABLE",             "raw_table")
RAW_SCHEMA    = os.getenv("RAW_SCHEMA_FILE",      "Terraform/schemas/raw_table.json")

storage_client  = storage.Client()
bq_client       = bigquery.Client()
publisher       = pubsub_v1.PublisherClient()

# ── UTILS ───────────────────────────────────────────────────────────────────────
def pascal_to_snake(name):
    """Convertit ResourceID → resource_id"""
    s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
    return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()

def load_schema():
    with open(RAW_SCHEMA, 'r') as f:
        spec = json.load(f)
    return [bigquery.SchemaField(**fld) for fld in spec['fields']]

def publish(topic, msg_dict):
    topic_path = publisher.topic_path(PROJECT_ID, topic)
    data = json.dumps(msg_dict).encode("utf-8")
    publisher.publish(topic_path, data).result()
    LOG.info(f"Pub/Sub ▶ {topic}: {msg_dict}")

# ── ENDPOINT ───────────────────────────────────────────────────────────────────
@app.route("/", methods=["POST"])
def ingest():
    envelope = request.get_json(force=True)
    if 'message' not in envelope:
        return ("Bad Request: no message", 400)

    # 1) Décodage Pub/Sub
    raw = envelope['message'].get('data', '')
    try:
        payload = json.loads(base64.b64decode(raw).decode('utf-8'))
        blob_name = payload['name']
        bucket_name = payload.get('bucket', DATA_BUCKET)
    except Exception as e:
        LOG.exception("Invalid Pub/Sub payload")
        publish(PUBSUB_ERROR, {"error": "invalid_payload", "details": str(e)})
        return ("Bad Request", 400)

    LOG.info(f"Trigger ▷ bucket={bucket_name} file={blob_name}")

    # 2) Download CSV
    try:
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".csv")
        bucket = storage_client.bucket(bucket_name)
        bucket.blob(blob_name).download_to_filename(tmp.name)
        LOG.info(f"Downloaded to {tmp.name}")
    except Exception as e:
        LOG.exception("Download failed")
        publish(PUBSUB_ERROR, {"error": "download_failed", "details": str(e)})
        return ("Download error", 500)

    # 3) Rewrite header PascalCase → snake_case
    snake_tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".csv")
    with open(tmp.name, newline='', encoding='utf-8') as src, \
         open(snake_tmp.name, 'w', newline='', encoding='utf-8') as dst:
        reader = csv.reader(src)
        writer = csv.writer(dst)
        header = next(reader)
        mapping = [pascal_to_snake(col) for col in header]
        writer.writerow(mapping)
        for row in reader:
            writer.writerow(row)
    LOG.info(f"Rewritten header: {mapping}")

    # 4) Load into BigQuery
    table_ref = bq_client.dataset(BQ_DATASET).table(BQ_TABLE)
    job_config = bigquery.LoadJobConfig(
        schema=load_schema(),
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
    )
    try:
        with open(snake_tmp.name, "rb") as data_file:
            job = bq_client.load_table_from_file(data_file, table_ref, job_config=job_config)
            job.result()
        LOG.info(f"Loaded {job.output_rows} rows into {BQ_DATASET}.{BQ_TABLE}")
        publish(PUBSUB_SUCCESS, {"file": blob_name, "rows": job.output_rows})
        return ("OK", 200)
    except Exception as e:
        LOG.exception("BigQuery load failed")
        publish(PUBSUB_ERROR, {"error": "bq_load_failed", "details": str(e)})
        return ("Load error", 500)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 8080)))
