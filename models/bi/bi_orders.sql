WITH orders AS (

    SELECT * FROM {{ ref('fct_orders') }}

),

customers AS (

    SELECT * FROM {{ ref('dim_customers') }}

),

final AS (

    SELECT
        orders.order_id,
        orders.order_status,
        customers.customer_state,
        customers.customer_city,
        DATE_TRUNC('month', orders.order_purchase_timestamp)   AS purchase_month,
        orders.order_value,
        orders.is_late_delivery,
        orders.avg_review_score

    FROM orders
    LEFT JOIN customers
        ON orders.customer_id = customers.customer_id

)

SELECT * FROM final