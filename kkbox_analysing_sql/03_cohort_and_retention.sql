WITH user_cohorts AS (
    SELECT 
        msno, 
        DATE_TRUNC('month', MIN(tran_date)) AS cohort_month
    FROM clean_transactions
    GROUP BY msno
),
segment_activity AS (
    SELECT 
        s.customer_segment,
        c.cohort_month,
        DATE_TRUNC('month', t.tran_date) AS activity_month,
        COUNT(DISTINCT t.msno) AS active_users
    FROM clean_transactions t
    JOIN user_cohorts c ON t.msno = c.msno
    JOIN user_segments s ON t.msno = s.msno -- Lấy tag từ bảng đã tạo
    GROUP BY 1, 2, 3
),
base_size AS (
    SELECT 
        customer_segment,
        cohort_month,
        active_users AS initial_users
    FROM segment_activity
    WHERE cohort_month = activity_month
)
SELECT 
    a.customer_segment,
    a.cohort_month,
    a.activity_month,
    a.active_users,
    b.initial_users,
    ROUND(CAST(a.active_users AS DOUBLE) * 100.0 / b.initial_users, 2) AS retention_rate_pct
FROM segment_activity a
JOIN base_size b 
  ON a.customer_segment = b.customer_segment 
  AND a.cohort_month = b.cohort_month
ORDER BY a.customer_segment, a.cohort_month, a.activity_month;

-----
WITH user_behavior AS (
    SELECT 
        msno,
        COUNT(DISTINCT tran_date) AS total_freq,
        MAX(tran_date) - MIN(tran_date) AS lifespan_days
    FROM clean_transactions
    GROUP BY msno
),
retention_by_freq AS (
    SELECT 
        total_freq,
        COUNT(msno) AS total_users,
        SUM(CASE WHEN lifespan_days >= 90 THEN 1 ELSE 0 END) AS retained_users
    FROM user_behavior
    GROUP BY total_freq
)
SELECT 
    total_freq,
    total_users,
    ROUND(CAST(retained_users AS DOUBLE) * 100.0 / total_users, 2) AS retention_rate_at_90days
FROM retention_by_freq
WHERE total_freq <= 20 
ORDER BY total_freq;