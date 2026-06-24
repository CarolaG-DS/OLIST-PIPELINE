{{ config(
    materialized='table'
) }}

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

customers AS (
    SELECT * FROM {{ ref('dim_customers') }}
),

order_items_agg AS (
    SELECT
        order_id,
        SUM(price)               AS total_items_price,
        SUM(freight_value)       AS total_freight_value,
        SUM(price + freight_value) AS total_order_value,
        COUNT(order_item_id)     AS total_items_quantity
    FROM {{ ref('stg_order_items') }}
    GROUP BY order_id
),

payments_agg AS ( --aggregazione dei pagamenti per order_id to avoid fans out
    SELECT
        order_id,
        SUM(payment_value)          AS total_payment_value,
        COUNT(payment_sequential)   AS total_payments_count
    FROM {{ ref('stg_order_payments') }}
    GROUP BY order_id
),

reviews_agg AS (
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM {{ ref('stg_order_reviews') }}
    GROUP BY order_id
),

final AS (
    SELECT
        o.order_id,
        o.customer_id,
        c.customer_unique_id,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,

        -- items (aggregated before join, avoids fan-out)
        COALESCE(i.total_items_price, 0.00)    AS items_value,
        COALESCE(i.total_freight_value, 0.00)  AS freight_value,
        COALESCE(i.total_order_value, 0.00)    AS order_value,
        COALESCE(i.total_items_quantity, 0)    AS total_items_quantity,

        -- payments (aggregated before join, avoids fan-out)
        COALESCE(p.total_payment_value, 0.00)  AS total_payment_value,
        COALESCE(p.total_payments_count, 0)    AS total_payments_count,

        -- reviews
        r.avg_review_score,

        -- delivery_days: NULL when the order was never delivered.
        -- This is intentional - "no value" is the correct answer for
        -- an order that hasn't arrived, not zero or a guess.
        (o.order_delivered_customer_date::DATE - o.order_purchase_timestamp::DATE) AS delivery_days,

        -- is_late_delivery: three explicit states instead of a binary flag,
        -- so "never delivered" is never silently counted as "on time".
        --   1 = delivered later than estimated (late)
        --   0 = delivered on or before estimated (on time)
        --   NULL = not delivered yet / no delivery date to compare
        CASE
            WHEN o.order_delivered_customer_date IS NULL THEN NULL
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
            ELSE 0
        END AS is_late_delivery

    FROM orders o
    LEFT JOIN customers c       ON o.customer_id = c.customer_id
    LEFT JOIN order_items_agg i ON o.order_id = i.order_id
    LEFT JOIN payments_agg p    ON o.order_id = p.order_id
    LEFT JOIN reviews_agg r     ON o.order_id = r.order_id
)

SELECT * FROM final