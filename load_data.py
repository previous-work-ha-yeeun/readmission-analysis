import pandas as pd


# ==========================================
# 1. LOAD DATA
# ==========================================
df = pd.read_csv('data/diabetic_data.csv')

print('Initial data shape:', df.shape)
print(df.head())
print(df.info())

