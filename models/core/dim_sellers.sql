{{ config(materialized='table') }}

WITH sellers AS (

    SELECT * FROM {{ ref('stg_sellers') }}

),

geolocation AS (

    SELECT * FROM {{ ref('stg_geolocation') }}

),

final AS (

    SELECT
        sellers.seller_id,
        sellers.seller_city,
        sellers.seller_state,
        sellers.seller_zip_code_prefix,
        geolocation.lat   AS seller_lat,
        geolocation.lng   AS seller_lng

    FROM sellers
    LEFT JOIN geolocation -- if a seller does not have coodinates for zip, we keep with null 
        ON sellers.seller_zip_code_prefix = geolocation.zip_code_prefix

)

SELECT * FROM final