#!/usr/bin/env python3
import argparse
import json
import logging
import datetime

import apache_beam as beam
from apache_beam.metrics.metric import Metrics
from apache_beam.options.pipeline_options import PipelineOptions, SetupOptions
from google.cloud import datacatalog_v1

# Tags pour side-outputs
DLQ_TAG = 'dlq'

class ExtractAndValidate(beam.PTransform):
    """Étape 1: lecture + verif initiale de raw_table."""
    def __init__(self, table, method):
        super().__init__()
        self.table = table
        self.method = method

    def expand(self, pcoll):
        return (
            pcoll
            | 'ReadRaw' >> beam.io.ReadFromBigQuery(
                  table=self.table,
                  method=self.method
              )
            | 'FilterMissingID' >> beam.Filter(
                  lambda r: r.get('id') 
                            and r.get('subscription_id')
                            and r.get('resource_group')
             )
        )

class CleanAndStandardizeDoFn(beam.DoFn):
    """Étape 2: nettoyage & standardisation, side-output DLQ."""
    def __init__(self):
        self.err_counter = Metrics.counter(self.__class__, 'bad_rows')

    def process(self, row):
        try:
            out = {
                'subscription_id': row['subscription_id'],
                'resource_group':  row['resource_group'].strip().upper(),
                'resource_name':   row['resource_name'].strip(),
                'location':        row['location'].strip().lower(),
                'type':            row['type'].strip().lower(),
                'kind':            (row.get('kind') or '').strip(),
                'sku':             (row.get('sku') or '').strip(),
                'id':              row['id'],
                'environment':     (row.get('environment') or '').strip(),
                'deployment_id':   (row.get('deployment_id') or '').strip(),
                'owner':           (row.get('owner') or '').strip(),
                'role_purpose':    (row.get('role_purpose') or '').strip(),
                'raptor_module':   (row.get('raptor_module') or '').strip(),
                'raptor_team':     (row.get('raptor_team') or '').strip(),
                'raptor_train':    (row.get('raptor_train') or '').strip(),
                'raptor_domain':   (row.get('raptor_domain') or '').strip(),
                'client_id':       (row.get('client_id') or '').strip(),
                'client_name':     (row.get('client_name') or '').strip(),
                'tags':            (row.get('tags') or '').strip(),
            }
            yield out
        except Exception as e:
            self.err_counter.inc()
            logging.error(f"Clean error on {row}: {e}")
            yield beam.pvalue.TaggedOutput(DLQ_TAG, row)

class SchemaEnrichment(beam.DoFn):
    """Étape 3: parsing JSON Tags & dérivés métiers."""
    def process(self, row):
        # extraction d'un flag depuis le JSON contenu dans tags
        try:
            tag_obj = json.loads(row['tags']) if row['tags'] else {}
        except json.JSONDecodeError:
            tag_obj = {}
        # par exemple, on crée un flag WebAppLinked
        row['webapp_linked'] = tag_obj.get('WebAppLinked', '').lower() == 'true'
        # on peut aussi dériver la subscription_short (les 8 premiers chars)
        row['subscription_short'] = row['subscription_id'][:8]
        yield row

class AddIngestionTimestamp(beam.DoFn):
    """Étape 3 bis: ajoute ingestion_timestamp."""
    def process(self, row):
        row['ingestion_timestamp'] = datetime.datetime.utcnow().isoformat()
        yield row

class DataCatalogTagging(beam.DoFn):
    """Étape 5: pose des tags Data Catalog pour le lineage."""
    def __init__(self, project, entry_group_id, tag_template_id):
        self.project = project
        self.entry_group = entry_group_id
        self.tag_template = tag_template_id

    def setup(self):
        self.client = datacatalog_v1.DataCatalogClient()

    def process(self, row):
        # parent = full resource path de l'entrée Data Catalog
        parent = self.client.entry_group_path(self.project, self.entry_group)
        tag = datacatalog_v1.types.Tag()
        tag.template = self.client.tag_template_path(
            self.project, self.entry_group, self.tag_template)
        # on ajoute un champ tag "processed_date"
        tag.fields['processed_date'].timestamp_value.GetCurrentTime()
        yield row  # on n'altère pas la row

def run(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--project',         required=True)
    parser.add_argument('--runner',          default='DataflowRunner')
    parser.add_argument('--region',          default='us-central1')
    parser.add_argument('--job_name',        default='tds-pipeline')
    parser.add_argument('--temp_location',   required=True)
    parser.add_argument('--staging_location',required=True)
    parser.add_argument('--num_workers',     type=int, default=3)
    parser.add_argument('--max_num_workers', type=int, default=10)
    parser.add_argument('--use_export',      action='store_true')
    known_args, pipeline_args = parser.parse_known_args(argv)

    opts = PipelineOptions(pipeline_args + [
        f'--project={known_args.project}',
        f'--runner={known_args.runner}',
        f'--job_name={known_args.job_name}',
        f'--region={known_args.region}',
        f'--temp_location={known_args.temp_location}',
        f'--staging_location={known_args.staging_location}',
        f'--num_workers={known_args.num_workers}',
        f'--max_num_workers={known_args.max_num_workers}',
    ])
    opts.view_as(SetupOptions).save_main_session = True

    raw_table = f"{known_args.project}:inventory_dataset.raw_table"
    tds_table = f"{known_args.project}:inventory_dataset.tds_table"
    schema    = {'fields': json.load(open("infra/terraform/schemas/tds_table.json"))}

    method = 'EXPORT' if known_args.use_export else 'DIRECT_READ'

    with beam.Pipeline(options=opts) as p:
        # 1) Extraction & validation
        validated = p | ExtractAndValidate(raw_table, method)

        # 2) Nettoyage & standardisation + DLQ
        cleaned_and_dlq = validated | 'CleanStd' >> beam.ParDo(
            CleanAndStandardizeDoFn()).with_outputs(DLQ_TAG, main='cleaned')
        cleaned = cleaned_and_dlq.cleaned
        dlq     = cleaned_and_dlq.dlq

        # 3) Enrichissements métiers & timestamp
        enriched = (
            cleaned
            | 'ParseTags' >> beam.ParDo(SchemaEnrichment())
            | 'AddTS'     >> beam.ParDo(AddIngestionTimestamp())
        )

        # 4) Write to staging (TDS) avec partition & clustering
        enriched | 'WriteTDS' >> beam.io.WriteToBigQuery(
            table=tds_table,
            schema=schema,
            create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
            write_disposition=beam.io.BigQueryDisposition.WRITE_TRUNCATE,
            time_partitioning=beam.io.gcp.bigquery.TimePartitioning(
                type='DAY', field='ingestion_timestamp'
            ),
            clustering_fields=['resource_group', 'type']
        )

        # 5) DataLineage via Data Catalog tags
        _ = (
            enriched
            | 'TagDataLineage' >> beam.ParDo(
                  DataCatalogTagging(
                      project=known_args.project,
                      entry_group_id='inventory_entry_group',
                      tag_template_id='inventory_tag_template'
                  )
              )
        )

        # Écriture du DLQ pour analyse
        _ = (
            dlq
            | 'FormatDLQ' >> beam.Map(json.dumps)
            | 'WriteDLQ'  >> beam.io.WriteToText(
                  file_path_prefix=f"{known_args.temp_location}/dlq/tds_",
                  file_name_suffix='.json'
              )
        )

if __name__ == '__main__':
    logging.getLogger().setLevel(logging.INFO)
    run()
