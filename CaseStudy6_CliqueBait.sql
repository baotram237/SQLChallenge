-- Digital Analysis
-- How many users are there?
SELECT 
	COUNT(DISTINCT user_id) AS num_user
FROM users
-- How many cookies does each user have on average?
SELECT 
	AVG(num_cookie) AS avg_num_cookies
FROM
	(SELECT 
		user_id,
		COUNT(e.cookie_id) AS num_cookie
	FROM events e
	JOIN users u
	ON e.cookie_id = u.cookie_id
	GROUP BY u.user_id) AS count_cookie
-- What is the unique number of visits by all users per month?
SELECT 
	DATEPART(MONTH, event_time) AS event_month,
	COUNT(DISTINCT visit_id) AS unique_num_visits
FROM events
GROUP BY DATEPART(MONTH, event_time)
ORDER BY event_month
-- What is the number of events for each event type?
SELECT 
	event_name,
	COUNT(*) AS num_events
FROM events e
JOIN event_identifier i
ON e.event_type = i.event_type
GROUP BY event_name
ORDER BY num_events DESC
-- What is the percentage of visits which have a purchase event?
SELECT 
	COUNT(DISTINCT visit_id) AS total_visits,
	(SELECT
		COUNT(DISTINCT visit_id)
	FROM events
	WHERE event_type = 3) AS purchased,
	(SELECT
	COUNT(DISTINCT visit_id)
	FROM events
	WHERE event_type = 3)*100.00
		/COUNT(DISTINCT visit_id) AS percent_purchase
FROM events
-- What is the percentage of visits which view the checkout page but do not have a purchase event?
SELECT 
	COUNT(DISTINCT visit_id) AS total_visits  ,
	(SELECT 
		COUNT(DISTINCT visit_id)
	FROM events
	WHERE page_id = 12
		AND visit_id NOT IN 
				(SELECT 
					visit_id
				 FROM events
				 WHERE event_type = 3)) AS checkout_without_purchase,
	(SELECT 
		COUNT(DISTINCT visit_id)
	FROM events
	WHERE page_id = 12
		AND visit_id NOT IN 
				(SELECT 
					visit_id
				 FROM events
				 WHERE event_type = 3)) * 100.00
		/COUNT(DISTINCT visit_id) AS percent_checkout_without_purchase
FROM events

-- What are the top 3 pages by number of views?
SELECT 
	TOP 3 page_name,
	COUNT (*) AS page_views
FROM events e
JOIN page_hierarchy p
ON e.page_id = p.page_id
WHERE event_type = 1
GROUP BY page_name
ORDER BY COUNT (*) DESC
-- What is the number of views and cart adds for each product category?
SELECT 
	product_category,
	SUM(CASE 
			WHEN event_type = 1 THEN 1 ELSE 0 END) AS page_views,
	SUM(CASE
			WHEN event_type = 2 THEN 1 ELSE 0 END) AS add_carts
FROM events e
JOIN page_hierarchy p
ON e.page_id = p.page_id
WHERE product_category IS NOT NULL
GROUP BY product_category
-- What are the top 3 products by purchases?
SELECT 
	 TOP 3 page_name,
	 COUNT(*) AS num_purchased
FROM events e
JOIN page_hierarchy p
ON e.page_id = p.page_id
WHERE event_type = 2
AND visit_id IN 
				(SELECT DISTINCT visit_id
				FROM events
				WHERE event_type = 3)
GROUP BY page_name
ORDER BY COUNT(*) DESC
-- Product Funnel Analysis
-- Using a single SQL query - create a new output table which has the following details:
-- How many times was each product viewed?
-- How many times was each product added to cart?
-- How many times was each product added to a cart but not purchased (abandoned)?
-- How many times was each product purchased?

SELECT 
	DISTINCT page_name,
	(SELECT COUNT(*) FROM events e1 WHERE event_type = 1 
									AND e1.page_id = e.page_id) AS viewed,
	(SELECT COUNT(*) FROM events e1 WHERE event_type = 2 
									AND e1.page_id = e.page_id) AS added_to_cart,
	(SELECT COUNT(*) FROM events e1 WHERE event_type = 2
									AND visit_id NOT IN 
										(SELECT DISTINCT visit_id FROM events
										WHERE event_type = 3)
									AND e1.page_id = e.page_id) AS abandoned,
	(SELECT COUNT(*) FROM events e1 WHERE event_type = 2
									AND visit_id IN 
										(SELECT DISTINCT visit_id FROM events
										WHERE event_type = 3)
									AND e1.page_id = e.page_id) AS purchased
FROM events e
JOIN page_hierarchy p
ON e.page_id = p.page_id
WHERE product_category IS NOT NULL
ORDER BY purchased DESC

-- Additionally, create another table which further aggregates 
-- the data for the above points but this time for each product category 
-- instead of individual products.
SELECT
	product_category,
	SUM(viewed) AS viewed,
	SUM(added_to_cart) AS added_to_cart, 
	SUM(abandoned) AS abandoned,
	SUM(purchased) AS purchased,
	SUM(purchased) * 100.00 / SUM(viewed) AS viewed_to_purchased,
	SUM(added_to_cart)*100.00 / SUM(viewed) AS conversion_rate_add_cart,
	SUM(purchased)*100.00 / SUM(added_to_cart) AS conversion_purchase
FROM
		(SELECT 
			DISTINCT product_category,
			page_name,
			(SELECT COUNT(*) FROM events e1 WHERE event_type = 1 
											AND e1.page_id = e.page_id) AS viewed,
			(SELECT COUNT(*) FROM events e1 WHERE event_type = 2 
											AND e1.page_id = e.page_id) AS added_to_cart,
			(SELECT COUNT(*) FROM events e1 WHERE event_type = 2
											AND visit_id NOT IN 
												(SELECT DISTINCT visit_id FROM events
												WHERE event_type = 3)
											AND e1.page_id = e.page_id) AS abandoned,
			(SELECT COUNT(*) FROM events e1 WHERE event_type = 2
											AND visit_id IN 
												(SELECT DISTINCT visit_id FROM events
												WHERE event_type = 3)
											AND e1.page_id = e.page_id) AS purchased
		FROM events e
		JOIN page_hierarchy p
		ON e.page_id = p.page_id
		WHERE product_category IS NOT NULL) AS individual_products
GROUP BY product_category
ORDER BY purchased DESC

-- Which product had the highest view to purchase percentage?
-- What is the average conversion rate from view to cart add?
-- What is the average conversion rate from cart add to purchase?
WITH product_stats AS
	(SELECT 
		DISTINCT page_name,
		(SELECT COUNT(*) FROM events e1 WHERE event_type = 1 
										AND e1.page_id = e.page_id) AS viewed,
		(SELECT COUNT(*) FROM events e1 WHERE event_type = 2 
										AND e1.page_id = e.page_id) AS added_to_cart,
		(SELECT COUNT(*) FROM events e1 WHERE event_type = 2
										AND visit_id NOT IN 
											(SELECT DISTINCT visit_id FROM events
											WHERE event_type = 3)
										AND e1.page_id = e.page_id) AS abandoned,
		(SELECT COUNT(*) FROM events e1 WHERE event_type = 2
										AND visit_id IN 
											(SELECT DISTINCT visit_id FROM events
											WHERE event_type = 3)
										AND e1.page_id = e.page_id) AS purchased
	FROM events e
	JOIN page_hierarchy p
	ON e.page_id = p.page_id
	WHERE product_category IS NOT NULL)
SELECT 
	*,
	purchased * 100.00 / viewed AS viewed_to_purchased,
	added_to_cart * 100.00 / viewed AS conversion_rate_add_cart,
	purchased * 100.00 / added_to_cart AS conversion_purchase
FROM product_stats
ORDER BY 8 DESC,7 DESC,6 DESC

-- Campaigns analysis
-- Campaigns stats
SELECT
	visit_id,
	user_id,

	MIN(event_time) AS visit_start_time,
	(SELECT 
		COUNT(event_type) 
	FROM events e1
	WHERE event_type = 1
	AND e1.visit_id = e.visit_id) AS page_views,

	(SELECT 
		COUNT(event_type) 
	FROM events e2
	WHERE event_type = 2
	AND e2.visit_id = e.visit_id) AS cart_adds,

	CASE WHEN MAX(e.page_id) = 13 THEN 1 ELSE 0 END AS purchase,

	(SELECT 
		campaign_name
	FROM campaign_identifier 
	WHERE MIN(event_time) BETWEEN start_date AND end_date) AS campaign_name,
	
	(SELECT 
		COUNT(event_type) 
	FROM events e4
	WHERE event_type = 4
	AND e4.visit_id = e.visit_id) AS impression,

	(SELECT 
		COUNT(event_type) 
	FROM events e5
	WHERE event_type = 5
	AND e5.visit_id = e.visit_id) AS click,

	(SELECT 
		STRING_AGG( page_name, ', ') AS products
	FROM events e6
	JOIN page_hierarchy p1
	ON e6.page_id = p1.page_id
	WHERE product_id IS NOT NULL
		AND event_type = 2
		AND e.visit_id = e6.visit_id) AS cart_products
FROM events e
JOIN page_hierarchy p
ON e.page_id = p.page_id
JOIN users u
ON u.cookie_id = e.cookie_id
GROUP BY visit_id, user_id
ORDER BY user_id, visit_id

-- create new table to report campaign metrics
SELECT *
INTO campaign_stats
FROM 
(SELECT
	visit_id,
	user_id,

	MIN(event_time) AS visit_start_time,
	(SELECT 
		COUNT(event_type) 
	FROM events e1
	WHERE event_type = 1
	AND e1.visit_id = e.visit_id) AS page_views,

	(SELECT 
		COUNT(event_type) 
	FROM events e2
	WHERE event_type = 2
	AND e2.visit_id = e.visit_id) AS cart_adds,

	CASE WHEN MAX(e.page_id) = 13 THEN 1 ELSE 0 END AS purchase,

	(SELECT 
		campaign_name
	FROM campaign_identifier 
	WHERE MIN(event_time) BETWEEN start_date AND end_date) AS campaign_name,
	
	(SELECT 
		COUNT(event_type) 
	FROM events e4
	WHERE event_type = 4
	AND e4.visit_id = e.visit_id) AS impression,

	(SELECT 
		COUNT(event_type) 
	FROM events e5
	WHERE event_type = 5
	AND e5.visit_id = e.visit_id) AS click,

	(SELECT 
		STRING_AGG( page_name, ', ') AS products
	FROM events e6
	JOIN page_hierarchy p1
	ON e6.page_id = p1.page_id
	WHERE product_id IS NOT NULL
		AND event_type = 2
		AND e.visit_id = e6.visit_id) AS cart_products
FROM events e
JOIN page_hierarchy p
ON e.page_id = p.page_id
JOIN users u
ON u.cookie_id = e.cookie_id
GROUP BY visit_id, user_id) AS stats

-- Analysis campaign result and impact
SELECT * FROM campaign_stats

-- Compare metrics in the group of users who have received impressions during 
-- each campaign and the group of users who did not, and compare with the one who have received
-- impression 

SELECT 
	impression,
	SUM(page_views) AS viewed,
	SUM(cart_adds) AS cart_adds,
	SUM(purchase) AS purchase,
	AVG(purchased) AS purchased_rate
FROM 
	(SELECT 
		*,
		purchase * 100.00 / page_views AS purchased
	FROM campaign_stats) AS extra_stats
WHERE campaign_name IS NOT NULL
GROUP BY impression

SELECT 
	impression,
	click,
	SUM(page_views) AS viewed,
	SUM(cart_adds) AS cart_adds,
	SUM(purchase) AS purchase,
	AVG(purchased) AS purchased_rate
FROM 
	(SELECT 
		*,
		purchase * 100.00 / page_views AS purchased
	FROM campaign_stats) AS extra_stats
WHERE campaign_name IS NOT NULL
GROUP BY click, impression

-- Compare the sucess or failure of each campaign

SELECT 
	campaign_name,
	COUNT(DISTINCT user_id) * 100.00
		/ (SELECT COUNT(DISTINCT user_id) FROM campaign_stats) AS impressed_users,
	SUM(page_views) AS page_views,
	SUM(cart_adds) AS card_adds,
	SUM(purchase) AS purchased,
	SUM(impression) AS impression,
	SUM(click) AS click,
	SUM(click) * 100.00 / SUM(impression) AS click_rate,
	AVG(purchased) AS purchased_rate
FROM 
	(SELECT 
		*,
		purchase * 100.00 / page_views AS purchased
	FROM campaign_stats
	WHERE impression =1 ) AS extra_stats
WHERE campaign_name IS NOT NULL
GROUP BY campaign_name
ORDER BY campaign_name


