-- Data Exploration and Cleansing

-- update NULL values

UPDATE interest_map
SET interest_summary = NULL
WHERE CAST(interest_summary AS VARCHAR(MAX))=''

UPDATE interest_metrics
SET _month = CASE 
    WHEN _month = 'NULL' THEN NULL
    ELSE CAST(_month AS INTEGER)
END;

UPDATE interest_metrics
SET _year = CASE 
    WHEN _year = 'NULL' THEN NULL
    ELSE CAST(_year AS INTEGER)
END;

UPDATE interest_metrics
SET month_year = NULL
WHERE month_year = 'NULL';

UPDATE interest_metrics
SET interest_id = NULL
WHERE interest_id = 'NULL';

--Change the Data type of month_year column
UPDATE interest_metrics 
SET month_year = CONCAT ( '01-',month_year)
WHERE month_year IS NOT NULL;

UPDATE interest_metrics
SET month_year = CAST(CONVERT(DATE, month_year, 105) AS DATE);

-- What is count of records in the fresh_segments.interest_metrics for each month_year value 
-- sorted in chronological order (earliest to latest) with the null values appearing first?
SELECT 
	month_year,
	COUNT(*) AS counts
FROM interest_metrics
GROUP BY month_year
ORDER BY month_year ASC

-- NULL value
SELECT * FROM interest_metrics
WHERE interest_id IS NULL

-- -> The null value makes up for 8%, so that i decided to delete the row that have NULL values
DELETE FROM interest_metrics
WHERE month_year IS NULL OR interest_id IS NULL

-- How many interest_id values exist in the fresh_segments.interest_metrics table but not in the fresh_segments.interest_map table? 
-- What about the other way around?
SELECT COUNT(DISTINCT me.interest_id) AS counts
FROM interest_metrics me
LEFT JOIN interest_map ma
ON me.interest_id = ma.id
WHERE ma.id IS NULL;

SELECT COUNT(DISTINCT ma.id) AS counts
FROM interest_map ma
LEFT JOIN interest_metrics me
ON me.interest_id = ma.id
WHERE me.interest_id IS NULL;

-- -> All the interest_id exist in the interest_metrics are in the interest_map.
-- but there are 7 id from the interest_map are not in the interest_metrics

-- Duplication validation
SELECT 
	id,
	COUNT(*) AS counts
FROM interest_map
GROUP BY id
ORDER BY counts DESC;

-- -> There seems to have something wrong with the interest_map as the id is not unique value
-- so I will select all the value in the interest_map order by id to check what happen
SELECT * FROM interest_map
ORDER BY id;

-- -> There are duplicated rows, do that I need to delete them

SELECT DISTINCT 
	id, 
	CAST(interest_name AS varchar(max)) AS interest_name,
    CAST(interest_summary AS varchar(max)) AS interest_summary,
    created_at,
    last_modified
INTO clean_interest_map
FROM interest_map;
-- -> Therefore, I will use the clean_interest_map instead of interest_map

-- Value validation; check the relationship between created_at column in the clean_interest_map
-- and month_year from the interest_metrics. The month_year needs to be after the create_at value
-- -> Therefore, I will delete them from the table

-- Backup table
SELECT * 
INTO backup_interest_metrics
FROM interest_metrics

-- Delete invalid records
WITH validations AS
	(SELECT 
		interest_id,
		month_year, 
		created_at,
		CASE 
			WHEN month_year < CAST(created_at AS date) THEN 'Invalid'
			ELSE 'Valid'
		END AS time_validation
	FROM interest_metrics me
	JOIN clean_interest_map ma
	ON me.interest_id = ma.id)
DELETE FROM interest_metrics
WHERE EXISTS
	(SELECT *
	FROM validations v
	WHERE time_validation = 'Invalid'
	AND v.interest_id = interest_metrics.interest_id
	AND v.month_year = interest_metrics.month_year)

-- Interest Analysis

-- Which interests have been present in all month_year dates in our dataset?
SELECT
	me.interest_id,
	ma.interest_name
FROM interest_metrics me
JOIN clean_interest_map ma
ON me.interest_id = ma.id
GROUP BY me.interest_id, ma.interest_name
HAVING COUNT(DISTINCT month_year) 
		= (SELECT COUNT(DISTINCT month_year) FROM interest_metrics)

-- Using this same total_months measure - calculate the cumulative percentage of all records starting at 14 months 
	WITH get_total_months AS (
	  SELECT 
  		interest_id,
  		COUNT(DISTINCT month_year) AS total_months
	  FROM interest_metrics
	  WHERE interest_id IS NOT NULL
	  GROUP BY interest_id
	),
	get_cumalative_percentage AS (
	  SELECT
  		total_months,
  		COUNT(*) AS number_of_ids,
  		ROUND(100 * SUM(COUNT(*)) OVER (ORDER BY total_months DESC) / SUM(COUNT(*)) OVER(), 2) AS cumalative_percentage
	  FROM get_total_months
	  GROUP BY total_months
	)
SELECT
  total_months,
  number_of_ids,
  cumalative_percentage
FROM get_cumalative_percentage 
WHERE cumalative_percentage >= 90;

-- If we were to remove all interest_id values which are lower than the total_months value 
-- we found in the previous question - how many total data points would we be removing?
	WITH cte_total_months AS (
	  SELECT 
  		interest_id,
  		COUNT(DISTINCT month_year) AS total_months
	  FROM interest_metrics
	  GROUP BY interest_id
	  HAVING
  		COUNT(DISTINCT month_year) < 6
	)
-- Select results that are < 90%
SELECT
  COUNT(*) rows_removed
FROM interest_metrics
WHERE
  EXISTS(
  	SELECT
  		interest_id
  	FROM cte_total_months
  	WHERE
  		cte_total_months.interest_id = interest_metrics.interest_id
  );

