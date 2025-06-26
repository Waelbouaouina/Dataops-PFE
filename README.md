# DataOps-PFE  
Une chaîne DataOps Serverless sur GCP pour ingérer, valider, transformer et historiser vos données d’inventaire, de la simple ingestion CSV à des dashboards Looker Studio.

---

## 1. Vue d’ensemble de l’architecture  
┌─────────────────┐ ┌──────────────┐ ┌─────────────┐ │ Cloud Build │──(1)Infra──▶ GCP Services│ │ GCR/GCS │ │ (Terraform + │ │Terraform & CI/CD │ Buckets │ │ Docker build) │ └──────────────┘ └─────────────┘ └─────────────────┘ │(2–5) │ │ ▼ │ │ ┌────────────────────────┐ │ │ │ Cloud Run Service │ │ │ │ “dataloader” │ │ │ └────────────────────────┘ │ │ ▲ ▲ │ │ (3) Push image → GCR │ │ (6) Pub/Sub HTTP │ │ │ │ message │ ▼ │ │ ▼ ┌─────────────────┐ ┌───────────┐ │ ┌────────────────────┐ │ CSV & DAG → │ │ Cloud │ └───────▶│ Cloud Composer │ │ Storage GCS │ │ Function │ │ (Airflow) │ └─────────────────┘ │ “validator”│ └────────────────────┘ │(4) trigger └───────────┘ │ ▼ │(5) Pub/Sub success/error │ ┌─────────────────────┐ ▼ ▼ │ Google Cloud Logging│ ┌───────────────────┐ ┌────────────────────┐ └─────────────────────┘ │ Pub/Sub │ │ Dataflow Templates │ │ Success / Error │ └────────────────────┘ └───────────────────┘ │ │ │ ┌─────────────────────────┴───────────────┐ ▼ │ Airflow BigQuerySensor → Dataflow │──► TDS Pipeline └──────────────────────────────────────────┘ │ ▼ BDS Pipeline │

---

## 2. Déroulé détaillé  

### Étape 1 – Infra as Code & CI/CD  
1. **Cloud Build** lance Terraform :  
   - Création des buckets, Pub/Sub, IAM, Cloud Run, Cloud Functions, Composer, BigQuery, Data Catalog…  
2. Cloud Build :  
   - Build de l’image Docker `dataloader`,  
   - Push vers **Google Container Registry**.  
3. Cloud Build copie :  
   - Le CSV test → bucket **Storage**,  
   - Les DAGs Airflow → bucket **Cloud Composer**.  

---

### Étape 2 – Validation CSV & Qualité  
1. **Cloud Function** “validator” déclenchée à la création d’un object CSV en Storage.  
2. Exécute des tests **Great Expectations**,  
3. Logge dans **Cloud Logging**,  
4. En cas d’erreur :
   - Publish sur **Pub/Sub** `csv-error-topic` → **Cloud Monitoring** envoie une alerte email.  
5. En cas de succès :
   - Publish sur **Pub/Sub** `csv-success-topic` → abonnement HTTP POST vers **Cloud Run**.  

---

### Étape 3 – Ingestion dans Cloud Run  
- Le service **dataloader** (Cloud Run) reçoit la requête HTTP,  
- Lit le CSV, écrit précisons dans `raw_table` (BigQuery).  

---

### Étape 4 – Orchestration Airflow (Cloud Composer)  
1. Le bucket DAG est automatiquement surveillé par **Composer** – Airflow charge vos DAGs TDS & BDS.  
2. **BigQuerySensor** détecte la création de `raw_table`.  
3. **DataflowTemplatedJobStartOperator** déclenche vos Flex Templates Dataflow.  

---

## 3. Pipelines Dataflow (Apache Beam)  

### 3.1 Pipeline TDS (Transformation, Déduplication, Standardisation)  
1. Extraction :  
   - `BigQueryIO.read(raw_table)` → `PCollection<Record>` (schéma préliminaire1).  
2. Nettoyage & Standardisation :  
   - `ParDo(DoFn)` sur chaque enregistrement → schéma préliminaire2.  
3. Transformation & Enrichissement :  
   - `ParDo(DoFn)` + **sideInput** + `beam.Map` pour dériver de nouvelles colonnes,  
   - `CoGroupByKey` pour joindre données externes (si besoin),  
   - Résultat → schéma aware.  
4. Optimisation analytique :  
   - `beam.Filter`, `beam.Partition`, `Combine.perKey()`,  
   - `BigQueryIO.write()` avec partitionnement & clustering sur `tds_table`.  
5. Qualité & Traçabilité :  
   - Génération de **Data Catalog Tags** pour chaque table et enregistrement.  

### 3.2 Pipeline BDS (KPI & Insights)  
1. Lecture : `BigQueryIO.read(tds_table)` → `PCollection`.  
2. Calcul des KPI & enrichissements métiers (ParDo, CombinePerKey, Map…).  
3. `BigQueryIO.write()` vers `bds_table`.  
4. **Looker Studio** se connecte à `bds_table` pour dashboarding avec LookML.  

---

## 4. Prérequis & Déploiement  

```bash
# 1. Cloner le repo & setup
git clone https://github.com/Waelbouaouina/Dataops-PFE.git
cd Dataops-PFE

# 2. Configurer Terraform
cp Terraform/terraform.tfvars.example Terraform/terraform.tfvars
vim Terraform/terraform.tfvars  # project_id, region, alert_emails…

# 3. Auth GCP (pour Terraform & Cloud Build)
gcloud auth application-default login

# 4. Infra dry-run & apply
cd Terraform
terraform init
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply -auto-approve tfplan
