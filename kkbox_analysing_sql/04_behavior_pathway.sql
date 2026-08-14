WITH user_txn_sequence AS (
    SELECT 
        t.msno,
        ROW_NUMBER() OVER (PARTITION BY t.msno ORDER BY t.tran_date ASC, t.expire_date ASC) AS txn_sequence,
        t.actual_amount_paid
    FROM clean_transactions t
    JOIN user_segments s ON t.msno = s.msno
    WHERE s.customer_segment = 'Normal / At-Risk'
),
pivoted_user_journey AS (
    SELECT 
        msno,
        MAX(CASE WHEN txn_sequence = 1 THEN actual_amount_paid END) as txn_1,
        MAX(CASE WHEN txn_sequence = 2 THEN actual_amount_paid END) as txn_2,
        MAX(CASE WHEN txn_sequence = 3 THEN actual_amount_paid END) as txn_3
    FROM user_txn_sequence
    GROUP BY msno
),
classified_paths AS (
    SELECT 
        CASE 
            WHEN txn_1 = 0 AND txn_2 = 0 AND txn_3 = 0 THEN 'Branch A1: 1st(0) -> 2nd(0) -> 3rd(0)'
            WHEN txn_1 = 0 AND txn_2 = 0 AND txn_3 > 0 THEN 'Branch A2: 1st(0) -> 2nd(0) -> 3rd(>0)'
            WHEN txn_1 = 0 AND txn_2 = 0 AND txn_3 IS NULL THEN 'Branch A3: 1st(0) -> 2nd(0) -> Churn (No 3rd)'
            
            WHEN txn_1 = 0 AND txn_2 > 0 AND txn_3 > 0 THEN 'Branch B1: 1st(0) -> 2nd(>0) -> 3rd(>0)'
            WHEN txn_1 = 0 AND txn_2 > 0 AND txn_3 = 0 THEN 'Branch B2: 1st(0) -> 2nd(>0) -> 3rd(0)'
            WHEN txn_1 = 0 AND txn_2 > 0 AND txn_3 IS NULL THEN 'Branch B3: 1st(0) -> 2nd(>0) -> Churn (No 3rd)'
            
            WHEN txn_1 > 0 AND txn_2 > 0 AND txn_3 > 0 THEN 'Branch C1: 1st(>0) -> 2nd(>0) -> 3rd(>0)'
            WHEN txn_1 > 0 AND txn_2 > 0 AND txn_3 = 0 THEN 'Branch C2: 1st(>0) -> 2nd(>0) -> 3rd(0)'
            WHEN txn_1 > 0 AND txn_2 > 0 AND txn_3 IS NULL THEN 'Branch C3: 1st(>0) -> 2nd(>0) -> Churn (No 3rd)'
            
            WHEN txn_1 > 0 AND txn_2 = 0 AND txn_3 > 0 THEN 'Branch D1: 1st(>0) -> 2nd(0) -> 3rd(>0)'
            WHEN txn_1 > 0 AND txn_2 = 0 AND txn_3 IS NULL THEN 'Branch D2: 1st(>0) -> 2nd(0) -> Churn (No 3rd)'
            
            ELSE 'Other Pathways / Dropouts'
        END AS behavior_pathway,
        msno
    FROM pivoted_user_journey
)
SELECT 
    behavior_pathway,
    COUNT(DISTINCT msno) AS total_users,
    ROUND(100.0 * COUNT(DISTINCT msno) / (SELECT COUNT(DISTINCT msno) FROM pivoted_user_journey), 2) AS percentage_contribution
FROM classified_paths
GROUP BY 1
ORDER BY total_users DESC;

------
WITH user_txn_sequence AS (
    SELECT 
        t.msno,
        ROW_NUMBER() OVER (PARTITION BY t.msno ORDER BY t.tran_date ASC, t.expire_date ASC) AS txn_sequence,
        t.actual_amount_paid
    FROM clean_transactions t
    JOIN user_segments s ON t.msno = s.msno
    WHERE s.customer_segment = 'Normal / At-Risk'
),
pivoted_user_journey AS (
    SELECT 
        msno,
        MAX(CASE WHEN txn_sequence = 1 THEN actual_amount_paid END) as txn_1,
        MAX(CASE WHEN txn_sequence = 2 THEN actual_amount_paid END) as txn_2,
        MAX(CASE WHEN txn_sequence = 3 THEN actual_amount_paid END) as txn_3
    FROM user_txn_sequence
    GROUP BY msno
)
SELECT 
    'Branch A2: Started Free (0), Converted to Paid at Txn 3' AS user_group,
    COUNT(DISTINCT msno) AS user_count,
    ROUND(AVG(txn_3), 2) AS avg_price_paid_at_txn_3
FROM pivoted_user_journey
WHERE txn_1 = 0 AND txn_2 = 0 AND txn_3 > 0

UNION ALL

SELECT 
    'Branch C1: Paid from Txn 1, 2, and 3' AS user_group,
    COUNT(DISTINCT msno) AS user_count,
    ROUND(AVG(txn_3), 2) AS avg_price_paid_at_txn_3
FROM pivoted_user_journey
WHERE txn_1 > 0 AND txn_2 > 0 AND txn_3 > 0;