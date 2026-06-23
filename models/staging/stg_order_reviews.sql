WITH source AS (

    SELECT * FROM {{ source('raw', 'order_reviews') }}

),

renamed AS (

    SELECT
        review_id,
        order_id,
        TRY_CAST(review_score AS INTEGER)               AS review_score,
        TRIM(review_comment_title)                       AS review_comment_title,
        TRIM(review_comment_message)                     AS review_comment_message,
        TRY_CAST(review_creation_date AS TIMESTAMP)      AS review_creation_date,
        TRY_CAST(review_answer_timestamp AS TIMESTAMP)   AS review_answer_timestamp

    FROM source

)

SELECT * FROM renamed