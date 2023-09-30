-- Customer Nodes exploration

-- How many unique nodes are there on the Data Bank system?
SELECT 
	COUNT(DISTINCT node_id) AS num_nodes
FROM customer_nodes
-- What is the number of nodes per region?
SELECT 
	r.region_name,
	COUNT( DISTINCT node_id) AS num_nodes
FROM customer_nodes c
JOIN regions r
ON c.region_id = r.region_id
GROUP BY r.region_name
-- How many customers are allocated to each region?
SELECT 
	r.region_name,
	COUNT(DISTINCT customer_id) AS num_customers
FROM customer_nodes c
JOIN regions r
ON c.region_id = r.region_id
GROUP BY r.region_name
-- How many days on average are customers reallocated to a different node?

SELECT 
	AVG(avg_days) AS avg_days_reallocated
FROM
(SELECT 
	customer_id, 
	AVG(interval_days) AS avg_days
FROM 
(SELECT 
	customer_id,
	DATEDIFF(DAY, start_date, end_date) AS interval_days
FROM customer_nodes) AS calculate_interval
GROUP BY customer_id) AS group_cus

-- What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
WITH avg_days_per_cus
AS (SELECT 
		customer_id, 
		region_id,
		AVG(interval_days) AS avg_days
	FROM 
			(SELECT 
				customer_id,
				region_id,
				DATEDIFF(DAY, start_date, end_date) AS interval_days
			FROM customer_nodes 
			) AS calculate_interval
	GROUP BY customer_id, region_id)
SELECT
	DISTINCT region_id,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_days) 
			OVER(PARTITION BY region_id) AS Median,
	PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY avg_days) 
			OVER(PARTITION BY region_id) AS _80th,
	PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY avg_days) 
			OVER(PARTITION BY region_id) AS _95th
FROM avg_days_per_cus

-- Customer Transactions
-- What is the unique count and total amount for each transaction type?
SELECT 
	txn_type,
	COUNT(*) AS num_trans,
	SUM(txn_amount) AS total_amount
FROM customer_transactions
GROUP BY txn_type

-- What is the average total historical deposit counts and amounts for all customers?
SELECT 
	COUNT(*) AS total_deposit_counts,
	AVG(txn_amount) AS avg_deposit_amounts
FROM customer_transactions
WHERE txn_type = 'deposit'

-- For each month - how many Data Bank customers make more than 1 deposit and either 
-- 1 purchase or 1 withdrawal in a single month?
SELECT 
	month_transactions,
	COUNT(DISTINCT customer_id) AS num_cus
FROM
	(SELECT 
		customer_id,
		DATEPART(MONTH, txn_date) AS month_transactions,
		COUNT(*) OVER(PARTITION BY customer_id, DATEPART(MONTH, txn_date)) AS num_transactions_in_month
	FROM customer_transactions) AS calculate
WHERE num_transactions_in_month > 1
GROUP BY month_transactions
ORDER BY month_transactions

-- What is the closing balance for each customer at the end of the month?
CREATE FUNCTION dbo.closing_balance
	(@customer_id INT,
	 @month INT)
RETURNS INT
AS 
BEGIN
	DECLARE @closing_balance INT;
	SET @closing_balance =
		(SELECT 
				SUM (CASE
						WHEN txn_type = 'deposit' THEN txn_amount
						ELSE - txn_amount END)
		FROM customer_transactions
		WHERE DATEPART(MONTH, txn_date) <= @month
		AND customer_id = @customer_id)
	RETURN @closing_balance;
END;

SELECT 
	customer_id,
	COALESCE([1], dbo.closing_balance ( customer_id , 1)) AS month1,
    COALESCE([2], dbo.closing_balance ( customer_id , 2)) AS month2,
    COALESCE([3], dbo.closing_balance ( customer_id , 3)) AS month3,
    COALESCE([4], dbo.closing_balance ( customer_id , 4)) AS month4
FROM
(SELECT 
	customer_id,
	DATEPART(MONTH, txn_date) AS _month,
	dbo.closing_balance ( customer_id , DATEPART(MONTH, txn_date)) AS closing_balance
FROM customer_transactions
GROUP BY customer_id, DATEPART(MONTH, txn_date)) AS source_table
	PIVOT (
		SUM(closing_balance)
		FOR _month IN ([1], [2], [3], [4])  
	) AS pivot_table

-- Percentage change from each month?

SELECT 
	customer_id,
	CAST( month2 * 100.00 / NULLIF (month1,0) AS DECIMAL(10,2)) AS change12,
	CAST( month3 * 100.00 / NULLIF (month2,0) AS DECIMAL(10,2)) AS change23,
	CAST( month4 * 100.00 / NULLIF (month3,0) AS DECIMAL(10,2)) AS change34,
	CAST( month4 * 100.00 / NULLIF (month1,0) AS DECIMAL(10,2)) AS changeoverall
FROM 
	(SELECT 
		customer_id,
		COALESCE([1], dbo.closing_balance ( customer_id , 1)) AS month1,
		COALESCE([2], dbo.closing_balance ( customer_id , 2)) AS month2,
		COALESCE([3], dbo.closing_balance ( customer_id , 3)) AS month3,
		COALESCE([4], dbo.closing_balance ( customer_id , 4)) AS month4
	FROM
	(SELECT 
		customer_id,
		DATEPART(MONTH, txn_date) AS _month,
		dbo.closing_balance ( customer_id , DATEPART(MONTH, txn_date)) AS closing_balance
	FROM customer_transactions
	GROUP BY customer_id, DATEPART(MONTH, txn_date)) AS source_table
		PIVOT (
			SUM(closing_balance)
			FOR _month IN ([1], [2], [3], [4])  
		) AS pivot_table) balance_stats

-- running customer balance column that includes the impact each transaction
-- customer balance at the end of each month
-- minimum, average and maximum values of the running balance for each customer

SELECT
    customer_id,
    txn_date,
	txn_type,
	CASE
		WHEN txn_type = 'deposit' THEN txn_amount
		ELSE - txn_amount END AS impact,
    SUM(CASE
			WHEN txn_type = 'deposit' THEN txn_amount
			ELSE - txn_amount END) OVER (PARTITION BY customer_id ORDER BY txn_date) AS running_balance
FROM
    customer_transactions;

WITH running_account AS 
	(SELECT
		customer_id,
		txn_date,
		SUM(CASE
				WHEN txn_type = 'deposit' THEN txn_amount
				ELSE - txn_amount END) OVER (PARTITION BY customer_id ORDER BY txn_date) AS running_balance
	FROM
		customer_transactions)
SELECT
	customer_id,
	DATEPART(MONTH, txn_date) AS _month,
	dbo.closing_balance ( customer_id , DATEPART(MONTH, txn_date)) AS closing_balance,
	
	(SELECT 
		MAX(running_balance)
	 FROM running_account
	 WHERE customer_transactions.customer_id = running_account.customer_id
	 AND DATEPART(MONTH, customer_transactions.txn_date) 
							= DATEPART(MONTH, running_account.txn_date) 
	 )AS max_running_balance_in_month,

	 (SELECT 
		MIN(running_balance)
	 FROM running_account
	 WHERE customer_transactions.customer_id = running_account.customer_id
	 AND DATEPART(MONTH, customer_transactions.txn_date) 
							= DATEPART(MONTH, running_account.txn_date) 
	 )AS min_running_balance_in_month,

	 (SELECT 
		AVG(running_balance)
	 FROM running_account
	 WHERE customer_transactions.customer_id = running_account.customer_id
	 AND DATEPART(MONTH, customer_transactions.txn_date) 
							= DATEPART(MONTH, running_account.txn_date) 
	 )AS avg_running_balance_in_month

FROM customer_transactions 
GROUP BY customer_id, DATEPART(MONTH, txn_date)
ORDER BY customer_id, _month
