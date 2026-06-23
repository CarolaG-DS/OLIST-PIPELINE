WITH products AS (

    SELECT * FROM {{ ref('stg_products') }}

),

translation AS (

    SELECT * FROM {{ ref('stg_product_category_name_translation') }}

),

final AS (

    SELECT
        products.product_id,
        products.product_category_name,
        COALESCE(translation.product_category_name_english, 'unknown')   AS product_category_name_english, --if no traslation
        products.product_name_length,
        products.product_description_length,
        products.product_photos_qty,
        products.product_weight_g,
        products.product_length_cm,
        products.product_height_cm,
        products.product_width_cm

    FROM products
    LEFT JOIN translation --left to not loose products that have not translaction 
        ON products.product_category_name = translation.product_category_name

)

SELECT * FROM final