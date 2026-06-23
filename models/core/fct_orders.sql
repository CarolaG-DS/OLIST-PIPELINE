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
        SUM(price) AS total_items_price,
        SUM(freight_value) AS total_freight_value,
        SUM(price + freight_value) AS total_order_value,
        COUNT(order_item_id) AS total_items_quantity
    FROM {{ ref('stg_order_items') }} 
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
        COALESCE(i.total_items_price, 0.00) AS items_value, --if there is a null value replace it with 0.00
        COALESCE(i.total_freight_value, 0.00) AS freight_value,
        COALESCE(i.total_order_value, 0.00) AS order_value,
        COALESCE(i.total_items_quantity, 0) AS total_items_quantity,
        r.avg_review_score,
        (o.order_delivered_customer_date::DATE - o.order_purchase_timestamp::DATE) AS delivery_days,
        
        CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 --late delivery
            ELSE 0
        end as is_late_delivery

    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.customer_id
    LEFT JOIN order_items_agg i ON o.order_id = i.order_id
    LEFT JOIN reviews_agg r ON o.order_id = r.order_id
)

SELECT * FROM final