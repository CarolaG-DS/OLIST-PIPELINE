WITH source AS (

    SELECT * FROM {{ source('raw', 'products') }}

),

renamed AS (

    SELECT
        product_id,
        TRIM(product_category_name)                           AS product_category_name,
        TRY_CAST(product_name_lenght AS INTEGER)              AS product_name_length,
        TRY_CAST(product_description_lenght AS INTEGER)       AS product_description_length,
        TRY_CAST(product_photos_qty AS INTEGER)               AS product_photos_qty,
        TRY_CAST(product_weight_g AS INTEGER)                 AS product_weight_g,
        TRY_CAST(product_length_cm AS INTEGER)                AS product_length_cm,
        TRY_CAST(product_height_cm AS INTEGER)                AS product_height_cm,
        TRY_CAST(product_width_cm AS INTEGER)                 AS product_width_cm

    FROM source

)

SELECT * FROM renamed