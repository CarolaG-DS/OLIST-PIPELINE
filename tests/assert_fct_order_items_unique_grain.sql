-- Singular test: fct_order_items must be unique at its declared grain
-- (GRAIN:one row per order line, i.e. one row per order_id + order_item_id pair).
--
-- Neither column is unique on its own:
--   - order_id repeats (an order has many items)
--   - order_item_id repeats (item #1 exists in every order)
-- Only the COMBINATION of the two should never repeat.
--
-- This test passes when it returns ZERO rows (no duplicate combinations).
-- If it returns any row, that order_id + order_item_id pair appears more
-- than once, meaning the grain of fct_order_items has been violated.

SELECT
    order_id,
    order_item_id,
    COUNT(*) AS duplicate_count

FROM {{ ref('fct_order_items') }}

GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1

/*cosa rappresenta esattamente una singola riga di quella tabella.

fct_orders ha grain = un ordine. Ogni riga è un ordine, punto. Se hai 50.000 ordini, hai 50.000 righe.
fct_order_items ha grain = una riga d'ordine (item). Ogni riga è una singola linea/prodotto dentro un ordine. Se un ordine ha 3 prodotti diversi, quell'ordine genera 3 righe in questa tabella.
dim_customers ha grain = customer_id (cioè un cliente per ordine specifico, come avevamo deciso seguendo il brief).
 né order_id da solo è unico (un ordine ha più righe/item), né order_item_id da solo è unico (l'item numero 1 esiste in ogni ordine). Quello che deve essere unico è la coppia order_id + order_item_id insieme — questa combinazione non dovrebbe mai ripetersi, perché altrimenti significherebbe che hai due righe identiche per lo stesso prodotto nello stesso ordine (un errore di duplicazione).
Un test generico non può esprimere "queste due colonne insieme devono essere uniche" senza l'aiuto di un package esterno (dbt_utils, che abbiamo scelto di non aggiungere per tenere il progetto più semplice). Quindi scriviamo noi una query SQL su misura, salvata come file in tests/ — un singular test.
La regola del singular test è semplicissima: se la query ritorna righe, il test fallisce. Se ritorna zero righe, il test passa.

POTEVO CREARE UN SURROGATE KEY (order_item_pk =order_id + order_item_id) E NON FARE IL SINGULAR TEST MA UNIQUE TEST*/