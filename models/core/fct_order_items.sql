WITH order_items AS (

    SELECT * FROM {{ ref('stg_order_items') }}

),

final AS (

    SELECT
        order_items.order_id,
        order_items.order_item_id,
        order_items.product_id,
        order_items.seller_id,
        order_items.shipping_limit_date,
        order_items.price,
        order_items.freight_value,
        order_items.price + order_items.freight_value   AS item_total_value

    FROM order_items

)

SELECT * FROM final