WITH cohort_sizes AS (
    SELECT 
        c.first_cohort_month,
        DATE_TRUNC('month', t.tran_date) AS activity_month,
        COUNT(DISTINCT t.msno) AS retained_users
    FROM clean_transactions t
    JOIN (
        SELECT msno, DATE_TRUNC('month', MIN(tran_date)) AS first_cohort_month
        FROM clean_transactions
        GROUP BY msno
    ) c ON t.msno = c.msno
    GROUP BY 1, 2
),
base_cohort AS (
    SELECT 
        first_cohort_month,
        retained_users AS initial_users
    FROM cohort_sizes
    WHERE first_cohort_month = activity_month
)
SELECT 
    s.first_cohort_month,
    s.activity_month,
    s.retained_users,
    b.initial_users,
    ROUND(CAST(s.retained_users AS DOUBLE) * 100.0 / b.initial_users, 2) AS retention_rate_pct
FROM cohort_sizes s
JOIN base_cohort b ON s.first_cohort_month = b.first_cohort_month
ORDER BY 1, 2;


------ CREATE CUSTOMER BEHAVIOR TABLE ------
CREATE OR REPLACE TABLE customer_features AS
SELECT 
    msno,
    COUNT(DISTINCT tran_date) AS total_transactions,
    SUM(actual_amount_paid) AS total_spent,
    AVG(payment_plan_days) AS avg_plan_days,
    AVG(CASE WHEN is_auto_renew = 1 THEN 1.0 ELSE 0.0 END) AS auto_renew_ratio,
    MAX(tran_date) AS last_tran_date,
    MIN(tran_date) AS first_tran_date
FROM clean_transactions
GROUP BY msno;


-----Frequency Distribution-----
SELECT 
    total_transactions,
    COUNT(msno) AS customer_count,
    ROUND(COUNT(msno) * 100.0 / SUM(COUNT(msno)) OVER(), 2) AS percentage
FROM customer_features
GROUP BY total_transactions
ORDER BY total_transactions ASC;



-- Check the Frequency Percentiles to find the mathematical breakpoint.
SELECT 
    quantile_cont(frequency, 0.50) AS p50_median,
    quantile_cont(frequency, 0.80) AS p80_top_20_percent,
    quantile_cont(frequency, 0.90) AS p90_top_10_percent,
    quantile_cont(frequency, 0.95) AS p95_top_5_percent
FROM (
    SELECT msno, COUNT(DISTINCT tran_date) AS frequency 
    FROM clean_transactions 
    GROUP BY msno
);

----- CUSTOMER SEGMENT -----
CREATE OR REPLACE TEMP TABLE user_segments AS
WITH base_rfm AS (
    SELECT 
        msno,
        MAX(tran_date) AS last_tran_date,
        COUNT(DISTINCT tran_date) AS frequency,
        SUM(actual_amount_paid) AS monetary
    FROM clean_transactions
    GROUP BY msno
)
SELECT 
    msno,
    frequency,
    monetary,
    CASE 
        WHEN frequency >= 19 THEN 'Loyal / VIP (Top 20%)'
        WHEN frequency >= 5 THEN 'Potential / Regular'
        ELSE 'Normal / At-Risk'
    END AS customer_segment
FROM base_rfm;