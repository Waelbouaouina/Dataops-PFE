import pandas as pd

# Remplace le nom par le chemin exact vers ton fichier CSV
file_path = "RAPToR_Azure_Resources_Inventory_02-03-2024.csv"

# Charger le fichier CSV
df = pd.read_csv(file_path)

# Analyse
print(" Nombre total de lignes :", len(df))
print(" Doublons exacts :", df.duplicated().sum())
print(" Lignes entièrement vides :", df.isnull().all(axis=1).sum())
print(" Valeurs nulles totales :", df.isnull().sum().sum())
