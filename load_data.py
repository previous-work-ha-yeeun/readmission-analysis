import pandas as pd


# ==========================================
# 1. LOAD DATA
# ==========================================
df = pd.read_csv('data/diabetic_data.csv', na_values=['?'])

print('Initial data shape:', df.shape)
# print(df.head())
# print(df.info())


# ==========================================
# 2. DATA CLEANING & PREPROCESSING
# ==========================================
print(df.isna().mean().sort_values(ascending=False).head(8))

# for col in df.select_dtypes(include="str").columns:
#     print(df[col].value_counts(dropna=False).head(5))
#     print(f'Number of distinct values: {df[col].nunique()}')
#     print("---")


# Drop weight: 97% missing 
# Drop payer_code: 40% missing 
# For institutional lack of records, meaningful values can’t be built from them. (paper Section 2.3)
df = df.drop(columns=['weight', 'payer_code'])

# Keep as categories: 
# The paper’s core question is whether HbA1c was measured. - A1C result: blank = test not performed (Table 3) 
df['A1Cresult'] = df['A1Cresult'].fillna('Untested')
# medical_specialty and race were maintained 
for col in ["race", "medical_specialty"]:
    df[col] = df[col].fillna("Unknown")

# Remove rows with meaningless gender
# The paper’s final data has no Unknown gender rows left (Table 3)
df = df[df['gender'] != 'Unknown/Invalid']

print("Cleaned data shape:", df.shape)



