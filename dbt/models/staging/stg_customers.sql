-- models/staging/stg_customers.sql
-- Grain: one row per customer_id.

WITH source AS (
    SELECT * FROM {{ source('lumiere_raw', 'customers') }}
)

SELECT
    customer_id,
    customer_name,
    segment,
    country,
    city,
    CAST(acquisition_date AS date) AS acquisition_date,
    acquisition_channel

FROM source