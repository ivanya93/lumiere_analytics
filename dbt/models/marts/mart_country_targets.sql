-- models/marts/mart_country_targets.sql

-- Actual vs target revenue by country and month
-- Grain: country x year_month

WITH actuals AS(
    SELECT
        country,
        year_month,
        year,
        SUM(net_revenue)                                AS actual_revenue,
        COUNT(DISTINCT order_id)                        AS orders,
        COUNT(DISTINCT customer_id)                     AS customers
    FROM {{ ref('fct_orders')}}
    GROUP BY country, year_month, year
),

targets AS(
    SELECT * 
    FROM {{ ref('stg_sales_targets')}}
),

joined AS(
    SELECT 
        a.country,
        a.year_month,
        a.year,
        a.actual_revenue,
        a.orders,
        a.customers,
        t.target_revenue,
        -- Revenue vs Target 
        ROUND(a.actual_revenue - t.target_revenue, 2)   AS target_achievement_pct

    FROM actuals AS a
    LEFT JOIN targets AS t
        ON a.country = t.country 
        AND a.year_month = t.year_month
),

-- YoY growth per country 
yoy AS (
    SELECT
        country,
        MAX(CASE WHEN year = 2024 THEN actual_revenue END) AS rev_2024,
        MAX(CASE WHEN year = 2025 THEN actual_revenue END) AS rev_2025
    FROM joined 
    GROUP BY country
)

SELECT 
    j.*,
    y.rev_2024,
    y.rev_2025,
    ROUND(
        (y.rev_2025 - y.rev_2024) / NULLIF(y.rev_2024, 0) * 100, 2) AS yoy_growth_pct
    FROM joined AS j
    LEFT JOIN yoy AS y USING (country)
    