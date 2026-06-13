-- DCAT: The standard metadata language
-- Lumiere: Distribution: Pointing to structured parqued data in the data lake, with a clear lineage back to source systems.

-- models/intermediate/int_customer_rfm.sql
--
-- Reproduces the full RFM + CLV + customer_analytics logic from notebook 02:
--
--   → groupby aggregation (Recency, Frequency, Monetary)
--   → quintile scoring for R, F, M  (ntile(5) - ntile assigns quintiles with 1=lowest, 5=highest)
--   → RFM Score = R + F + M
--   → segment() function thresholds:
--                >= 13 → Champions
--                >= 10 → Loyal Customers
--                >= 7  → Potential Loyalists
--                >= 4  → Needs Attention
--                else  → At Risk
--   Cell 25  → CLV_Estimate = Revenue * 1.5
--   Cell 26  → customer_analytics = rfm merged with clv
--
-- Grain: one row per customer_id.
-- Snapshot date: 2026-01-01 (used for Recency calculation).
-- Materialised as: table

WITH orders AS (
    SELECT * FROM {{ ref('int_orders_enriched') }}
),

rfm_base AS (
    -- Mirrors notebook 02 cell 18 groupby aggregation
    SELECT
        customer_id,

        -- Recency: days since most recent order (SNAPSHOT_DATE = 2026-01-01)
        DATE('2026-01-01') - MAX(order_date)            AS recency,

        -- Frequency: unique orders per customer
        COUNT(DISTINCT order_id)                        AS frequency,

        -- Monetary: total net revenue per customer
        ROUND(SUM(net_revenue), 2)                      AS monetary,

        -- Extra aggregations used in customer_analytics / CLV
        MIN(order_date)                                 AS first_order_date,
        MAX(order_date)                                 AS last_order_date,
        COUNT(DISTINCT order_id)                        AS orders,       -- alias for CLV join
        ROUND(SUM(net_revenue), 2)                      AS revenue       -- alias for CLV join

    FROM orders
    GROUP BY customer_id
),

rfm_scored AS (
    SELECT *,
        -- R score: lower recency (more recent) = higher score → labels [5,4,3,2,1]
        6 - ntile(5) OVER (order by recency)            AS R,

        -- F score: higher frequency = higher score → labels [1,2,3,4,5]
        ntile(5) OVER (order by frequency)              AS F,

        -- M score: higher monetary = higher score → labels [1,2,3,4,5]
        ntile(5) OVER (order by monetary)               AS M

    FROM rfm_base
),

rfm_segmented AS (
    -- Mirrors notebook 02 cells 20 + 22
    SELECT *,
        R + F + M                                       AS rfm_score,

        -- segment() function thresholds — exact match to notebook 02
        CASE
            WHEN R + F + M >= 13 THEN 'Champions'
            WHEN R + F + M >= 10 THEN 'Loyal Customers'
            WHEN R + F + M >= 7  THEN 'Potential Loyalists'
            WHEN R + F + M >= 4  THEN 'Needs Attention'
            ELSE                      'At Risk'
        END                                             AS segment

    FROM rfm_scored
),

clv AS (
    -- Mirrors notebook 02 cell 25
    -- CLV_Estimate = Revenue * 1.5 (retention factor of 1.5 as in notebook)
    SELECT
        customer_id,
        revenue,
        orders,
        ROUND(revenue * 1.5, 2)                         AS clv_estimate

    FROM rfm_base
),

-- customer_analytics: mirrors notebook 02 cell 26 by joining RFM segments with CLV estimates
customer_analytics AS (
    SELECT
        r.customer_id,
        r.recency,
        r.frequency,
        r.monetary,
        r.first_order_date,
        r.last_order_date,
        r.r,
        r.f,
        r.m,
        r.rfm_score,
        r.segment,
        c.revenue,
        c.orders,
        c.clv_estimate

    FROM rfm_segmented r
    LEFT JOIN clv c USING (customer_id)
)

SELECT * FROM customer_analytics
