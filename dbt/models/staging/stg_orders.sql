-- models/staging/stg_orders.sql
-- Cleans and types the raw orders table loaded by notebook 03.
-- Grain: one row per order_id.

WITH source AS (
    SELECT 
    * FROM {{ source('lumiere_raw', 'orders') }}
),

typed AS (
    SELECT
        order_id,
        customer_id,
        product_id,

        CAST(order_date AS date)     AS order_date,
        CAST(ship_date  AS date)     AS ship_date,

        country,
        channel,
        payment_method,

        CAST(quantity      AS integer) AS quantity,
        CAST(unit_price    AS numeric) AS unit_price,
        CAST(discount      AS numeric) AS discount,       -- 0.0 to 0.5
        CAST(shipping_cost AS numeric) AS shipping_cost,

        -- kpi: ship_date - order_date in days: A product cannot be shipped before it is ordered ergo
        CAST(ship_date AS date) - CAST(order_date AS date) AS shipping_days,

        -- kpi: gross and net revenue at staging layer
        CAST(unit_price AS numeric) * CAST(quantity AS integer)
            AS gross_revenue,

        -- kpi: net revenue
        CAST(unit_price AS numeric) * CAST(quantity AS integer)
            * (1 - CAST(discount AS numeric))
            AS net_revenue

    FROM source
),
-- quality check applied to filter out orders with invalid discount, price, quantity, or shipping dates
validated AS (
    SELECT *
    FROM typed
    WHERE discount BETWEEN 0 AND 0.5
      AND unit_price > 0
      AND quantity BETWEEN 1 AND 5
      AND ship_date >= order_date
)

SELECT * FROM validated