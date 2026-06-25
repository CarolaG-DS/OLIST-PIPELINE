-- Relazione tra ritardo consegna e review score
WITH orders AS (

    SELECT * FROM {{ ref('fct_orders') }}

),

final AS (

    SELECT
        CASE
            WHEN is_late_delivery = 1 THEN 'late' -- change into word as più friendly per Tableau
            WHEN is_late_delivery = 0 THEN 'on_time'
            ELSE 'not_delivered'
        END                        AS delivery_status,

        COUNT(order_id)            AS total_orders, --to give a context (if only 5 out of 1000000 orders have not been delivered it does not weight much)
        AVG(avg_review_score)      AS avg_review_score --this is the avg of the avg by delivery status:

    FROM orders
    GROUP BY delivery_status

)

SELECT * FROM final

/* almost each order had one review (duplicates were rare), so in this case the avarage of the order weight as much as their score
I'm doing the 'mean score' of the products in a group (on time / late ..)
it would be a problem doing the avg of the avg if one order had many more reviews than another
in that case we would be doing a join between order fact and staging order review (which was not properly cleaned yet)  */