-- models/marts/mart_commercial_kpis.sql
--
-- Aggregated commercial KPIs, matching the computed values in notebook 02:
--   - kpis_commercial (cell 32): net_revenue, gross_profit, margin_pct, aov,
--     avg_discount_pct, return_rate
--   - disc_impact (cell 35): orders + margin by disc_tier
--
-- Grain: year_month × year_quarter × country × channel × category × brand
-- This grain lets Tableau slice by any combination without re-aggregating.

WITH fct AS (
    SELECT * FROM {{ ref('fct_orders') }}
)

SELECT
    -- ── Time ──────────────────────────────────────────────────────────────
    year,
    quarter,
    month,
    year_month,
    year_quarter,
    fiscal_year,
    fiscal_quarter,

    -- ── Dimensions ────────────────────────────────────────────────────────
    country,
    channel,
    category,
    sub_category,
    brand,
    disc_tier,

    -- ── Volume ────────────────────────────────────────────────────────────
    COUNT(DISTINCT order_id)                            AS total_orders,
    SUM(quantity)                                       AS total_units,
    COUNT(DISTINCT customer_id)                         AS unique_customers,

    -- ── Revenue kpis ────────────────
    ROUND(SUM(gross_revenue), 2)                        AS gross_revenue,
    ROUND(SUM(discount_amount), 2)                      AS total_discount,
    ROUND(SUM(net_revenue), 2)                          AS net_revenue,
    ROUND(AVG(net_revenue), 2)                          AS avg_order_value,     

    -- ── Profitability kpis ──────────────────────────────────────────────────────
    ROUND(SUM(cogs), 2)                                 AS total_cogs,
    ROUND(SUM(gross_profit), 2)                         AS gross_profit,
    ROUND(
        SUM(gross_profit) / NULLIF(SUM(net_revenue), 0), -- nullif net_revenue is 0 to avoid division by zero
        4
    )                                                   AS blended_margin_pct,

    -- ── Discounting kpis ────────────────────────────────────────────────────────
    ROUND(AVG(discount), 4)                             AS avg_discount_pct,    -- "avg_discount_pct" in notebook
    ROUND(
        SUM(discount_amount) / NULLIF(SUM(gross_revenue), 0),
        4
    )                                                   AS discount_share_of_gross,

    -- ── Returns kpis ────────────────────
    SUM(is_return)                                      AS total_returns,
    ROUND(
        SUM(is_return)::NUMERIC / NULLIF(COUNT(*), 0),
        4
    )                                                   AS return_rate

FROM fct
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13 -- Group by 
