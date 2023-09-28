-- Setup the Database

CREATE DATABASE pizza_runner;
USE pizza_runner;

DROP TABLE IF EXISTS runners;
CREATE TABLE runners (
  "runner_id" INTEGER,
  "registration_date" DATE
);
INSERT INTO runners
  ("runner_id", "registration_date")
VALUES
  (1, '2021-01-01'),
  (2, '2021-01-03'),
  (3, '2021-01-08'),
  (4, '2021-01-15');


DROP TABLE IF EXISTS customer_orders;
CREATE TABLE customer_orders (
  "order_id" INTEGER,
  "customer_id" INTEGER,
  "pizza_id" INTEGER,
  "exclusions" VARCHAR(4),
  "extras" VARCHAR(4),
  "order_time" DATETIME
);

INSERT INTO customer_orders
  ("order_id", "customer_id", "pizza_id", "exclusions", "extras","order_time")
VALUES
  ('1', '101', '1', '', '', '2020-01-01 18:05:02'),
  ('2', '101', '1', '', '', '2020-01-01 19:00:52'),
  ('3', '102', '1', '', '', '2020-01-02 23:51:23'),
  ('3', '102', '2', '', NULL, '2020-01-02 23:51:23'),
  ('4', '103', '1', '4', '', '2020-01-04 13:23:46'),
  ('4', '103', '1', '4', '', '2020-01-04 13:23:46'),
  ('4', '103', '2', '4', '', '2020-01-04 13:23:46'),
  ('5', '104', '1', 'null', '1', '2020-01-08 21:00:29'),
  ('6', '101', '2', 'null', 'null', '2020-01-08 21:03:13'),
  ('7', '105', '2', 'null', '1', '2020-01-08 21:20:29'),
  ('8', '102', '1', 'null', 'null', '2020-01-09 23:54:33'),
  ('9', '103', '1', '4', '1, 5', '2020-01-10 11:22:59'),
  ('10', '104', '1', 'null', 'null', '2020-01-11 18:34:49'),
  ('10', '104', '1', '2, 6', '1, 4', '2020-01-11 18:34:49');


DROP TABLE IF EXISTS runner_orders;
CREATE TABLE runner_orders (
  "order_id" INTEGER,
  "runner_id" INTEGER,
  "pickup_time" DATETIME,
  "distance" VARCHAR(7),
  "duration" VARCHAR(10),
  "cancellation" VARCHAR(23)
);

INSERT INTO runner_orders
  ("order_id", "runner_id", "pickup_time", "distance", "duration", "cancellation")
VALUES
  ('1', '1', '2020-01-01 18:15:34', '20km', '32 minutes', ''),
  ('2', '1', '2020-01-01 19:10:54', '20km', '27 minutes', ''),
  ('3', '1', '2020-01-03 00:12:37', '13.4km', '20 mins', NULL),
  ('4', '2', '2020-01-04 13:53:03', '23.4', '40', NULL),
  ('5', '3', '2020-01-08 21:10:57', '10', '15', NULL),
  ('6', '3', NULL, 'null', 'null', 'Restaurant Cancellation'),
  ('7', '2', '2020-01-08 21:30:45', '25km', '25mins', 'null'),
  ('8', '2', '2020-01-10 00:15:02', '23.4 km', '15 minute', 'null'),
  ('9', '2', NULL, 'null', 'null', 'Customer Cancellation'),
  ('10', '1', '2020-01-11 18:50:20', '10km', '10minutes', 'null');


DROP TABLE IF EXISTS pizza_names;
CREATE TABLE pizza_names (
  "pizza_id" INTEGER,
  "pizza_name" TEXT
);
INSERT INTO pizza_names
  ("pizza_id", "pizza_name")
VALUES
  (1, 'Meatlovers'),
  (2, 'Vegetarian');


DROP TABLE IF EXISTS pizza_recipes;
CREATE TABLE pizza_recipes (
  "pizza_id" INTEGER,
  "toppings" TEXT
);
INSERT INTO pizza_recipes
  ("pizza_id", "toppings")
VALUES
  (1, '1, 2, 3, 4, 5, 6, 8, 10'),
  (2, '4, 6, 7, 9, 11, 12');


DROP TABLE IF EXISTS pizza_toppings;
CREATE TABLE pizza_toppings (
  "topping_id" INTEGER,
  "topping_name" TEXT
);
INSERT INTO pizza_toppings
  ("topping_id", "topping_name")
VALUES
  (1, 'Bacon'),
  (2, 'BBQ Sauce'),
  (3, 'Beef'),
  (4, 'Cheese'),
  (5, 'Chicken'),
  (6, 'Mushrooms'),
  (7, 'Onions'),
  (8, 'Pepperoni'),
  (9, 'Peppers'),
  (10, 'Salami'),
  (11, 'Tomatoes'),
  (12, 'Tomato Sauce');

-- Challenges

-- Clean the dataset
SELECT *
FROM customer_orders

UPDATE customer_orders
SET exclusions = NULL 
WHERE exclusions ='' OR exclusions = 'null'
UPDATE customer_orders
SET extras = NULL
WHERE extras = '' OR extras = 'null'

SELECT * FROM runner_orders
UPDATE runner_orders
SET distance = NULL WHERE distance = 'null'

SELECT * FROM runner_orders
UPDATE runner_orders
SET duration = NULL WHERE duration = 'null'

UPDATE runner_orders
SET cancellation = NULL WHERE cancellation = 'null' OR cancellation =''

UPDATE runner_orders
SET distance = 
	CASE
		WHEN CHARINDEX ('km', distance) = 0 THEN CAST(distance AS DECIMAL(5,2))
		ELSE CAST(SUBSTRING(distance, 1, CHARINDEX ('km',distance)-1 ) AS DECIMAL(5,2))
	END
WHERE distance IS NOT NULL;

UPDATE runner_orders
SET duration = 
	CASE
		WHEN CHARINDEX ('min', duration) = 0 THEN CAST(duration AS INT)
		ELSE CAST(SUBSTRING(duration, 1, CHARINDEX ('min',duration)-1 ) AS INT)
	END
WHERE duration IS NOT NULL;

SELECT * FROM runner_orders

-- Pizza Metrics:
-- How many pizzas were ordered?
-- How many unique customer orders were made?
SELECT 
	COUNT(DISTINCT customer_id) AS unique_customers,
	COUNT(DISTINCT c.order_id) AS total_orders,
	COUNT(pizza_id) AS total_pizza
FROM customer_orders c
JOIN runner_orders r
ON c.order_id = r.order_id
WHERE cancellation IS NULL;

-- How many successful orders were delivered by each runner?
SELECT 
	runner_id,
	COUNT(pizza_id) AS num_pizzas
FROM runner_orders r
JOIN customer_orders c
ON r.order_id = c.order_id
WHERE cancellation IS NULL
GROUP BY runner_id

-- How many of each type of pizza was delivered?
SELECT 
	customer_id,
	[1] AS Meatlovers,
	[2] AS Vegetarian
FROM
(SELECT 
	customer_id,
	p.pizza_id
FROM pizza_names p
JOIN customer_orders c
ON p.pizza_id = c.pizza_id
JOIN runner_orders r
ON r.order_id = c.order_id
WHERE cancellation IS NULL) AS count_num_pizzas
PIVOT 
	( COUNT(pizza_id)
		FOR pizza_id IN ([1],[2])
	) AS pivot_table

-- What was the maximum number of pizzas delivered in a single order
SELECT TOP 1 COUNT(pizza_id) AS max_pizzas
FROM customer_orders c
JOIN runner_orders r
ON r.order_id  = c.order_id
WHERE cancellation IS NULL
GROUP BY c.order_id
ORDER BY max_pizzas DESC

-- For each customer, how many delivered pizzas had at least 
-- 1 change and how many had no changes?
SELECT 
	customer_id,
	SUM(CASE WHEN extras IS NULL AND exclusions IS NULL THEN 1
		ELSE 0 END) AS no_change,
	SUM(CASE WHEN extras IS NOT NULL OR exclusions IS NOT NULL THEN 1
		ELSE 0 END) AS changed
FROM customer_orders c
JOIN runner_orders r
ON c.order_id = r.order_id
WHERE cancellation IS NULL
GROUP BY customer_id

-- How many pizzas were delivered that had both exclusions and extras?
SELECT COUNT(pizza_id)
FROM customer_orders c
JOIN runner_orders r
ON c.order_id = r.order_id
WHERE cancellation IS NULL
AND exclusions IS NOT NULL
AND extras IS NOT NULL

-- What was the total volume of pizzas ordered for each hour of the day?
SELECT 
	DATEPART(HOUR, order_time) AS hour_of_day,
	COUNT(pizza_id)
FROM customer_orders c
JOIN runner_orders r
ON c.order_id = r.order_id
WHERE cancellation IS NULL
GROUP BY DATEPART(HOUR, order_time)
ORDER BY hour_of_day

-- What was the volume of orders for each day of the week?
SELECT 
	DATENAME(WEEKDAY, order_time) AS day_of_week,
	COUNT(pizza_id)
FROM customer_orders c
JOIN runner_orders r
ON c.order_id = r.order_id
WHERE cancellation IS NULL
GROUP BY DATENAME(WEEKDAY, order_time)
ORDER BY day_of_week

-- Runner and Customer Experience
-- How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT
	registration_date,
	DATEDIFF(week, '2021-01-01',registration_date) AS week_number,
	COUNT(runner_id) OVER (PARTITION BY DATEDIFF(week, '2021-01-01',registration_date)) AS signups
FROM runners

-- What was the average time in minutes it took for each runner to arrive at 
-- the Pizza Runner HQ to pickup the order?
SELECT 
	runner_id,
	AVG(DATEPART(MINUTE, pickup_time - order_time)) AS avg_pickup_time
FROM customer_orders c
JOIN runner_orders r
ON r.order_id = c.order_id
WHERE cancellation IS NULL
GROUP BY runner_id

-- What was the average distance travelled for each customer?
SELECT 
	customer_id,
	ROUND(AVG(CAST(distance AS DECIMAL(5,2))),2) AS avg_distance
FROM runner_orders r
JOIN customer_orders c
ON r.order_id = c.order_id
WHERE cancellation IS NULL
GROUP BY customer_id

-- What was the difference between the longest and shortest delivery times for all orders?
SELECT
	MAX(CAST(duration AS INT)) - MIN (CAST(duration AS INT)) AS difference
FROM runner_orders 
WHERE cancellation IS NULL

-- What was the average speed for each runner for each delivery?
SELECT
	runner_id,
	order_id,
	distance,
	duration,
	AVG(CAST(distance AS DECIMAL(5,2))/CAST(duration AS INT)) 
		OVER (PARTITION BY runner_id , order_id) AS avg_speed
FROM runner_orders 
WHERE cancellation IS NULL
ORDER BY runner_id, order_id;

-- What is the successful delivery percentage for each runner?
SELECT 
    r.runner_id,
    COUNT(DISTINCT ro.order_id) AS num_orders,
    SUM(CASE WHEN ro.cancellation IS NULL THEN 1 ELSE 0 END) AS success_order,
    (SUM(CASE WHEN ro.cancellation IS NULL THEN 1 ELSE 0 END)*100.00) / COUNT(DISTINCT ro.order_id) AS success
FROM runner_orders ro
JOIN runners r 
ON ro.runner_id = r.runner_id
GROUP BY r.runner_id;

-- Ingredient Optimisation

-- What are the standard ingredients for each pizza?
SELECT 
    n.pizza_id,
	CAST(n.pizza_name AS NVARCHAR(MAX)) AS pizza_name,
    STRING_AGG(CAST(t.topping_name AS NVARCHAR(MAX)), ', ') AS toppings
FROM pizza_names n
JOIN pizza_recipes r
ON n.pizza_id = r.pizza_id
CROSS APPLY
    STRING_SPLIT(CAST(r.toppings AS NVARCHAR(MAX)), ',') s
JOIN pizza_toppings t
ON TRY_CAST(s.value AS INT) = t.topping_id
GROUP BY n.pizza_id, CAST(n.pizza_name AS NVARCHAR(MAX))

-- What was the most commonly added extra?
SELECT TOP 1
   CAST(t.topping_name AS NVARCHAR(MAX)) AS most_common_extra
FROM customer_orders c
JOIN pizza_recipes r
ON c.pizza_id = r.pizza_id
CROSS APPLY
    STRING_SPLIT(CAST(c.extras AS NVARCHAR(MAX)), ',') s
JOIN pizza_toppings t
ON TRY_CAST(s.value AS INT) = t.topping_id
GROUP BY CAST(t.topping_name AS NVARCHAR(MAX))
ORDER BY COUNT(s.value) DESC

-- What was the most common exclusion?
SELECT TOP 1
   CAST(t.topping_name AS NVARCHAR(MAX)) AS most_common_exclusion
FROM customer_orders c
JOIN pizza_recipes r
ON c.pizza_id = r.pizza_id
CROSS APPLY
    STRING_SPLIT(CAST(c.exclusions AS NVARCHAR(MAX)), ',') s
JOIN pizza_toppings t
ON TRY_CAST(s.value AS INT) = t.topping_id
GROUP BY CAST(t.topping_name AS NVARCHAR(MAX))
ORDER BY COUNT(s.value) DESC

-- Generate an order item for each record in the customers_orders table in the format of one of the following:
-- Meat Lovers; Meat Lovers - Exclude Beef; Meat Lovers - Extra Bacon; Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

SELECT 
	order_id,
	CONCAT (
	(SELECT 
		pizza_name 
		FROM pizza_names n
		WHERE n.pizza_id = c.pizza_id),
	(SELECT 
		CASE 
		WHEN c.exclusions IS NOT NULL 
		THEN CONCAT (' - Exclude ', STRING_AGG (CAST(t.topping_name AS NVARCHAR(MAX)), ', '))
		ELSE '' END
		FROM pizza_recipes r
		CROSS APPLY
			STRING_SPLIT(CAST(c.exclusions AS NVARCHAR(MAX)), ',') s
		JOIN pizza_toppings t
		ON TRY_CAST(s.value AS INT) = t.topping_id
		WHERE r.pizza_id = c.pizza_id),
	(SELECT 
		CASE
		WHEN c.extras IS NOT NULL
		THEN CONCAT(' - Extra ',STRING_AGG (CAST(t.topping_name AS NVARCHAR(MAX)), ', '))
		ELSE '' END
		FROM pizza_recipes r
		CROSS APPLY
			STRING_SPLIT(CAST(c.extras AS NVARCHAR(MAX)), ',') s
		JOIN pizza_toppings t
		ON TRY_CAST(s.value AS INT) = t.topping_id
		WHERE r.pizza_id = c.pizza_id)) AS order_desription
FROM customer_orders c

-- Pricing 

-- If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - 
-- how much money has Pizza Runner made so far if there are no delivery fees?
SELECT 
	SUM(sale) AS total_sales
FROM
(SELECT 
	(COUNT(pizza_id) *
		CASE 
		WHEN pizza_id = 1 THEN 12 
		ELSE 10 END) AS sale
FROM customer_orders c
JOIN runner_orders r
ON c.order_id  =r.order_id
WHERE cancellation IS NULL
GROUP BY pizza_id) AS pricing

SELECT * FROM pizza_toppings

-- What if there was an additional $1 charge for any pizza extras?
-- Add cheese is $1 extra
SELECT 
	SUM(sale) AS total_sales
FROM
(SELECT 
	(COUNT(pizza_id) *
		CASE 
		WHEN pizza_id = 1 THEN 
							12 + CASE WHEN extras LIKE '%4%' THEN 1 ELSE 0 END
		ELSE 10 + CASE WHEN extras LIKE '%4%' THEN 1 ELSE 0 END
		END) AS sale
FROM customer_orders c
JOIN runner_orders r
ON c.order_id  =r.order_id
WHERE cancellation IS NULL
GROUP BY pizza_id,extras ) AS pricing

-- If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and 
-- each runner is paid $0.30 per kilometre traveled.
-- how much money does Pizza Runner have left over after these deliveries?

SELECT 
	r.order_id,
	(SELECT SUM(each_pizza)
	FROM
		(SELECT 
			order_id,
			pizza_id,
			(COUNT(pizza_id) *
			CASE 
			WHEN pizza_id = 1 THEN 12 
			ELSE 10 END) AS each_pizza
		FROM customer_orders
		GROUP BY order_id, pizza_id)AS pricing
	WHERE pricing.order_id = r.order_id
	GROUP BY order_id) AS sales,
	distance,
	CAST(distance AS DECIMAL(5,2))*0.30 AS shipping_fee,
	(SELECT SUM(each_pizza)
	FROM
		(SELECT 
			order_id,
			pizza_id,
			(COUNT(pizza_id) *
			CASE 
			WHEN pizza_id = 1 THEN 12 
			ELSE 10 END) AS each_pizza
		FROM customer_orders
		GROUP BY order_id, pizza_id)AS pricing
	WHERE pricing.order_id = r.order_id
	GROUP BY order_id) - CAST(distance AS DECIMAL(5,2))*0.30 AS left_over
FROM customer_orders c
JOIN runner_orders r
ON c.order_id = r.order_id
WHERE cancellation IS NULL
GROUP BY r.order_id, distance
