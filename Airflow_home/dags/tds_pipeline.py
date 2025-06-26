# Dags/tds_pipeline.py
from airflow import DAG
from airflow.operators.dummy import DummyOperator
from datetime import datetime

with DAG(
    dag_id="tds_pipeline",
    start_date=datetime(2025, 6, 1),
    schedule_interval=None,
    catchup=False
) as dag:
    extract = DummyOperator(task_id="extract")
    clean   = DummyOperator(task_id="clean")
    enrich  = DummyOperator(task_id="enrich")
    optimize= DummyOperator(task_id="optimize")
    lineage = DummyOperator(task_id="lineage")

    extract >> clean >> enrich >> optimize >> lineage
