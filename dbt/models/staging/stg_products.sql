-- models/staging/stg_products.sql

-- Grain: one row per product_id.

WITH source AS (
    SELECT * FROM {{ source('lumiere_raw', 'products') }}
)

SELECT
    product_id,
    product_name,
    category,
    "sub-category"               AS sub_category,    -- fix hyphen from raw header
    brand,
    CAST(unit_cost   AS numeric) AS unit_cost,
    CAST(list_price  AS numeric) AS list_price,
    CAST(launch_date AS date)    AS launch_date,
    -- kpi: product margin percentage (1 - unit_cost / list_price) --- IGNORE ---
    ROUND(
        (CAST(list_price AS numeric) - CAST(unit_cost AS numeric))
        / NULLIF(CAST(list_price AS numeric), 0),
        4
    )                            AS product_margin_pct

FROM source