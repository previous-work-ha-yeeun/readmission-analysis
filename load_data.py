import pandas as pd


# ==========================================
# 1. LOAD DATA
# ==========================================
df = pd.read_csv('data/diabetic_data.csv')

print('Initial data shape:', df.shape)
# print(df.head())
# print(df.info())


# ==========================================
# 2. DATA CLEANING & PREPROCESSING
# ==========================================
for col in df.select_dtypes(include="str").columns:
    print(df[col].value_counts(dropna=False).head(5))
    print(f'Number of distinct values: {df[col].nunique()}')
    print("---")

# for col in df.select_dtypes(include="number").columns:
#     print(col, df[col].describe())
#     print("------------------")
