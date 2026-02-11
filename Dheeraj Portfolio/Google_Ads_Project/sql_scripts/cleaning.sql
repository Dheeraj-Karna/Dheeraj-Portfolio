--Created a Table to clean the Messy data 

Create table `sql-dm-project.google_ads_practice.Google_ads_clean` AS
  
SELECT Ad_id,COALESCE(sale_amount,0) AS sale_amount,
COALESCE(clicks,0) AS Clicks,COALESCE(impressions,0) AS Impressions,
COALESCE(cost,0) AS Cost,COALESCE(leads,0) AS Leads,
COALESCE(conversions,0) AS conversions,
  
   FORMAT_DATE('%d-%m-%Y',
     COALESCE (
       safe.parse_date('%d-%m-%Y',Ad_date),
       safe.parse_date('%Y-%m-%d',Ad_date),
       safe.parse_date('%Y/%m/%d',Ad_date),
       safe.parse_date('%Y/%d/%m',Ad_date),
       safe.parse_date('%m/%Y/%d',Ad_date),
       safe.parse_date('%m/%d/%Y',Ad_date)
     )
     ) AS Ad_date_Clean,
  
     CASE
       WHEN LOWER(Campaign_Name) LIKE '%data%' THEN 'Data Analytics Course'
     Else 'Data Analytics Course'
     END AS Campaign_name,
  
     CASE
       WHEN LOWER (Location) IN ('hyderabad','Hyderbed') THEN 'Hyderabad'
       ELSE 'Hyderabad'
     END AS Location,

     CASE
       WHEN LOWER(Device) ='mobile' THEN 'Mobile'
       WHEN LOWER(Device) ='desktop' THEN 'Desktop'
       WHEN LOWER(Device) ='tablet' THEN 'Tablet'
     END AS Device
  
FROM `sql-dm-project.google_ads_practice.ads_data`

--Created a view to store KPI values for further visualisations

CREATE OR REPLACE VIEW `sql-dm-project.google_ads_practice.derived_kpi_view` AS
SELECT
    Ad_ID,
    Campaign_Name,
    Keyword,
    SUM(COALESCE(Cost,0)) AS Total_cost,
    SUM(COALESCE(Sale_Amount,0)) AS Total_Revenue,
    ROUND(SUM(Clicks) / NULLIF(SUM(Impressions), 0), 2) AS CTR,
    ROUND(SUM(Conversions) / NULLIF(SUM(Clicks), 0), 2) AS Conv_Rate,
    ROUND(SUM(Cost) / NULLIF(SUM(Conversions), 0), 2) AS Cost_per_Conversion,
    ROUND(SUM(Sale_Amount) / NULLIF(SUM(Cost), 0), 2) AS ROAS
FROM `sql-dm-project.google_ads_practice.ads_data_cleaned`
GROUP BY Ad_ID, Campaign_Name,Keyword;

-- 1) Calculate Cost per Conversion and Return on Ad Spend (ROAS) for each Campaign_Name. Rank campaigns by profitability.
SELECT
  Campaign_Name,
  ROUND(SUM(Cost),2) AS Total_Cost,
  SUM(Conversions) AS Total_Conversions,
  SUM(Sale_Amount) AS Total_Revenue,
  -- Cost per Conversion
  ROUND(SUM(Cost) / NULLIF(SUM(Conversions), 0), 2) AS Cost_per_Conversion,
  -- ROAS = Revenue / Cost
  ROUND(SUM(Sale_Amount) / NULLIF(SUM(Cost), 0), 2) AS ROAS,
  RANK() over(order by ROUND(SUM(Cost) / NULLIF(SUM(Conversions), 0), 2) ASC, ROUND(SUM(Sale_Amount) / NULLIF(SUM(Cost), 0), 2) DESC) AS Rank_camp
FROM `sql-dm-project.google_ads_practice.ads_data_cleaned`
GROUP BY Campaign_Name;

-- In this dataset we have only campaign_name 'Data Analytics course'.

-- 2) For each Keyword,Calculate Click‑Through Rate (CTR = Clicks/Impressions) and Conversion Rate (Conversions/Clicks). Identify top 5 performing keywords.

SELECT
    Keyword,
    ROUND(SUM(Clicks) / NULLIF(SUM(Impressions), 0), 2) AS CTR,
    ROUND(SUM(Conversions) / NULLIF(SUM(Clicks), 0), 2) AS Conv_Rate
FROM `sql-dm-project.google_ads_practice.ads_data_cleaned`
GROUP BY Keyword
ORDER BY Conv_Rate DESC
LIMIT 5;

--3) Compare Conversion Rate and Cost per Conversion across Device and Location. Identify the most efficient device‑location combinations.

SELECT
   Device,
   Location,
   ROUND(SUM(Conversions) / NULLIF(SUM(Clicks), 0), 2) AS Conv_Rate,
   ROUND(SUM(Cost) / NULLIF(SUM(Conversions), 0), 2) AS Cost_per_Conversion,
   RANK() OVER (PARTITION BY Location ORDER BY SUM(Cost)/NULLIF(SUM(Conversions),0) ASC, SUM(Conversions)/NULLIF(SUM(Clicks),0) DESC) AS efficiency_rank
FROM `sql-dm-project.google_ads_practice.ads_data_cleaned`
GROUP BY Device, Location;

--4) Are campaigns improving or declining over time?
--For each Ad_ID within the campaign, calculate Cost per Conversion and classify ads into performance categories. Flag ads with Cost per Conversion Declining Performance or High Performance
--- due to single campaign, will sort with ad_id and cost_per_conv and flag their declining performance

SELECT ad_id,Ad_Date_Clean,
 ROUND((Cost/Conversions),2) AS Cost_per_conv,
CASE
 WHEN ROUND((Cost/Conversions),2) between 1 AND 40 THEN 'Declining Performance'
 WHEN ROUND((Cost/Conversions),2) is null then 'No Result'
 ELSE 'Good Performance'
END AS Performance_status
FROM `sql-dm-project.google_ads_practice.ads_data_cleaned`
Order By Cost_per_conv DESC;

--5) Replace nulls in Leads and Conversions with 0 using COALESCE. Recalculate KPIs and compare results before and after cleaning

-- Before cleaning (raw data)
WITH before_cleaning AS
(
SELECT
    Campaign_name,Ad_ID,
    ROUND(SUM(Conversions) / SUM(Clicks),2) AS Before_conversion_rate,
    ROUND(SUM(Cost) / SUM(Conversions),2) AS Before_cost_per_conversion,
    ROUND(SUM(Sale_Amount) /SUM(Cost),2) AS Before_roas
FROM `sql-dm-project.google_ads_practice.ads_data_cleaned`
GROUP BY Campaign_name,Ad_ID
)

-- After cleaning (replace nulls with 0)
SELECT
    BC.Campaign_Name,
    BC.Ad_id,
    BC.Before_conversion_rate,
    BC.Before_cost_per_conversion,
    BC.Before_roas,
    ROUND(SUM(COALESCE(Conversions, 0)) / NULLIF(SUM(Clicks), 0),2) AS conversion_rate,
    ROUND(SUM(Cost) / NULLIF(SUM(COALESCE(Conversions, 0)), 0),2) AS cost_per_conversion,
    ROUND(SUM(Sale_Amount) / NULLIF(SUM(COALESCE(Cost,0)), 0),2) AS roas

FROM `sql-dm-project.google_ads_practice.ads_data_cleaned` , before_cleaning  BC
GROUP BY BC.Campaign_Name,BC.Ad_id,BC.Before_conversion_rate,BC.Before_cost_per_conversion,BC.Before_roas;

--6) Create a query that outputs the Top 10 campaigns ranked by Sale_Amount and ROAS, ready for visualization in Looker Studio.
WITH campaign_perf AS (
    SELECT
        Campaign_Name,Ad_ID,
        SUM(Sale_Amount) AS total_sales,
        SUM(Cost) AS total_cost,
        ROUND(SUM(Sale_Amount) / NULLIF(SUM(Cost), 0), 2) AS roas
    FROM `sql-dm-project.google_ads_practice.ads_data_cleaned`
    GROUP BY Campaign_Name,Ad_ID
)
SELECT
    Campaign_Name,
    ad_id,
    total_sales,
    roas,
    RANK() OVER (ORDER BY total_sales DESC, roas DESC) AS campaign_rank
FROM campaign_perf
ORDER BY campaign_rank
LIMIT 10;













