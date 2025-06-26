# DataOps-PFE

Une plateforme end-to-end pour ingérer, valider, transformer et historiser tes données d’inventaire sur GCP, avec orchestration Airflow, TF-infra as code et CI/CD Cloud Build.

---

## 🚀 Caractéristiques

- Ingestion Pub/Sub → Cloud Run (dataloader)
- Validation CSV via Cloud Function + Great Expectations  
- Stockage Raw/TDS/BDS dans BigQuery  
- Orchestration Airflow sur Cloud Composer  
- Transformation en Dataflow (Flex Templates)  
- CI/CD automatique avec Cloud Build trigger GitHub  
- Monitoring & alerting (Cloud Monitoring)  
- Data Catalog pour la traçabilité  
- Logging sink vers BigQuery  

---

## 📁 Structure du repo

