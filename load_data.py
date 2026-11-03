import os
import io
import pandas as pd
from sqlalchemy import create_engine
from dotenv import load_dotenv


# ==========================================
# 1. LOAD MAIN DATA
# ==========================================
df = pd.read_csv('data/diabetic_data.csv', na_values=['?'])

print('Initial data shape:', df.shape)
# print(df.head())
# print(df.info())


# ==========================================
# 2. LOAD ID MAPPING TABLES 
# ==========================================
with open("data/IDs_mapping.csv", encoding="utf-8") as f:
    lines = f.read().splitlines()

blocks, current = [], []
for line in lines:
    if line.strip().strip(",") == "":    # table separator: blank line or only commas
        if current:
            blocks.append(current)
            current = []
    else:
        current.append(line)
if current:
    blocks.append(current)

print("Tables found in mapping file:", len(blocks)) 


# ==========================================
# 3. DATA CLEANING & PREPROCESSING
# ==========================================
print(df.isna().mean().sort_values(ascending=False).head(8))

# Drop weight: 97% missing 
# Drop payer_code: 40% missing 
# For institutional lack of records, meaningful values can’t be built from them. (paper Section 2.3)
df = df.drop(columns=['weight', 'payer_code'])

# Keep as categories (Table 3): 
# The paper’s core question is whether HbA1c was measured. - A1C result: blank = test not performed 
df['A1Cresult'] = df['A1Cresult'].fillna('Untested')
# medical_specialty and race were maintained 
for col in ["race", "medical_specialty"]:
    df[col] = df[col].fillna("Unknown")

# Remove rows with meaningless gender
# The paper’s final data has no Unknown gender rows left (Table 3)
df = df[df['gender'] != 'Unknown/Invalid']

print("Cleaned data shape:", df.shape)


# ==========================================
# 4. Load cleaned data into MySQL 
# ==========================================
load_dotenv()

user = os.getenv("DB_USER")
password = os.getenv("DB_PASSWORD")
host = os.getenv("DB_HOST")
port = os.getenv("DB_PORT")
database = os.getenv("DB_NAME")

db_connection_url = f"mysql+pymysql://{user}:{password}@{host}:{port}/{database}"
engine = create_engine(db_connection_url)

# Main data
df.to_sql('inpatient_encounters', engine, if_exists='replace', index=False, chunksize=5000)
print('Main data loaded to MySQL')

# ID mapping tables
for block in blocks:
    table_name = block[0].split(",")[0].replace("_id", "")   
    m = pd.read_csv(io.StringIO("\n".join(block)), keep_default_na=False)  # keep 'NULL' as literal text
    m["description"] = m["description"].str.strip()                        # remove spaces
    m.to_sql(table_name, engine, if_exists="replace", index=False)
    print("Loaded -", table_name, m.shape)




