WITH source AS (

    SELECT * FROM {{ source('raw', 'sellers') }}

),

renamed AS (

    SELECT
        seller_id,
        TRY_CAST(seller_zip_code_prefix AS INTEGER)     AS seller_zip_code_prefix,
        TRIM(seller_city)                               AS seller_city,
        TRIM(seller_state)                              AS seller_state

    FROM source

)

SELECT * FROM renamed