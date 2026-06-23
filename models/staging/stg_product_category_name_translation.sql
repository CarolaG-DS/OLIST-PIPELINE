WITH source AS (

    SELECT * FROM {{ source('raw', 'product_category_name_translation') }}

),

renamed AS (

    SELECT
        TRIM(_product_category_name)            AS product_category_name,
        TRIM(product_category_name_english)     AS product_category_name_english

    FROM source

)

SELECT * FROM renamed