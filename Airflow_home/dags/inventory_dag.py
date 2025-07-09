# Dags/inventory_dag.py

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.google.cloud.sensors.bigquery import BigQueryTableExistenceSensor
from airflow.providers.google.cloud.operators.dataflow import DataflowTemplatedJobStartOperator

# === Config DAG ===
PROJECT_ID   = "tmtrackdev01"
REGION       = "us-central1"
BUCKET       = "inventory-bucket-tmtrackdev01"
DATASET      = "inventory_dataset"
TDSTEMPLATE  = f"gs://{BUCKET}/templates/tds_template"
BDSTEMPLATE  = f"gs://{BUCKET}/templates/bds_template"

default_args = {
    "start_date": datetime(2025, 1, 1),
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
    "project_id": PROJECT_ID,
}

with DAG(
    dag_id="inventory_dataops",
    default_args=default_args,
    description="Orchestre TDS puis BDS sur l’inventaire Azure",
    schedule_interval="@daily",
    catchup=False,
) as dag:

    # STEP 0 – On attend que raw_table existe / soit peuplée
    wait_raw = BigQueryTableExistenceSensor(
        task_id="wait_for_raw_table",
        project_id=PROJECT_ID,
        dataset_id=DATASET,
        table_id="raw_table",
        poke_interval=60,
        timeout=3600,
        mode="reschedule",
    )

    # STEP 1 – Lancer le pipeline TDS via template Dataflow
    run_tds = DataflowTemplatedJobStartOperator(
        task_id="run_tds_pipeline",
        template=TDSTEMPLATE,
        parameters={
            "project": PROJECT_ID,
            "region": REGION,
            "temp_location": f"gs://{BUCKET}/tmp",
            "staging_location": f"gs://{BUCKET}/staging",
            # "use_export": "true"  # si besoin
        },
        location=REGION,
        wait_until_finished=True,
    )

    # STEP 2 – Lancer le pipeline BDS via template Dataflow
    run_bds = DataflowTemplatedJobStartOperator(
        task_id="run_bds_pipeline",
        template=BDSTEMPLATE,
        parameters={
            "project": PROJECT_ID,
            "region": REGION,
            "temp_location": f"gs://{BUCKET}/tmp",
            "staging_location": f"gs://{BUCKET}/staging",
        },
        location=REGION,
        wait_until_finished=True,
    )

    # Orchestration
    wait_raw >> run_tds >> run_bds
