-- models/staging/stg_returns.sql
-- Grain: one row per returned order_id.

WITH source AS (
    SELECT * FROM {{ source('lumiere_raw', 'returns') }}
)

SELECT
    order_id,
    CAST(return_date AS date) AS return_date,
    reason                    AS return_reason

FROM source