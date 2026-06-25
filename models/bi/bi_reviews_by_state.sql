--Review score medio per stato
WITH orders AS (

    SELECT * FROM {{ ref('fct_orders') }}

),

customers AS (

    SELECT * FROM {{ ref('dim_customers') }}

),

joined AS (

    SELECT
        customers.customer_state,
        orders.avg_review_score

    FROM orders
    LEFT JOIN customers
        ON orders.customer_id = customers.customer_id

),

final AS (

    SELECT
        customer_state,
        COUNT(*)              AS total_orders, --count how many orders from each state, to give context and robustness
        AVG(avg_review_score) AS avg_review_score

    FROM joined
    GROUP BY customer_state

)

SELECT * FROM final

/*Quali stati brasiliani hanno il più alto e il più basso livello di soddisfazione cliente?

Insight:

Identificare aree con problemi di servizio.
Prioritizzare interventi operativi.*/

