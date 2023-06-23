DROP MATERIALIZED VIEW IF EXISTS Purchase_History CASCADE;

CREATE MATERIALIZED VIEW IF NOT EXISTS Purchase_History AS
     WITH
         Group_id AS (
            SELECT P.customer_id, T.transaction_id, T.transaction_datetime, group_id,
                sum(sku_amount*sku_purchase_price)::numeric AS Group_Cost,
                sum(sku_summ)::numeric AS Group_summ,
                sum(sku_sum_paid)::numeric AS Group_Summ_Paid
            FROM "PersonalInformation" P
            JOIN "Cards" C ON P.customer_id = C.customer_id
            JOIN "Transactions" T ON C.customer_card_id = T.customer_card_id
            JOIN "Checks" CH ON CH.transaction_id = T.transaction_id
            JOIN "ProductGrid" PG on CH.sku_id = PG.sku_id
            JOIN "Stores" S ON PG.sku_id = S.sku_id and S.transaction_store_id = T.transaction_store_id
            GROUP BY P.customer_id, T.transaction_id, T.transaction_datetime, group_id, sku_discount
            ORDER BY P.customer_id, group_id )

    SELECT  * FROM Group_id g
    ORDER BY customer_id, group_id;

-- tests
select * from purchase_history
    where group_id = 1 and transaction_id > 100;
select * from purchase_history
    where Group_Cost < 50;
select customer_id, transaction_datetime, group_summ
from purchase_history
    where transaction_datetime < '2018-03-01'
