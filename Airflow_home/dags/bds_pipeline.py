# Dags/bds_pipeline.py
from airflow import DAG
from airflow.operators.dummy import DummyOperator
from datetime import datetime

with DAG(
    dag_id="bds_pipeline",
    start_date=datetime(2025, 6, 1),
    schedule_interval=None,
    catchup=False
) as dag:
    start        = DummyOperator(task_id="start")
    read_tds     = DummyOperator(task_id="read_tds")
    transform_kpi= DummyOperator(task_id="transform_kpi")
    load_bds     = DummyOperator(task_id="load_bds")

    start >> read_tds >> transform_kpi >> load_bds
