import pandas as pd
from sqlalchemy import create_engine

# Step 1: Connect to SQL database
engine = create_engine('postgresql+psycopg2://username:password@host:5432/dbname')

# Step 2: Define SQL queries
query_ads = """
SELECT campaign_name, impressions, clicks, cost, conversions, date
FROM ad_platform.campaign_performance
WHERE date BETWEEN '2025-08-01' AND '2025-08-31'
"""

query_crm = """
SELECT customer_id, lead_source, created_date, status, region
FROM crm.leads
WHERE status IN ('Converted', 'Qualified')
"""

# Step 3: Load data into Pandas
ads_df = pd.read_sql(query_ads, engine)
crm_df = pd.read_sql(query_crm, engine)

# Step 4: Clean and transform
ads_df.dropna(subset=['campaign_name', 'clicks', 'impressions'], inplace=True)
ads_df['CTR'] = ads_df['clicks'] / ads_df['impressions']
ads_df['ROI'] = (ads_df['conversions'] * 100) / ads_df['cost']  # Assuming avg order value = 100

# Step 5: Join with CRM data
merged_df = pd.merge(ads_df, crm_df, left_on='campaign_name', right_on='lead_source', how='inner')

# Step 6: Export cleaned dataset
merged_df.to_csv('final_campaign_analysis.csv', index=False)

print("Campaign analysis completed. Output saved to final_campaign_analysis.csv")
