WITH source AS (

    SELECT * FROM {{ source('raw', 'order_payments') }}

),

renamed AS (

    SELECT
        order_id,
        payment_sequential,
        TRIM(payment_type)                          AS payment_type,
        TRY_CAST(payment_installments AS INTEGER)   AS payment_installments,
        TRY_CAST(payment_value AS DECIMAL(10,2))    AS payment_value

    FROM source

)

SELECT * FROM renamed