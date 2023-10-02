
-- Data analysis
-- Customer Journey
SELECT * 
FROM subscriptions s
JOIN plans p
ON s.plan_id = p.plan_id

-- How many customers has Foodie-Fi ever had?
SELECT COUNT(DISTINCT customer_id) AS num_customers
FROM subscriptions

-- What is the monthly distribution of trial plan start_date values for our dataset 
-- use the start of the month as the group by value
SELECT 
	FORMAT(DATEADD(MONTH, DATEDIFF(MONTH, 0, start_date),0),'dd/MM/yyy') AS month,
	COUNT(plan_id) AS num_trial
FROM subscriptions
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, start_date),0)
ORDER BY DATEADD(MONTH, DATEDIFF(MONTH, 0, start_date),0) ASC

-- What plan start_date values occur after the year 2020 for our dataset?
-- Show the breakdown by count of events for each plan_name
SELECT 
	p.plan_name,
	COUNT(s.plan_id) AS num_plans
FROM subscriptions s
JOIN plans p
ON s.plan_id = p.plan_id
WHERE DATEPART(YEAR, start_date) > 2020
GROUP BY p.plan_name

-- What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
SELECT 
	COUNT(DISTINCT customer_id) AS num_customers,
	(SELECT 
		COUNT(DISTINCT customer_id) 
	FROM subscriptions 
	WHERE plan_id = 4) AS num_churn,
	CAST(
	(SELECT 
		COUNT(DISTINCT customer_id) 
	FROM subscriptions 
	WHERE plan_id = 4) * 100.00/ COUNT(DISTINCT customer_id) AS DECIMAL (5,2)) AS percent_churn
FROM subscriptions

-- How many customers have churned straight after their initial free trial 
-- what percentage is this?
SELECT 
	COUNT(*) AS num_customers,
	CAST((COUNT(*) * 100.0) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions) AS DECIMAL (5,0))
			AS Percentage
FROM subscriptions start
JOIN 
	(SELECT 
		customer_id, 
		start_date AS churn_date
	FROM subscriptions
	WHERE plan_id = 4) churn
ON start.customer_id = churn .customer_id
WHERE start.plan_id = 0 
AND DATEDIFF(DAY, start.start_date, churn.churn_date) = 7

-- What is the number and percentage of customer plans after their initial free trial?
SELECT 
	COUNT(*) AS num_customers,
	CAST((COUNT(*) * 100.0) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions) AS DECIMAL (5,2)) AS percentage
FROM subscriptions start
JOIN 
	(SELECT 
		customer_id,
		start_date
	FROM subscriptions
	WHERE plan_id = 0) trial_end
ON start.customer_id = trial_end.customer_id
WHERE DATEDIFF(DAY, trial_end.start_date, start.start_date) = 7
AND start.plan_id <> 4

-- What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

GO
CREATE FUNCTION actual_current_plan
	(
	 @current_date DATE,
	 @plan_id INT,
	 @previous_date DATE,
	 @previous_plan INT
	)
RETURNS INT
AS
BEGIN
	DECLARE @current_plan INT
	SET @current_plan = 
	(
		CASE	
			WHEN @previous_plan = 0
			THEN CASE
					WHEN DATEADD(DAY, 7, @previous_date) >= @current_date
					THEN @previous_plan
					ELSE @plan_id END
			WHEN @previous_plan = 1 OR @previous_plan = 2
			THEN CASE
					WHEN DATEADD(MONTH, 1, @previous_date) >= @current_date
					THEN @previous_plan
					ELSE @plan_id END 
			WHEN @previous_plan = 3
			THEN CASE
					WHEN DATEADD(YEAR, 1, @previous_date) >= @current_date
					THEN @previous_plan
					ELSE @plan_id END 
		END 
	)
	RETURN @current_plan
END
GO

SELECT 
	current_plan,
	COUNT(*) AS plan_num,
	CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS plan_percent
FROM 
	(SELECT 
		customer_id,
		CASE	
			WHEN plan_id = 0 OR plan_id = 3 THEN plan_id
			WHEN plan_id = 4 THEN dbo.actual_current_plan('2020-12-31',plan_id, previous_date, previous_plan)
			ELSE 
				CASE 
					WHEN previous_plan < plan_id THEN plan_id
					ELSE dbo.actual_current_plan('2020-12-31',plan_id, previous_date, previous_plan)
				END 	
		END AS current_plan
	FROM 
		(SELECT
			customer_id,
			plan_id,
			start_date,
			LAG(plan_id) OVER(PARTITION BY customer_id ORDER BY start_date ASC) AS previous_plan,
			LAG(start_date) OVER(PARTITION BY customer_id ORDER BY start_date ASC) AS previous_date,
			ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date DESC) AS rank_date
		FROM subscriptions s1
		WHERE start_date <= '2020-12-31') AS two_lastest_plan
	WHERE rank_date = 1) AS actual_plan
GROUP BY current_plan

-- How many customers have upgraded to an annual plan in 2020?
SELECT 
	COUNT(DISTINCT customer_id) AS num_cus
FROM subscriptions
WHERE plan_id = 3
AND start_date BETWEEN '2020-01-01' AND '2021-01-01'

-- How many days on average does it take for a customer to an annual plan from 
-- the day they join Foodie-Fi?
SELECT AVG(day_between) AS avg_days_to_annual
FROM 
(SELECT 
	DATEDIFF(DAY, first_join.start_date, annual_plan.start_date) AS day_between
FROM subscriptions first_join
JOIN subscriptions annual_plan
ON first_join.customer_id = annual_plan.customer_id
WHERE first_join.plan_id = 0
AND annual_plan.plan_id = 3) AS change_to_annual

-- Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH change_to_annual AS
	(SELECT 
			first_join.customer_id,
			DATEDIFF(DAY, first_join.start_date, annual_plan.start_date) AS day_between
	 FROM subscriptions first_join
		JOIN subscriptions annual_plan
		ON first_join.customer_id = annual_plan.customer_id
	WHERE first_join.plan_id = 0
		AND annual_plan.plan_id = 3),
	avg_period AS
	(SELECT
		customer_id,
		CASE
			WHEN day_between BETWEEN 0 AND 30 THEN 'O-30 days'
			WHEN day_between BETWEEN 31 AND 60 THEN '31-60 days'
			WHEN day_between BETWEEN 61 AND 90 THEN '61-90 days'
		ELSE 'More than 90 days'
	    END AS break_period
	 FROM change_to_annual)
SELECT 
	break_period,
	AVG(day_between) AS avg_day_between,
	COUNT (*) AS num_cus
FROM avg_period a
JOIN change_to_annual c
ON a.customer_id = c.customer_id
GROUP BY break_period
ORDER BY num_cus DESC;

-- How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
SELECT
	COUNT(DISTINCT customer_id) AS num_cus_downgraded
FROM 
	(SELECT 
		customer_id,
		plan_id,
		start_date,
		LAG(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS previous_plan
	FROM subscriptions
	WHERE YEAR(start_date) = 2020) AS plan_change
WHERE 
	plan_id = 2 AND previous_plan = 1
