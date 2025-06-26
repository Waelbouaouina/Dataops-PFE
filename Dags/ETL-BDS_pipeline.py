#!/usr/bin/env python3
import argparse
import json
import logging
import datetime

import apache_beam as beam
from apache_beam.metrics.metric import Metrics
from apache_beam.options.pipeline_options import PipelineOptions, SetupOptions
from google.cloud import datacatalog_v1

# Tag pour side-output DLQ
DLQ_TAG = 'dlq'

# --- STEP 1: Extraction & Validation initiale
class ReadAndValidate(beam.PTransform):
    def __init__(self, table, method):
        super().__init__()
        self.table = table
        self.method = method

    def expand(self, pcol):
        return (
            pcol
            | "1.1 ReadTDS" >> beam.io.ReadFromBigQuery(
                  table=self.table,
                  method=self.method)
            | "1.2 FilterInvalid" >> beam.Filter(
                  lambda r: r.get('resource_group') and r.get('type'))
        )

# --- STEP 2: (Optionnel) DLQ pour lignes sans clé de group/type
class ValidateFn(beam.DoFn):
    def __init__(self):
        self.bad = Metrics.counter(self.__class__, 'bad_rows')

    def process(self, row):
        if not row.get('resource_group') or not row.get('type'):
            self.bad.inc()
            yield beam.pvalue.TaggedOutput(DLQ_TAG, row)
        else:
            yield row

# --- STEP 3: Calcul des KPI (Count Per Key) & enrichissements
def to_kv(row):
    # clé composite (resource_group, type)
    key = (row['resource_group'], row['type'])
    return (key, 1)

def format_for_bds(kv_count):
    (rg, rtype), count = kv_count
    return {
        'resource_group': rg,
        'type':           rtype,
        'resource_count': count,
        'report_date':    datetime.date.today().isoformat()
    }

# --- STEP 5: Data Catalog Tagging (facultatif)
class TagLineageFn(beam.DoFn):
    def __init__(self, project, entry_group, tag_template):
        self.project = project
        self.entry_group = entry_group
        self.tag_template = tag_template

    def setup(self):
        self.client = datacatalog_v1.DataCatalogClient()
        self.parent = self.client.entry_group_path(self.project, self.entry_group)
        self.template = self.client.tag_template_path(
            self.project, self.entry_group, self.tag_template)

    def process(self, row):
        tag = datacatalog_v1.types.Tag()
        tag.template = self.template
        tag.fields['report_date'].timestamp_value.GetCurrentTime()
        self.client.create_tag(parent=self.parent, tag=tag)
        yield row

def run(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--project',         required=True)
    parser.add_argument('--runner',          default='DataflowRunner')
    parser.add_argument('--region',          default='us-central1')
    parser.add_argument('--job_name',        default='bds-pipeline')
    parser.add_argument('--temp_location',   required=True)
    parser.add_argument('--staging_location',required=True)
    parser.add_argument('--use_export',      action='store_true')
    known_args, pipeline_args = parser.parse_known_args(argv)

    # Beam / Dataflow options
    opts = PipelineOptions(pipeline_args + [
        f'--project={known_args.project}',
        f'--runner={known_args.runner}',
        f'--region={known_args.region}',
        f'--job_name={known_args.job_name}',
        f'--temp_location={known_args.temp_location}',
        f'--staging_location={known_args.staging_location}',
    ])
    opts.view_as(SetupOptions).save_main_session = True

    # Tables & schéma
    tds_table = f"{known_args.project}:inventory_dataset.tds_table"
    bds_table = f"{known_args.project}:inventory_dataset.bds_table"
    bds_schema = {'fields': json.load(open("Terraform/schemas/bds_table.json"))}
    read_method = 'EXPORT' if known_args.use_export else 'DIRECT_READ'

    with beam.Pipeline(options=opts) as p:
        # 1) Extraction & validation
        raw = p | ReadAndValidate(tds_table, read_method)

        # 2) (Optionnel) Side-output pour invalid rows
        validated = (
            raw
            | "2. Validate" >> beam.ParDo(ValidateFn()).with_outputs(DLQ_TAG, main='good')
        )
        good = validated.good
        dlq  = validated.dlq

        # 3) Calcul KPI + Report Date
        kpis = (
            good
            | "3.1 ToKV"        >> beam.Map(to_kv)
            | "3.2 CountPerKey" >> beam.combiners.Count.PerKey()
            | "3.3 FormatBDS"   >> beam.Map(format_for_bds)
        )

        # 4) Écriture en BDS (partition & clustering si besoin)
        kpis | "4. WriteBDS" >> beam.io.WriteToBigQuery(
            table=bds_table,
            schema=bds_schema,
            create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
            write_disposition=beam.io.BigQueryDisposition.WRITE_TRUNCATE,
            time_partitioning=beam.io.gcp.bigquery.TimePartitioning(
                type='DAY', field='report_date'
            ),
            clustering_fields=['resource_group','type']
        )

        # 5) Data Catalog tagging (facultatif)
        _ = (
            kpis
            | "5. TagLineage" >> beam.ParDo(
                  TagLineageFn(
                      project=known_args.project,
                      entry_group='inventory_entry_group',
                      tag_template='inventory_tag_template'
                  )
              )
        )

        # Stocker le DLQ pour debug
        _ = (
            dlq
            | "FormatDLQ" >> beam.Map(json.dumps)
            | "WriteDLQ"  >> beam.io.WriteToText(
                  file_path_prefix=f"{known_args.temp_location}/dlq/bds_",
                  file_name_suffix='.json'
              )
        )

if __name__ == '__main__':
    logging.getLogger().setLevel(logging.INFO)
    run()
