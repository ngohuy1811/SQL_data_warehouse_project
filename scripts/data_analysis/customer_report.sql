/*
==================================================================================
Customer Report
==================================================================================
*/
CREATE VIEW gold.report_customers AS
WITH base_query AS (
	SELECT 
	f.order_number,
	f.product_key,
	f.order_date,
	f.sales_amount,
	f.quantity,
	c.customer_key,
	c.customer_number,
	CONCAT(c.first_name, ' ' ,c.last_name) AS customer_name,
	DATEDIFF (year, c.birthdate, GETDATE()) AS age
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_customers c
	ON c.customer_key = f.customer_key
	WHERE order_date IS NOT NULL)

, customer_aggregation AS (

	SELECT
	customer_key,
	customer_number,
	customer_name,
	age,
	COUNT(DISTINCT order_number) AS total_order,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT product_key) AS total_product,
	MAX(order_date) AS last_order_date,
	DATEDIFF(month, MIN(order_date),MAX(order_date)) AS lifespan
	FROM base_query
	GROUP BY customer_key, customer_number, customer_name, age)
SELECT 
customer_key,
customer_number,
customer_name,
age,
CASE 
		WHEN age < 20 THEN 'Under 20'
		WHEN age BETWEEN 20 AND 29 THEN '20 - 29'
		WHEN age BETWEEN 30 AND 39 THEN '30 - 39'
		WHEN age BETWEEN 40 AND 49 THEN '40 - 49'
		ELSE '50 and above'
END AS age_group,
CASE
		WHEN  lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
		WHEN  lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
		ELSE  'New'
END AS customer_segments,
last_order_date,
DATEDIFF(month,last_order_date,GETDATE()) AS recency,
total_order,
total_sales,
CASE 
	WHEN total_order = 0 THEN 0
	ELSE total_sales/total_order 
END AS avg_order_value,
total_quantity,
total_product,
lifespan,
CASE 
	WHEN lifespan = 0 THEN 0
	ELSE total_sales/lifespan 
END AS avg_monthly_spending
FROM customer_aggregation