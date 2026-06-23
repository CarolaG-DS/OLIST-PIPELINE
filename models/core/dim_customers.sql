WITH customers AS (

    SELECT * FROM {{ ref('stg_customers') }}

),

geolocation AS (

    SELECT * FROM {{ ref('stg_geolocation') }}

),

final AS (

    SELECT
        customers.customer_id,
        customers.customer_unique_id,
        customers.customer_city,
        customers.customer_state,
        customers.customer_zip_code_prefix,
        geolocation.lat   AS customer_lat,
        geolocation.lng   AS customer_lng

    FROM customers
    LEFT JOIN geolocation --to not loose cust with no coordinates
        ON customers.customer_zip_code_prefix = geolocation.zip_code_prefix

)

SELECT * FROM final