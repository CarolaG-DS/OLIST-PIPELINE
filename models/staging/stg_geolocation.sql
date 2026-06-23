WITH source AS (

    SELECT * FROM {{ source('raw', 'geolocation') }}

),

casted AS (

    SELECT
        TRY_CAST(geolocation_zip_code_prefix AS INTEGER)   AS zip_code_prefix,
        TRY_CAST(geolocation_lat AS DECIMAL(10,6))          AS lat,
        TRY_CAST(geolocation_lng AS DECIMAL(10,6))          AS lng,
        TRIM(geolocation_city)                               AS city,
        TRIM(geolocation_state)                              AS state

    FROM source

),

filtered AS (

    -- removing the outliers
    SELECT *
    FROM casted
    WHERE lat BETWEEN -33.75 AND 5.27
      AND lng BETWEEN -73.99 AND -28.85

),

aggregated AS (

    --removing dublicates by setting an avg lat and lng and combining those per zip code 
    SELECT
        zip_code_prefix,
        AVG(lat)                          AS lat,
        AVG(lng)                          AS lng,
        MODE(city)                        AS city, -- mode= most frequently occurring value in a group
        MODE(state)                       AS state

    FROM filtered
    GROUP BY zip_code_prefix

)

SELECT * FROM aggregated