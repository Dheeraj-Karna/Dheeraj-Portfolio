-- Joining all the tables to make easy analysis further, Joiner through View
CREATE VIEW `sql-dm-project.Ecommerce_data.Ecommerce_table` AS
SELECT
   orders.order_id AS order_id,
   orders.status AS order_status,
   orders.gender,
   orders.created_at,
   orders.returned_at,
   orders.shipped_at,
   orders.delivered_at,
   orders.num_of_item,
   order_items.id AS order_item_id,
   order_items.status AS order_item_status,
   order_items.created_at AS order_items_created,
   order_items.shipped_at AS order_items_shipped,
   order_items.delivered_at AS order_items_delivered,
   order_items.returned_at AS order_items_returned,
   order_items.sale_price,
   users.id AS user_id,
   users.first_name,
   users.last_name,
   users.email,
   users.age,
   users.state,
   users.street_address,
   users.city,
   users.country,
   users.postal_code,
   users.latitude,
   users.longitude,
   users.traffic_source,
   users.created_at AS user_created_at,
   users.user_geom,
   events.id AS event_id,
   events.sequence_number,
   events.session_id,
   events.created_at AS events_created,
   events.ip_address,
   events.city AS events_city,
   events.state AS events_state,
   events.postal_code AS events_postal_code,
   events.browser,
   events.traffic_source AS event_traffic_source,
   events.uri,
   events.event_type,
   products.id AS product_id,
   products.cost,
   products.category,
   products.name,
   products.brand,
   products.retail_price,
   products.department,
   products.sku,
   inv_items.id AS inventory_item_id,
   inv_items.created_at AS inv_items_created,
   inv_items.sold_at,
   inv_items.cost AS inv_items_cost,
   inv_items.product_category AS inv_prod_cat,
   dc.id AS distribution_center_id,
   dc.name AS distribution_center_name,
   dc.latitude AS distribution_center_lat,
   dc.longitude AS distribution_center_long,
   dc.distribution_center_geom
FROM `bigquery-public-data.thelook_ecommerce.orders` orders
JOIN `bigquery-public-data.thelook_ecommerce.order_items` order_items
   ON orders.order_id = order_items.order_id
JOIN `bigquery-public-data.thelook_ecommerce.users` users
   ON order_items.user_id = users.id
JOIN `bigquery-public-data.thelook_ecommerce.events` events
   ON users.id = events.user_id
JOIN `bigquery-public-data.thelook_ecommerce.products` products
   ON order_items.product_id = products.id
JOIN `bigquery-public-data.thelook_ecommerce.inventory_items` inv_items
   ON products.id = inv_items.product_id
JOIN `bigquery-public-data.thelook_ecommerce.distribution_centers` dc
   ON inv_items.product_distribution_center_id = dc.id;

--Which age group generates the highest revenue?
select age,
FORMAT('%.2f ₹',SUM(ec.sale_price)) AS Total_sales_in_INR,
from `sql-dm-project.Ecommerce_data.Ecommerce_table` ec
GROUP BY age
ORDER BY Total_sales_in_INR DESC

--How does gender distribution affect purchase behavior (conversion rate, average order value)?
Select gender,
Count(Distinct order_id) AS Total_uniq_orders,
CONCAT(ROUND(SUM(CASE WHEN order_item_status ='Complete' THEN sale_price END) / 1000000,0),'M') AS Total_purchased_orders,
Concat(ROUND(SUM(CASE WHEN order_item_status ='Complete' THEN sale_price END) * 100.0 / SUM(sale_price),2),'%') AS Convesion_rate,
ROUND(SUM(sale_price)/COUNT (Distinct order_id),2) AS Avg_order_value,
from `sql-dm-project.Ecommerce_data.Ecommerce_table`
GROUP BY gender;

--Which traffic sources (organic, paid, referral) bring the most valuable customers?
Select traffic_source,COUNT(DISTINCT user_id) AS Unique_users
from `sql-dm-project.Ecommerce_data.Ecommerce_table`
WHERE order_status='Complete'
Group By traffic_source;

--What are the top cities/states/countries by revenue contribution?
SELECT
country,
Round(SUM(sale_price),2) AS Total_sales,
from `sql-dm-project.Ecommerce_data.Ecommerce_table`
group by country
Order by SUM(sale_price) DESC

--Which product categories and brands generate the highest sales and profit margins?
SELECT
category,brand,
ROUND(SUM(sale_price),0) AS Revenue,
ROUND(SUM(sale_price)-sum(cost),0) AS Profit,
ROUND((SUM(sale_price) - SUM(cost)) * 100.0 / SUM(sale_price),0) AS Profit_Margin
from `sql-dm-project.Ecommerce_data.Ecommerce_table`
GROUP BY category,brand
ORDER BY Revenue DESC

--What is the average retail price vs. sale price across categories?
SELECT
category,
AVG(retail_price) as Avg_retail_price,
ROUND(SUM(sale_price),0) AS Total_Revenue
from `sql-dm-project.Ecommerce_data.Ecommerce_table`
GROUP By category;

--Which products have the highest return rates?
SELECT
 name,
 category,
 COUNT(order_id) AS Total_orders,
 COUNT(CASE WHEN order_item_status='Returned' THEN order_id END) AS Returned_orders,
 ROUND(COUNT(CASE WHEN order_item_status='Returned' THEN order_id END) * 100.0 / COUNT(order_id), 2) AS Return_rate_percent
FROM `sql-dm-project.Ecommerce_data.Ecommerce_table`
GROUP BY name, category
HAVING Returned_orders < COUNT(order_id)   -- exclude 100% return cases
ORDER BY Return_rate_percent DESC;

--What percentage of orders are returned, and what is the impact on revenue?
SELECT
 category,
 COUNT(CASE WHEN order_item_status='Returned' THEN order_id END) AS No_of_orders_returned,
 COUNT(order_id) AS Total_orders,
 CONCAT(ROUND(COUNT(CASE WHEN order_item_status='Returned' THEN order_id END) * 100.0 / COUNT(order_id), 2), '%') AS Return_rate_percent,
 CONCAT(ROUND(SUM(CASE WHEN order_item_status='Returned' THEN sale_price ELSE 0 END) * 100.0 / SUM(sale_price), 2), '%') AS Revenue_impact
FROM `sql-dm-project.Ecommerce_data.Ecommerce_table`
GROUP BY category
ORDER BY Revenue_impact DESC;

--Which distribution centers handle the most orders?
SELECT
distribution_center_name,
COUNT(CASE WHEN order_item_status='Shipped' THEN order_id END ) AS Orders_shipped_dc
FROM `sql-dm-project.Ecommerce_data.Ecommerce_table`
GROUP BY distribution_center_name
ORDER BY Orders_shipped_dc DESC;


--What is the average cost vs. retail price of inventory items?
SELECT
inv_prod_cat,FORMAT('%.2f₹',SUM(retail_price)/1000000 ) AS Retail_Price_Millions,
FORMAT('%.2f₹',SUM(inv_items_cost) / 1000000 ) AS inv_item_cost_Millions,
CONCAT(ROUND(AVG(inv_items_cost),2),'%') AS Avg_inv_item_cost
FROM `sql-dm-project.Ecommerce_data.Ecommerce_table`
GROUP By inv_prod_cat

--Which product categories are most frequently sold from each distribution center?
SELECT
inv_prod_cat,
distribution_center_name,
COUNT(CASE WHEN order_item_status='Complete' THEN category END) AS sold_inv_prod_cat
FROM `sql-dm-project.Ecommerce_data.Ecommerce_table`
GROUP BY inv_prod_cat,distribution_center_name
ORDER BY sold_inv_prod_cat DESC

--Which traffic sources lead to the highest conversion rates?
SELECT
traffic_source,
COUNT(CASE WHEN order_item_status='Complete'THEN order_id END) AS No_of_orders_purchased,
ROUND(COUNT(CASE WHEN order_item_status='Complete'THEN order_id END) * 100.0 / COUNT(order_id),2) AS Highest_conv_rate
FROM `sql-dm-project.Ecommerce_data.Ecommerce_table`
GROUP BY traffic_source
ORDER BY Highest_conv_rate DESC

--How do events (page views, clicks, sessions) translate into purchases?
SELECT
event_type,
COUNT(CASE WHEN order_item_status='Complete' THEN order_id END) AS Event_based_purchsed_orders,
CONCAT(ROUND(SUM(CASE WHEN order_item_status = 'Complete' THEN sale_price END / 1000000),2),'₹') AS Millions_Revenue_from_events,
COUNT(*) AS Total_events,
CONCAT(ROUND(COUNT(CASE WHEN order_item_status='Complete' THEN order_id END) * 100.0 / COUNT(*),2),'%') AS events_conv_rate
FROM `sql-dm-project.Ecommerce_data.Ecommerce_table`
GROUP BY event_type

--What is the customer journey from event → order → repeat purchase?
WITH customer_orders AS (
 SELECT
   user_id,event_type,
   COUNT(DISTINCT order_id) AS total_orders
 FROM `sql-dm-project.Ecommerce_data.Ecommerce_table`
 WHERE order_item_status = 'Complete'
 GROUP BY user_id,event_type
)
SELECT
 event_type, 
 COUNT(DISTINCT CASE WHEN total_orders >= 1 THEN user_id END) AS customers_with_orders,
 COUNT(DISTINCT CASE WHEN total_orders >= 2 THEN user_id END) AS customers_with_repeat_orders,
 ROUND(COUNT(DISTINCT CASE WHEN total_orders >= 2 THEN user_id END) * 100.0 /
       COUNT(DISTINCT CASE WHEN total_orders >= 1 THEN user_id END), 2) AS repeat_purchase_rate_percent
FROM customer_orders
GROUP BY event_type

--What is the ROAS (Return on Ad Spend) for different traffic sources?
SELECT
traffic_source,
ROUND(SUM(cost)/1000000,0) AS Total_Ads_spent_in_Millions,
ROUND(SUM(sale_price)/1000000,0) AS Total_Returns_in_Millions,
CONCAT(ROUND(SUM(sale_price) *100.0 / SUM(cost),2),'%') AS ROAS
FROM `sql-dm-project.Ecommerce_data.Ecommerce_table`
GROUP BY traffic_source
ORDER BY ROUND(SUM(sale_price)/1000000,0) DESC

--Which browsers or devices show the strongest engagement?
SELECT
browser,
event_type,
COUNT(CASE WHEN order_item_status='Complete' THEN order_id END) AS Event_based_purchsed_orders,
CONCAT(ROUND(SUM(CASE WHEN order_item_status = 'Complete' THEN sale_price END / 1000000),0),'₹') AS Millions_Revenue_from_events,
FROM `sql-dm-project.Ecommerce_data.Ecommerce_table`
GROUP BY browser, event_type
ORDER BY ROUND(SUM(CASE WHEN order_item_status = 'Complete' THEN sale_price END / 1000000),0) DESC

--How do returns affect overall profitability?
SELECT
CONCAT(ROUND(SUM(sale_price)/1000000,0),'M') AS over_all_revenue,
CONCAT(ROUND(SUM(CASE WHEN order_item_status ='Complete' THEN sale_price /1000000 END),0),'M') AS Completed_orders_Revenue,
CONCAT(ROUND(SUM(CASE WHEN order_item_status ='Returned' THEN sale_price /1000000 END),0),'M') AS Returned_orders_Revenue,
CONCAT(ROUND(SUM(CASE WHEN order_item_status ='Complete' THEN sale_price /1000000 END) -
SUM(CASE WHEN order_item_status ='Returned' THEN sale_price /1000000 END),0),'M') AS Differences_in_Revenue
FROM `sql-dm-project.Ecommerce_data.Ecommerce_table`

--What is the lifetime value (LTV) of customers acquired through different channels?
WITH customer_metrics AS (
 SELECT
   traffic_source,
   user_id,
   COUNT(DISTINCT order_id) AS total_orders,
   SUM(CASE WHEN order_item_status = 'Complete' THEN sale_price ELSE 0 END) AS total_revenue
 FROM `sql-dm-project.Ecommerce_data.Ecommerce_table`
 GROUP BY traffic_source, user_id
),
channel_metrics AS (
 SELECT
   traffic_source,
   ROUND(SUM(total_revenue)/COUNT(DISTINCT user_id),2) AS avg_revenue_per_customer,
   ROUND(SUM(total_revenue)/SUM(total_orders),2) AS avg_order_value,
   ROUND(SUM(total_orders)/COUNT(DISTINCT user_id),2) AS purchase_frequency
 FROM customer_metrics
 GROUP BY traffic_source
)
SELECT
 traffic_source,
 avg_order_value,
 purchase_frequency,





