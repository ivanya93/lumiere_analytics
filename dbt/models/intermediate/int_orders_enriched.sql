-- DCAT: The standard metadata language

-- Lumiere: Distribution: Pointing to structured parqued data in the data lake, with a clear lineage back to source systems.
-- models/intermediate/int_orders_enriched.sql
--
-- Reproduces the enrichment done in notebook 02, cell by cell:
--   - Merges product columns (mirrors the .merge() )
--   - Computes Gross Revenue, Discount Amount, Net Revenue, COGS, Gross Profit, Margin Pct  
--   - Adds date dimensions: Year, Quarter, Month, Week, Year-Month, Year Quarter, Fiscal Year, Fiscal Quarter  
--   - Adds Disc_Tier buckets  
--
-- Grain: one row per order_id.
-- Materialised as: table

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

products AS (
    SELECT * FROM {{ ref('stg_products') }}
),

joined AS (
    SELECT
        -- ── Keys ──────────────────────────────────────────────────────────
        o.order_id,
        o.customer_id,
        o.product_id,

        -- ── Dates ─────────────────────────────────────────────────────────
        o.order_date,
        o.ship_date,
        o.shipping_days,

        -- ── Dimensions ────────────────────────────────────────────────────
        o.country,
        o.channel,
        o.payment_method,

        -- ── Product attributes (from stg_products) ────────────────────────
        p.product_name,
        p.category,
        p.sub_category,
        p.brand,
        p.unit_cost,
        p.list_price,
        p.product_margin_pct,

        -- ── Order measures ────────────────────────────────────────────────
        o.quantity,
        o.unit_price,
        o.discount,
        o.shipping_cost,

        -- ── Revenue metrics (mirrors notebook 02 cells 10-11) ─────────────
        -- Gross Revenue = Unit Price * Quantity
        o.unit_price * o.quantity                               AS gross_revenue,

        -- Discount Amount = Gross Revenue * Discount
        (o.unit_price * o.quantity) * o.discount                AS discount_amount,

        -- Net Revenue = Gross Revenue - Discount Amount
        o.unit_price * o.quantity * (1 - o.discount)            AS net_revenue,

        -- COGS = Unit Cost * Quantity
        p.unit_cost * o.quantity                                AS cogs,

        -- Gross Profit = Net Revenue - COGS
        (o.unit_price * o.quantity * (1 - o.discount))
            - (p.unit_cost * o.quantity)                        AS gross_profit,

        -- Margin Pct = Gross Profit / Net Revenue
        CASE
            WHEN o.unit_price * o.quantity * (1 - o.discount) > 0
            THEN ROUND(
                ((o.unit_price * o.quantity * (1 - o.discount))
                    - (p.unit_cost * o.quantity))
                / (o.unit_price * o.quantity * (1 - o.discount)),
                4
            )
            ELSE 0
        END                                                     AS margin_pct,

        -- ── Date dimensions (mirrors notebook 02 cell 12) ─────────────────
        EXTRACT(year    from o.order_date)::integer             AS year,
        EXTRACT(quarter from o.order_date)::integer             AS quarter,
        EXTRACT(month   from o.order_date)::integer             AS month,
        to_char(o.order_date, 'Month')                          AS month_name,
        EXTRACT(week    from o.order_date)::integer             AS week,
        to_char(o.order_date, 'YYYY-MM')                        AS year_month,   -- matches "Year-Month" column in notebook
        to_char(o.order_date, 'YYYY')
            || '-Q' || EXTRACT(quarter from o.order_date)::text as year_quarter,

        -- Fiscal year: July-start (same logic used in notebook)
        CASE
            WHEN EXTRACT(month from o.order_date) >= 7
            THEN EXTRACT(year from o.order_date)::integer + 1
            ELSE EXTRACT(year from o.order_date)::integer
        END                                                     AS fiscal_year,

        -- Fiscal quarter (Q1 starts in July)
        ((EXTRACT(month from o.order_date)::integer - 7 + 12) % 12 / 3 + 1)
                                                                AS fiscal_quarter,

        -- ── Discount tier (mirrors notebook 02 cell 35 pd.cut bins) ───────
        CASE
            WHEN o.discount = 0              THEN 'No discount'
            WHEN o.discount <= 0.10          THEN '1-10%'
            WHEN o.discount <= 0.20          THEN '11-20%'
            WHEN o.discount <= 0.30          THEN '21-30%'
            ELSE                                  '31-50%'
        END                                                     AS disc_tier

    FROM orders o
    LEFT JOIN products p USING (product_id)
)

SELECT * FROM joined
