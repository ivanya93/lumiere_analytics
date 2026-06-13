-- model/marts/mart_customer_kpis.sql

-- one row per customer with all RFM + CLV attributes from int_customer_rfm
-- joined with customer master data from stg_customers

-- Grain: one row per customer_id

WITH rfm AS(
    SELECT * FROM {{ ref('int_customer_rfm')}}
),

customers AS(
    SELECT * FROM {{ref('stg_customers')}}
)

SELECT
    c.customer_id,
    c.customer_name,
    c.segment                             AS customer_segment,
    c.country,
    c.city,
    c.acquisition_date,
    c.acquisition_channel,
    ------ RFM Scores (from int_customer_rfm)---------------
    r.recency,                           -- days since last order
    r.frequency,                         -- unique order count
    r.monetary,                          -- total net revenue
    r.r,                                 -- recency quintile score 1-5
    r.f,                                 -- frequency quintile score 1-5
    r.m,                                 -- monetary quintile score 1-5
    r.rfm_score,                         -- R + F + M (3-15)
    -- Segment labels (champions, loyal cust., potential loyalists, at risk etc)
    r.segment                            AS rfm_segment,
    -- CLV --------------------------------------------------
    r.revenue                            AS total_revenue,
    r.orders                             AS total_orders,
    r.clv_estimate,
    -- Activity dates ---------------------------------------
    r.first_order_date,
    r.last_order_date,
    -- Customer tenure: days since acquisition --------------
    DATE('2026-01-01') - c.acquisition_date AS tenure_days

    FROM customers AS c 
    LEFT JOIN rfm AS r USING (customer_id)