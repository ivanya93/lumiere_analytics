-- models/staging/stg_sales_targets.sql
--
-- Fixes the hyphenated "year-month" column and splits it into integer
-- year + month fields — matching clean_targets() in notebook 01.
-- Grain: one row per country + year_month.

WITH source AS (
    SELECT * FROM {{ source('lumiere_raw', 'sales_targets') }}
)

SELECT
    country,
    "year-month"                                         AS year_month,
    split_part("year-month", '-', 1)::integer            AS year,
    split_part("year-month", '-', 2)::integer            AS month,
    CAST(target_revenue AS numeric)                      AS target_revenue

FROM source