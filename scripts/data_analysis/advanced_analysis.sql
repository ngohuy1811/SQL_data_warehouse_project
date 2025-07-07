-- =================================================
-- CHANGE OVER TIME
-- =================================================
SELECT
YEAR(order_date) AS order_year,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date)
-- OR USING DATETRUNC

SELECT
DATETRUNC(month,order_date) AS order_date, --OUT PUT IS DATETIME
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month,order_date)
ORDER BY DATETRUNC(month,order_date)

-- OR
SELECT
FORMAT(order_date,'yyyy-MMM') AS order_date, --OUT PUT IS STRING
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date,'yyyy-MMM')
ORDER BY FORMAT(order_date,'yyyy-MMM')

-- =================================================
-- CUMULATIVE ANALYSIS
-- =================================================
-- Total of sales over time
SELECT 
order_date,
total_sales,
SUM(total_sales) OVER (PARTITION BY order_date ORDER BY order_date) AS running_total_sales,
AVG(avg_price) OVER (ORDER BY order_date) AS moving_average_price
FROM
	(SELECT
	DATETRUNC(month,order_date) AS order_date,
	SUM(sales_amount) AS total_sales,
	AVG(price) AS avg_price
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(month,order_date)
	)t

-- =================================================
-- PERFORMANCE ANALYSIS
-- =================================================
/*Analyze the yearly performance of products by comparing their sales to both the
average sales performance of the product and the previous year's sales */
WITH yearly_product_sales AS
(
SELECT
YEAR(f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS current_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY
YEAR(f.order_date),
p.product_name
)
SELECT
order_year,
product_name,
current_sales,
AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales, 
current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_average,
CASE
	WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
	WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
	ELSE 'Avg'
END avg_change,
LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS pre_sales,
current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_pre_year,
CASE
	WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Good'
	WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Bad'
	ELSE 'No change'
END sales_change
FROM yearly_product_sales
ORDER BY product_name, order_year

-- =================================================
-- PART TO WHOLE ANALYSIS
-- =================================================
/*Which categories contribute the most to overall sales */
WITH category_sales AS (
SELECT
category,
SUM(sales_amount) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
GROUP BY category)

SELECT
  category,
  total_sales,
  SUM(total_sales) OVER () AS all_category_sales,
  CONCAT(ROUND((CAST (total_sales AS FLOAT) / SUM(total_sales) OVER ()) * 100, 2),'%') AS sales_propotion
FROM category_sales
ORDER BY total_sales DESC

-- =================================================
-- DATA SEGMENTATION
-- =================================================
/* Segment products into cost ranges and count how many 
products fall into each segment */
WITH product_segments AS (
SELECT
product_key,
product_name,
cost,
CASE
	WHEN cost < 100 THEN 'Below 100'
	WHEN cost BETWEEN 100 AND 500 THEN '100 - 500'
	WHEN cost BETWEEN 500 AND 1000 THEN '500 - 1000'
	ELSE 'Above 1000'
END cost_range
FROM gold.dim_products)

SELECT
cost_range,
COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC

/* Group customers into three segments */

WITH customer_profile AS 
(
SELECT
c.customer_key,
CONCAT(c.first_name,' ',c.last_name) AS full_name,
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
DATEDIFF(month, MIN(order_date),MAX(order_date)) AS spending_history,
SUM(f.sales_amount) AS total_spending
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c 
ON f.customer_key = c.customer_key
GROUP BY c.customer_key, CONCAT(c.first_name,' ',c.last_name)
)
SELECT
customer_segments,
COUNT(customer_key) AS total_customers
FROM(
	SELECT
	customer_key,
	full_name,
	spending_history,
	total_spending,
	CASE
		WHEN  spending_history >= 12 AND total_spending > 5000 THEN 'VIP'
		WHEN  spending_history >= 12 AND total_spending <= 5000 THEN 'Regular'
		ELSE  'New'
	END AS customer_segments
	FROM customer_profile)t
GROUP BY customer_segments
ORDER BY total_customers