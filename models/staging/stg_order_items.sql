WITH source AS (

    SELECT * FROM {{ source('raw', 'order_items') }}

),

renamed AS (

    SELECT
        order_id,
        order_item_id,
        product_id,
        seller_id,
        TRY_CAST(shipping_limit_date AS TIMESTAMP)   AS shipping_limit_date,
        TRY_CAST(price AS DECIMAL(10,2))             AS price,
        TRY_CAST(freight_value AS DECIMAL(10,2))     AS freight_value

    FROM source

)

SELECT * FROM renamed