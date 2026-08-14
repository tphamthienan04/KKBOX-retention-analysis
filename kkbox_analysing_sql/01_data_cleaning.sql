-----FULL TRANSACTION TABLE -----
CREATE OR REPLACE TABLE transactions_full AS 
SELECT * FROM transactions
UNION 
SELECT * FROM transactions_v2;

SELECT COUNT(*)
FROM transactions_full

-----CHECKING DATA ------
-- MISSING VALUES (NULL) CHECK
SELECT 
    COUNT(*) - COUNT(msno) AS missing_msno,
    COUNT(*) - COUNT(payment_method_id) AS missing_payment_method_id,
    COUNT(*) - COUNT(payment_plan_days) AS missing_payment_plan_days,
    COUNT(*) - COUNT(plan_list_price) AS missing_plan_list_price,
    COUNT(*) - COUNT(actual_amount_paid) AS missing_actual_amount_paid,
    COUNT(*) - COUNT(is_auto_renew) AS missing_is_auto_renew,
    COUNT(*) - COUNT(transaction_date) AS missing_transaction_date,
    COUNT(*) - COUNT(membership_expire_date) AS missing_membership_expire_date,
    COUNT(*) - COUNT(is_cancel) AS missing_is_cancel
FROM transactions_full;

-- DUPLICATES CHECK
SELECT msno, transaction_date, COUNT(*) as duplicate_count
FROM transactions_full
GROUP BY msno, transaction_date
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

SELECT *
FROM transactions_full
WHERE msno = 'vf6eQrnFfiS9o1kB/gRUJ4iTUixS9tHNKizqQ/1vLDI=' 
  AND transaction_date = 20160229;



-- LOGICAL DATE ERROR CHECK
WITH parsed_dates AS (
    SELECT 
        CAST(strptime(CAST(transaction_date AS VARCHAR), '%Y%m%d') AS DATE) AS tran_date,
        CAST(strptime(CAST(membership_expire_date AS VARCHAR), '%Y%m%d') AS DATE) AS expire_date
    FROM transactions_full
    WHERE transaction_date IS NOT NULL AND membership_expire_date IS NOT NULL
)
SELECT COUNT(*) AS invalid_dates_count
FROM parsed_dates
WHERE expire_date < tran_date;

WITH parsed_dates AS (
    SELECT  
    	msno,
        CAST(strptime(CAST(transaction_date AS VARCHAR), '%Y%m%d') AS DATE) AS tran_date,
        CAST(strptime(CAST(membership_expire_date AS VARCHAR), '%Y%m%d') AS DATE) AS expire_date,
        plan_list_price,
        actual_amount_paid,
        payment_plan_days
    FROM transactions_full
    WHERE transaction_date IS NOT NULL AND membership_expire_date IS NOT NULL
)
SELECT 
    msno,
    tran_date,
    expire_date,
    plan_list_price,
    actual_amount_paid,
    payment_plan_days
FROM parsed_dates
WHERE expire_date < tran_date
LIMIT 10;

WITH parsed_dates AS (
    SELECT 
        CAST(strptime(CAST(transaction_date AS VARCHAR), '%Y%m%d') AS DATE) AS tran_date,
        CAST(strptime(CAST(membership_expire_date AS VARCHAR), '%Y%m%d') AS DATE) AS expire_date
    FROM transactions_full
    WHERE transaction_date IS NOT NULL 
      AND membership_expire_date IS NOT NULL
),
calculated_gaps AS (
    SELECT 
        CAST(tran_date - expire_date AS INTEGER) AS date_gap_days
    FROM parsed_dates
    WHERE expire_date < tran_date
)
SELECT 
    date_gap_days,
    COUNT(*) AS frequency
FROM calculated_gaps
GROUP BY date_gap_days
ORDER BY date_gap_days
;

-- PRICE & PLAN ANOMALIES CHECK
SELECT 
    SUM(CASE WHEN plan_list_price < 0 OR actual_amount_paid < 0 THEN 1 ELSE 0 END) AS negative_prices,
    
    SUM(CASE WHEN plan_list_price = 0 AND payment_plan_days > 31 THEN 1 ELSE 0 END) AS free_plan_anomaly,
    
    SUM(CASE WHEN actual_amount_paid > plan_list_price THEN 1 ELSE 0 END) AS paid_greater_than_list
FROM transactions_full;

SELECT 
    payment_plan_days,
    COUNT(*) AS count
FROM transactions_full
WHERE plan_list_price = 0 
  AND payment_plan_days > 31
GROUP BY payment_plan_days
ORDER BY payment_plan_days;

SELECT COUNT(*) AS total_group_a
FROM transactions_full
WHERE actual_amount_paid > plan_list_price 
  AND plan_list_price > 0;

SELECT 
    msno,
    plan_list_price,
    actual_amount_paid,
    payment_plan_days,
    is_auto_renew
FROM transactions_full
WHERE actual_amount_paid > plan_list_price 
  AND plan_list_price > 0

SELECT COUNT(*) AS total_group_b
FROM transactions_full
WHERE actual_amount_paid > plan_list_price 
  AND plan_list_price = 0;

----- CLEANING TABLE -----
CREATE OR REPLACE TABLE clean_transactions AS
WITH base_cleaned AS (
    SELECT 
        msno,
        payment_method_id,
        payment_plan_days,
        plan_list_price,
        actual_amount_paid,
        is_auto_renew,
        is_cancel,
        CAST(strptime(CAST(transaction_date AS VARCHAR), '%Y%m%d') AS DATE) AS tran_date,
        CAST(strptime(CAST(membership_expire_date AS VARCHAR), '%Y%m%d') AS DATE) AS expire_date
    FROM transactions_full
    WHERE msno IS NOT NULL 
      AND transaction_date IS NOT NULL 
      AND membership_expire_date IS NOT NULL
      AND plan_list_price >= 0 
      AND actual_amount_paid >= 0
      AND NOT (plan_list_price = 0 AND payment_plan_days > 60)
),
deduplicated_logs AS (
    SELECT 
        msno,
        payment_method_id,
        payment_plan_days,
        plan_list_price,
        actual_amount_paid,
        is_auto_renew,
        is_cancel,
        tran_date,
        expire_date,
        ROW_NUMBER() OVER (
    		PARTITION BY msno, tran_date 
    		ORDER BY 
        CASE 
            WHEN plan_list_price = 0 THEN ABS(CAST(expire_date - tran_date AS INTEGER) - 30) 
            ELSE ABS(CAST(expire_date - tran_date AS INTEGER) - payment_plan_days) 
        END ASC,
        expire_date DESC
) as rn
    FROM base_cleaned
)
SELECT DISTINCT
    msno,
    payment_method_id,
    payment_plan_days,
    plan_list_price,
    actual_amount_paid,
    is_auto_renew,
    is_cancel,
    tran_date,
    CASE 
        WHEN expire_date < tran_date AND payment_plan_days > 0 
        THEN tran_date + INTERVAL '1 day' * payment_plan_days
        ELSE expire_date
    END AS expire_date
FROM deduplicated_logs
WHERE rn = 1; 