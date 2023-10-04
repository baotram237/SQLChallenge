-- Setup database

CREATE DATABASE dannys_diner;
USE dannys_diner;

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 
CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  
CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

-- Challenges

-- 1. What is the total amount each customer spent at the restaurant?
SELECT s.customer_id, 
		SUM(m.price) AS total_amount
FROM menu m
JOIN sales s
ON m.product_id = s.product_id
GROUP BY s.customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT 	customer_id,
		COUNT (DISTINCT order_date) AS no_days_visit
FROM sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
SELECT s1.customer_id, 
		m.product_name
FROM menu m
JOIN sales s1
ON m.product_id = s1.product_id
WHERE s1.order_date IN 
        (SELECT MIN(order_date)
     FROM sales s2
     WHERE s1.customer_id = s2.customer_id)
GROUP BY s1.customer_id, m.product_name;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT TOP 1
    m.product_name, 
    COUNT(*) AS no_buy
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY no_buy DESC;

-- 5. Which item was the most popular for each customer?
WITH RankedItems AS (
    SELECT 
        customer_id,
        product_id,
        COUNT(product_id) AS purchase_count,
        RANK() OVER(PARTITION BY customer_id ORDER BY COUNT(product_id) DESC) AS rank
    FROM sales
    GROUP BY customer_id, product_id
)
SELECT
    r.customer_id,
    r.product_id,
    m.product_name,
    r.purchase_count
FROM RankedItems r
JOIN menu m
ON r.product_id = m.product_id
WHERE rank = 1
ORDER BY r.customer_id;

-- 6. Which item was purchased first by the customer after they became a member?
WITH CustomerFirstPurchases AS (
  SELECT
    s.customer_id,
    m.join_date,
    MIN(s.order_date) AS first_purchase_date
  FROM sales s
  JOIN members m 
  ON s.customer_id = m.customer_id
  WHERE s.order_date >= m.join_date
  GROUP BY s.customer_id, m.join_date)
SELECT
  cf.customer_id,
  cf.join_date,
  s.product_id,
  m.product_name,
  cf.first_purchase_date
FROM CustomerFirstPurchases cf
JOIN sales s 
ON cf.customer_id = s.customer_id 
AND cf.first_purchase_date = s.order_date
JOIN menu m 
ON s.product_id = m.product_id;

-- 7. Which item was purchased just before the customer became a member?
WITH PurchasesBeforeJoin AS (
  SELECT
    s.customer_id,
  	join_date,
  	MAX(s.order_date) AS date_before_join
  FROM sales s
  JOIN members m 
  ON s.customer_id = m.customer_id
  WHERE s.order_date < m.join_date
  GROUP BY s.customer_id, join_date)
SELECT
  s.customer_id,
  pb.join_date,
  m.product_name,
  pb.date_before_join
FROM PurchasesBeforeJoin pb
JOIN sales s 
ON pb.customer_id = s.customer_id 
AND pb.date_before_join = s.order_date
JOIN menu m 
ON s.product_id = m.product_id;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT 
	s.customer_id,
    COUNT(s.product_id) AS total_items,
    SUM(m.price) AS total_amount
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
LEFT JOIN members me
ON s.customer_id = me.customer_id
WHERE order_date < join_date
GROUP BY s.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT customer_id,
		SUM(point) AS points
FROM 
(SELECT s.customer_id,
		s.product_id,
     CASE 
     WHEN s.product_id = 1 THEN price*20
     ELSE price*10
     END AS point
FROM sales s
JOIN menu m
ON s.product_id = m.product_id) AS pointing
GROUP BY customer_id
ORDER BY points DESC;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT customer_id,
		SUM(point) AS points
FROM (SELECT s.customer_id,
		s.product_id,
     CASE 
	 WHEN s.order_date BETWEEN join_date AND DATEADD(DAY, 7, me.join_date) THEN price*20
     WHEN s.product_id = 1 THEN price*20
     ELSE price*10
     END AS point
FROM sales s
LEFT JOIN menu m
ON s.product_id = m.product_id
LEFT JOIN members me
ON s.customer_id = me.customer_id) AS pointing
GROUP BY customer_id
ORDER BY points DESC;
