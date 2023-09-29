 -- Data Cleaning Steps
 DROP TABLE IF EXISTS clean_weekly_sales;
 CREATE TABLE clean_weekly_sales
 (
	week_date DATE,
	week_number INT, 
	month_number INT, 
	calendar_year INT,
	region VARCHAR(13),
	platforms VARCHAR(10),
	segment VARCHAR(10),
	age_band VARCHAR(15),
	demographic VARCHAR(10),
	customer_type VARCHAR(10),
	transactions INTEGER,
    sales BIGINT,
	avg_transaction DECIMAL(5,2)
 )

INSERT INTO clean_weekly_sales
SELECT	
	CONVERT(DATE, week_date, 3),
	DATEPART(DAY, DATEDIFF(DAY, 0, CONVERT(DATE, week_date, 3))/7 * 7)/7 + 1,
	DATEPART(MONTH, CONVERT(DATE, week_date, 3)),
	DATEPART(YEAR, CONVERT(DATE, week_date, 3)),
	region,
	platforms,
	CASE 
		WHEN segment = 'null' THEN 'unknown'
		ELSE segment END,
	CASE 
		WHEN segment = 'null' THEN 'unknown'
		WHEN RIGHT(segment, 1) = '1' THEN 'Young Adults'
		WHEN RIGHT(segment, 1) = '2' THEN 'Middle Aged'
		ELSE 'Retirees' END,
	CASE 
		WHEN segment = 'null' THEN 'unknown'
		WHEN LEFT(segment, 1) = 'C' THEN 'Couples'
		ELSE 'Families' END,
	customer_type,
	transactions,
	sales,
	ROUND(sales/transactions, 2)
FROM weekly_sales

-- Data Exploration
-- How many total transactions were there for each year in the dataset?

SELECT
	calendar_year, 
	SUM(transactions) AS total_transactions
FROM clean_weekly_sales
GROUP BY calendar_year
-- What is the total sales for each region for each month?

SELECT 
	region,
	month_number,
	SUM(sales) AS total_sales
FROM clean_weekly_sales
GROUP BY region, month_number
ORDER BY region, month_number
-- What is the total count of transactions for each platform

SELECT 
	platforms,
	SUM(transactions) AS total
FROM clean_weekly_sales
GROUP BY platforms
-- What is the percentage of sales for Retail vs Shopify for each month?

SELECT
	calendar_year, 
	month_number,
	(SELECT SUM(sales) FROM clean_weekly_sales  c1
			WHERE platforms = 'Retail'
			AND c1.calendar_year = c3.calendar_year
			AND c1.month_number = c3.month_number) * 1.00/
	(SELECT SUM(sales) FROM clean_weekly_sales c2 
			WHERE platforms = 'Shopify'
			AND c2.calendar_year = c3.calendar_year
			AND c2.month_number = c3.month_number) AS Retail_vs_Shopify
FROM clean_weekly_sales c3
GROUP BY calendar_year, month_number
ORDER BY calendar_year, month_number
-- What is the percentage of sales by demographic for each year in the dataset?

SELECT
	calendar_year,
	demographic,
	SUM(sales) AS total_sales,
	(SELECT SUM(sales) 
		FROM clean_weekly_sales c1
		WHERE c1.calendar_year = c2.calendar_year) AS total_of_year,
	ROUND(SUM(sales) * 100.00
		/ (SELECT SUM(sales) 
		FROM clean_weekly_sales c1
		WHERE c1.calendar_year = c2.calendar_year) ,2) AS percent_by_demographic
FROM clean_weekly_sales c2
GROUP BY calendar_year, demographic
ORDER BY calendar_year, demographic
-- Which age_band and demographic values contribute the most to Retail sales?

SELECT 
	age_band, 
	demographic,
	SUM(sales) AS sales
FROM clean_weekly_sales
WHERE platforms = 'Retail'
AND age_band <> 'unknown'
GROUP BY age_band, demographic
ORDER BY sales DESC
-- Can we use the avg_transaction column to find the average transaction size 
-- for each year for Retail vs Shopify? If not - how would you calculate it instead?

SELECT
	calendar_year,
	platforms,
	AVG(transaction_size) AS avg_transaction_size
FROM 
	(SELECT 
		calendar_year,
		platforms,
		sales / transactions AS transaction_size
	FROM clean_weekly_sales) AS trans_size
GROUP BY calendar_year, platforms
ORDER BY calendar_year, platforms

-- Before and after analysis
-- Taking the week_date value of 2020-06-15 as the baseline week where the Data Mart 
-- sustainable packaging changes came into effect.

-- What is the total sales for the 4 weeks before and after 2020-06-15?

SELECT 
	CASE
		WHEN week_date < '2020-06-15' THEN 'Before'
		WHEN week_date >='2020-06-15' THEN 'After'
	END AS period,
	SUM(sales) AS total_sales
FROM clean_weekly_sales
WHERE week_date BETWEEN DATEADD(WEEK, -4, '2020-06-15') AND DATEADD(WEEK, 4, '2020-06-15')
GROUP BY 
	CASE
		WHEN week_date < '2020-06-15' THEN 'Before'
		WHEN week_date >='2020-06-15' THEN 'After'
	END
-- What is the growth or reduction rate in actual values and percentage of sales?

SELECT
	MAX(CASE WHEN period = 'After' THEN total_sales END) 
	- MAX(CASE WHEN period = 'Before' THEN total_sales END) AS sales_difference,
	((MAX(CASE WHEN period = 'After' THEN total_sales END) - MAX(CASE WHEN period = 'Before' THEN total_sales END))*100.00 
	/ NULLIF(MAX(CASE WHEN period = 'Before' THEN total_sales END), 0))  AS sales_percentage_change
FROM
(SELECT 
	CASE
		WHEN week_date < '2020-06-15' THEN 'Before'
		WHEN week_date >='2020-06-15' THEN 'After'
	END AS period,
	SUM(sales) AS total_sales
FROM clean_weekly_sales
WHERE week_date BETWEEN DATEADD(WEEK, -4, '2020-06-15') AND DATEADD(WEEK, 4, '2020-06-15')
GROUP BY 
	CASE
		WHEN week_date < '2020-06-15' THEN 'Before'
		WHEN week_date >='2020-06-15' THEN 'After'
	END) AS sales_per_period

-- What about the entire 12 weeks before and after?
SELECT 
	CASE
		WHEN week_date < '2020-06-15' THEN 'Before'
		WHEN week_date >='2020-06-15' THEN 'After'
	END AS period,
	SUM(sales) AS total_sales
FROM clean_weekly_sales
WHERE week_date BETWEEN DATEADD(WEEK, -12, '2020-06-15') AND DATEADD(WEEK, 12, '2020-06-15')
GROUP BY 
	CASE
		WHEN week_date < '2020-06-15' THEN 'Before'
		WHEN week_date >='2020-06-15' THEN 'After'
	END

SELECT
	MAX(CASE WHEN period = 'After' THEN total_sales END) 
	- MAX(CASE WHEN period = 'Before' THEN total_sales END) AS sales_difference,
	((MAX(CASE WHEN period = 'After' THEN total_sales END) - MAX(CASE WHEN period = 'Before' THEN total_sales END))*100.00 
	/ NULLIF(MAX(CASE WHEN period = 'Before' THEN total_sales END), 0))  AS sales_percentage_change
FROM
(SELECT 
	CASE
		WHEN week_date < '2020-06-15' THEN 'Before'
		WHEN week_date >='2020-06-15' THEN 'After'
	END AS period,
	SUM(sales) AS total_sales
FROM clean_weekly_sales
WHERE week_date BETWEEN DATEADD(WEEK, -12, '2020-06-15') AND DATEADD(WEEK, 12, '2020-06-15')
GROUP BY 
	CASE
		WHEN week_date < '2020-06-15' THEN 'Before'
		WHEN week_date >='2020-06-15' THEN 'After'
	END) AS sales_per_period
-- How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?

CREATE FUNCTION CalculateBeforeSales
	(@interval INT,
	@changing_date VARCHAR(10),
	@year INT)
RETURNS  BIGINT
AS
BEGIN
	DECLARE @sale_before BIGINT 
	SELECT @sale_before = 
		SUM(sales) 
		FROM clean_weekly_sales
		WHERE week_date >= DATEADD(WEEK, - @interval, CAST (CAST(@year AS VARCHAR(MAX)) + @changing_date  AS DATE)) 
		AND week_date < CAST (CAST(@year AS VARCHAR(MAX)) + @changing_date AS DATE)
	RETURN @sale_before
END;

CREATE FUNCTION CalculateAfterSales
	(@interval INT,
	@changing_date VARCHAR(10),
	@year INT)
RETURNS  BIGINT
AS
BEGIN
	DECLARE @sale_after BIGINT 
	SELECT @sale_after = 
		SUM(sales) 
		FROM clean_weekly_sales
		WHERE week_date >= CAST (CAST(@year AS VARCHAR(MAX)) + @changing_date AS DATE)
		AND week_date <= DATEADD(WEEK, @interval, CAST (CAST(@year AS VARCHAR(MAX)) + @changing_date  AS DATE)) 
	RETURN @sale_after
END;

SELECT 
	calendar_year,
	(SELECT dbo.CalculateBeforeSales(4,'-06-15', calendar_year)) AS before,
	(SELECT dbo.CalculateAfterSales(4,'-06-15', calendar_year)) AS after
FROM clean_weekly_sales 
GROUP BY calendar_year
ORDER BY calendar_year
