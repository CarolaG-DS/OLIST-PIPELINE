WITH source AS (

    SELECT * FROM {{ source('raw', 'customers') }}

),

renamed AS (

    SELECT
        customer_id,                                     --unique per order
        customer_unique_id,                              --unique per client
        TRY_CAST(customer_zip_code_prefix AS INTEGER)    AS customer_zip_code_prefix,
        TRIM(customer_city)                              AS customer_city,
        TRIM(customer_state)                             AS customer_state

    FROM source

)

SELECT * FROM renamed