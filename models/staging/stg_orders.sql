WITH source AS (

    SELECT * FROM {{ source('raw', 'orders') }}

),

renamed AS (

    SELECT
        order_id,
        customer_id,
        TRIM(order_status)                                       AS order_status,
        TRY_CAST(order_purchase_timestamp AS TIMESTAMP)          AS order_purchase_timestamp,
        TRY_CAST(order_approved_at AS TIMESTAMP)                 AS order_approved_at,
        TRY_CAST(order_delivered_carrier_date AS TIMESTAMP)      AS order_delivered_carrier_date,
        TRY_CAST(order_delivered_customer_date AS TIMESTAMP)     AS order_delivered_customer_date,
        TRY_CAST(order_estimated_delivery_date AS TIMESTAMP)     AS order_estimated_delivery_date

    FROM source

)

SELECT * FROM renamed