-- Sales analysis

-- What was the total quantity sold for all products?
-- What is the total generated revenue for all products before discounts?
-- What was the total discount amount for all products?

SELECT
	SUM(qty) AS total_quantity_sold,
	SUM(price * qty) AS generated_revenue_before_discounts,
	SUM(discount) AS total_discounts
FROM sales

-- Transaction Analysis

-- How many unique transactions were there?
-- What is the average unique products purchased in each transaction?
-- What is the average discount value per transaction?

SELECT
	COUNT(DISTINCT txn_id) AS unique_transactions,

	(SELECT
		AVG(uni_products)
	FROM (SELECT 
			COUNT(DISTINCT prod_id) AS uni_products
		  FROM sales
		  GROUP BY txn_id) AS unique_products) AS avg_unique_products,

	(SELECT
		AVG(discount_val)
	FROM (SELECT 
			SUM(discount) AS discount_val
		  FROM sales
		  GROUP BY txn_id) AS discount_value) AS avg_discount_per_transaction
FROM sales

-- What are the 25th, 50th and 75th percentile values for the revenue per transaction?
WITH revenue AS
(SELECT
		(SUM(price * qty) - SUM(discount)) AS revenue_value
	FROM sales
	GROUP BY txn_id)
SELECT
	DISTINCT 
	PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY revenue_value) OVER() AS "25th Percentile",
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue_value) OVER() AS "50th Percentile",
	PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue_value) OVER() AS "75th Percentile"
FROM revenue

-- What is the percentage split of all transactions for members vs non-members?
-- What is the average revenue for member transactions and non-member transactions?

SELECT
	CASE WHEN member = 't' THEN 'Member'
		 ELSE 'Non - member' END AS member_type,
	COUNT(DISTINCT txn_id) AS num_transactions,
	CAST(COUNT(DISTINCT txn_id) * 100.0 / SUM(COUNT(DISTINCT txn_id)) OVER () AS DECIMAL ( 5,2)) AS percent_transactions,
	(SELECT 
		AVG(revenue_value) 
	FROM
		(SELECT
		member,
		txn_id,
		(SUM(price * qty) - SUM(discount)) AS revenue_value
		FROM sales
		GROUP BY txn_id, member) AS revenue
	WHERE s1.member = revenue.member
	) AS avg_revenue
FROM sales s1
GROUP BY 
	CASE WHEN member = 't' THEN 'Member'
		 ELSE 'Non - member' END, s1.member

-- Product Analysis

-- What are the top 3 products by total revenue before discount?
SELECT 
	TOP 3 
	product_name,
	SUM(qty * s.price) AS revenue_before_discount
FROM sales s
JOIN product_details p
ON s.prod_id = p.product_id
GROUP BY p.product_name
ORDER BY SUM(qty * s.price) DESC

-- What is the total transaction “penetration” for each product? 
-- (hint: penetration = number of transactions where at least 1 
-- quantity of a product was purchased divided by total number of transactions)
SELECT 
	product_name,
	COUNT(DISTINCT txn_id) AS num_transactions,
	CAST (COUNT(DISTINCT txn_id) *100.00 / 
	(SELECT 
		COUNT(DISTINCT txn_id) FROM sales) AS DECIMAL (5,2)) AS penetration
FROM sales s
JOIN product_details p
ON s.prod_id = p.product_id
GROUP BY product_name
ORDER BY penetration DESC

-- What is the total quantity, revenue and discount for each segment?
-- What is the top selling product for each segment?
WITH rank_by_quantity AS
	(SELECT 
	product_name,
	segment_name,
	SUM(qty) AS total_quantity,
	RANK() OVER(PARTITION BY segment_name ORDER BY SUM(qty) DESC) AS ranking
	FROM sales s
	JOIN product_details p
	ON s.prod_id = p.product_id
	GROUP BY segment_name, product_name)
SELECT 
	segment_name,
	SUM(qty) AS total_quantity,
	SUM(qty * p.price) AS revenue_berfore_discount,
	SUM(discount) AS total_discount,
	SUM(qty * p.price) - SUM(discount) AS total_revenue,
	(SELECT 
		product_name
	 FROM rank_by_quantity r
	 WHERE ranking = 1
	 AND r.segment_name = p.segment_name) AS best_seller
FROM sales s
JOIN product_details p
ON s.prod_id = p.product_id
GROUP BY segment_name, segment_id

-- What is the percentage split of revenue by product for each segment?
SELECT 
	*,
	(SELECT 
			SUM(qty * p1.price) - SUM(discount)
		FROM sales s1
		JOIN product_details p1
		ON s1.prod_id = p1.product_id
		WHERE product_stats.segment_name = p1.segment_name) AS total_segment_revenue,
	CAST(revenue * 100.00 / 
		(SELECT 
			SUM(qty * p1.price) - SUM(discount)
		FROM sales s1
		JOIN product_details p1
		ON s1.prod_id = p1.product_id
		WHERE product_stats.segment_name = p1.segment_name)AS DECIMAL(5,2)) AS percent_split
FROM 
	(SELECT 
		segment_name, 
		product_name,
		SUM(qty * p.price) - SUM(discount) AS revenue
	FROM sales s
	JOIN product_details p
	ON s.prod_id = p.product_id
	GROUP BY segment_name, product_name) AS product_stats
ORDER BY total_segment_revenue DESC, percent_split DESC

-- What is the total quantity, revenue and discount for each category?
-- What is the top selling product for each category?
WITH rank_by_quantity AS
	(SELECT 
	product_name,
	category_name,
	SUM(qty) AS total_quantity,
	RANK() OVER(PARTITION BY category_name ORDER BY SUM(qty) DESC) AS ranking
	FROM sales s
	JOIN product_details p
	ON s.prod_id = p.product_id
	GROUP BY category_name, product_name)
SELECT 
	category_name,
	SUM(qty) AS total_quantity,
	SUM(qty * p.price) AS revenue_berfore_discount,
	SUM(discount) AS total_discount,
	SUM(qty * p.price) - SUM(discount) AS total_revenue,
	(SELECT 
		product_name
	 FROM rank_by_quantity r
	 WHERE ranking = 1
	 AND r.category_name = p.category_name) AS best_seller
FROM sales s
JOIN product_details p
ON s.prod_id = p.product_id
GROUP BY category_name

-- What is the percentage split of revenue by segment for each category?
-- What is the percentage split of total revenue by category?
SELECT 
	category_name,

	(SELECT 
			SUM(qty * p1.price) - SUM(discount)
		FROM sales s1
		JOIN product_details p1
		ON s1.prod_id = p1.product_id
		WHERE segment_stats.category_name = p1.category_name) AS total_category_revenue,
	
	CAST((SELECT 
			SUM(qty * p1.price) - SUM(discount)
		FROM sales s1
		JOIN product_details p1
		ON s1.prod_id = p1.product_id
		WHERE segment_stats.category_name = p1.category_name) * 100.00
		/ (SELECT SUM(qty * price) - SUM(discount) FROM sales) AS DECIMAL(5,2)) AS category_percent,

	segment_name,
	total_segment_revenue,

	CAST(total_segment_revenue * 100.00 / 
		(SELECT 
			SUM(qty * p1.price) - SUM(discount)
		FROM sales s1
		JOIN product_details p1
		ON s1.prod_id = p1.product_id
		WHERE segment_stats.category_name = p1.category_name)AS DECIMAL(5,2)) AS segment_percent
FROM 
	(SELECT 
		segment_name, 
		category_name,
		SUM(qty * p.price) - SUM(discount) AS total_segment_revenue
	FROM sales s
	JOIN product_details p
	ON s.prod_id = p.product_id
	GROUP BY category_name, segment_name) AS segment_stats
ORDER BY total_category_revenue DESC, segment_percent DESC

-- What is the most common combination of at least 1 
-- quantity of any 3 products in a 1 single transaction?

WITH ProductCombinations AS 
    (SELECT DISTINCT txn_id, prod_id, product_name
    FROM sales s
	JOIN product_details p
	ON s.prod_id = p. product_id)
SELECT 
	TOP 1
	p1.product_name AS product1, 
	p2.product_name AS product2, 
	p3.product_name AS product3, 
	COUNT(*) AS combination_count
FROM ProductCombinations p1
JOIN ProductCombinations p2 
	ON p1.txn_id = p2.txn_id AND p1.prod_id <> p2.prod_id
JOIN ProductCombinations p3 
	ON p2.txn_id = p3.txn_id AND p2.prod_id <> p3.prod_id
GROUP BY p1.product_name, p2.product_name, p3.product_name
ORDER BY combination_count DESC

-- Data modeling
-- Use a single SQL query to transform the product_hierarchy 
-- and product_prices datasets to the product_details table.

WITH category_level AS
	(SELECT
		id AS category_id,
		level_text AS category_name
	FROM product_hierarchy
	WHERE level_name = 'Category'),
	segment_level AS
	(SELECT
		id AS segment_id,
		parent_id,
		level_text AS segment_name
	FROM product_hierarchy
	WHERE level_name = 'Segment')
SELECT 
	p.product_id,
	p.price,
	CONCAT(h.level_text ,' -  ' ,c.category_name) AS product_name,
	c.category_id,
	s.segment_id,
	h.id AS style_id,
	c.category_name,
	s.segment_name,
	h.level_text AS style_name
FROM product_hierarchy h
JOIN product_prices p
ON h.id = p.id
JOIN segment_level s
ON h.parent_id = s.segment_id
JOIN category_level c
ON s.parent_id = c.category_id

