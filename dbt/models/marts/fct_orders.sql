-- DCAT: The standard metadata language

-- Lumiere: Catalog: Describing the unified knowledge graph of data assets in the organization, to enable data discovery and governance.

-- models/marts/fct_orders.sql
--
-- Final fact table for Tableau. Joins int_orders_enriched with returns,
-- to add is_return flag — the equivalent of adding a return indicator to the orders_enriched parquet saved in notebook 02.
-- Grain: one row per order_id.

WITH orders AS (
    SELECT * FROM {{ ref('int_orders_enriched') }} --ref means: select from the int_orders_enriched model
),

returns AS (
    SELECT
        order_id,
        1             as is_return, -- 1=returned, 0=not returned (will be filled in with COALESCE in final select)
        return_reason
    FROM {{ ref('stg_returns') }}
)

SELECT
    o.*,
    COALESCE(r.is_return, 0)    AS is_return,
    r.return_reason

FROM orders o
LEFT JOIN returns r USING (order_id)
