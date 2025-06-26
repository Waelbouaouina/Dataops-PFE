# Tests/test_dataloader.py
import io
import csv
import pytest
from Dataloader.dataloader import load_csv_to_bigquery
from google.cloud import bigquery

def test_csv_columns_validation():
    """Le header CSV doit contenir toutes les colonnes requises."""
    csv_content = (
        "ResourceID,ResourceName,ResourceType,ResourceGroup,"
        "SubscriptionID,Location,Tags,CreatedDate\n"
        "1,TestResource,TypeA,GroupA,Sub123,us-west1,\"tag1,tag2\",2023-01-01T00:00:00Z\n"
    )
    csv_file = io.StringIO(csv_content)
    reader = csv.reader(csv_file)
    header = next(reader)
    required = {
        "ResourceID","ResourceName","ResourceType","ResourceGroup",
        "SubscriptionID","Location","Tags","CreatedDate"
    }
    assert required.issubset(set(header))

class DummyLoadJob:
    """Charge-job simulé avec un output_rows fixé."""
    def __init__(self, rows):
        self.output_rows = rows
    def result(self):
        return None

class DummyBQClient:
    """Client BigQuery factice pour capturer l’appel de load_table_from_file."""
    def __init__(self):
        self.called = False

    def load_table_from_file(self, file_obj, table_ref, job_config):
        # On s’assure qu’on passe bien le même fichier et un job_config valide
        assert hasattr(job_config, "source_format")
        assert file_obj.getvalue().startswith("ResourceID,")
        self.called = True
        return DummyLoadJob(rows=1)

def test_load_csv_to_bigquery(monkeypatch):
    """load_csv_to_bigquery() retourne le nombre de lignes chargées."""
    # 1) Prépare un CSV minimal
    csv_content = (
        "ResourceID,ResourceName,ResourceType,ResourceGroup,"
        "SubscriptionID,Location,Tags,CreatedDate\n"
        "1,TestResource,TypeA,GroupA,Sub123,us-west1,\"tag1,tag2\",2023-01-01T00:00:00Z\n"
    )
    csv_file = io.StringIO(csv_content)

    # 2) Remplace bigquery.Client par notre DummyBQClient
    monkeypatch.setattr(bigquery, "Client", lambda: DummyBQClient())

    # 3) Appel de la fonction
    rows_loaded = load_csv_to_bigquery(csv_file)

    # 4) Assertions
    assert rows_loaded == 1
