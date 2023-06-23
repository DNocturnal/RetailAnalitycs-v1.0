DROP MATERIALIZED VIEW IF EXISTS Groups CASCADE;
-- для этой таблицы нужна purchase_history
CREATE MATERIALIZED VIEW IF NOT EXISTS Groups AS
    -- индекс востребованности
    WITH Affenity_Index AS (
            SELECT PH.customer_id, P.group_id, group_purchase/count(ph.transaction_id)::numeric as group_affinity_index
            FROM Purchase_History PH
            JOIN Periods P ON P.customer_id = PH.customer_id
            WHERE ph.transaction_datetime BETWEEN first_group_purchase_date AND last_group_purchase_date
            GROUP BY PH.customer_id, P.group_id, group_purchase
            ORDER BY customer_id ),
        -- Индекс оттока клиента по конкретной группе
        Churn_Rate AS (
            SELECT  ph.customer_id, ph.group_id,
            (extract(epoch from(SELECT * FROM "DateOfAnalysisFormation")) - extract(epoch from max((ph.transaction_datetime))))/(group_frequency)/86400::numeric AS Group_Churn_Rate
            FROM "Transactions"
            JOIN purchase_history ph on "Transactions".transaction_id = ph.transaction_id
            JOIN periods p ON ph.group_id = p.group_id and p.customer_id = ph.customer_id
            GROUP BY ph.customer_id, ph.group_id, group_frequency
            ORDER BY customer_id, group_id ),
--  Показатель стабильности потребления группы определяется как среднее значение относительного отклонения
        Intervals AS (
            SELECT ph.customer_id, ph.transaction_id,  ph.group_id, ph.transaction_datetime,
            EXTRACT(DAY FROM (transaction_datetime - LAG(transaction_datetime)
                OVER (PARTITION BY ph.customer_id, ph.group_id ORDER BY transaction_datetime))) AS interval
            FROM purchase_history ph
            JOIN periods p ON p.customer_id = ph.customer_id and p.group_id = ph.group_id
            GROUP BY ph.customer_id, transaction_id, ph.group_id, transaction_datetime
            ORDER BY customer_id, group_id),
        Stability_Index AS (
            SELECT i.customer_id,  i.group_id, AVG(
                CASE
                    WHEN (i.interval - p.group_frequency) > 0::numeric
                    THEN (i.interval - p.group_frequency)
                    ELSE (i.interval - p.group_frequency) * '-1'::integer::numeric
                END / p.group_frequency) AS group_stability_index
            FROM Intervals i
            JOIN periods p on  p.customer_id = i.customer_id and i.group_id = p.group_id
            GROUP BY i.customer_id, i.group_id
            ORDER BY customer_id, group_id ),
        --Показатель актуальной маржи по группе для конкретного клиента
        Margin AS (
            SELECT customer_id, group_id, sum(group_summ_paid - group_cost)::numeric as Group_Margin
            FROM purchase_history
            GROUP BY customer_id, group_id
            ORDER BY customer_id, group_id ),
        Count_Discount_Share AS (
            SELECT DISTINCT p.customer_id, g.group_id,
                            CASE
                                WHEN max(sku_discount) = 0 THEN count(c3.transaction_id)
                                ELSE count(c3.transaction_id)  FILTER ( WHERE sku_discount> 0 )
                            END AS count_share
            FROM "PersonalInformation" P
            JOIN "Cards" C2 on p.customer_id = C2.customer_id
            JOIN "Transactions" T2 on C2.customer_card_id = T2.customer_card_id
            JOIN "Checks" C3 on T2.transaction_id = C3.transaction_id
            JOIN "ProductGrid" G on G.sku_id = C3.sku_id
            GROUP BY p.customer_id, g.group_id
            ORDER BY customer_id ),
        -- доля транзакций со скидкой
        Discount_Share AS (
            SELECT DISTINCT c.customer_id, c.group_id, count_share/group_purchase::numeric as Group_Discount_Share
            FROM Count_Discount_Share c
            JOIN periods p ON c.group_id = p.group_id and p.customer_id = c.customer_id
            GROUP BY c.customer_id, c.group_id, Group_Discount_Share ),
        -- мнимальная скидка по группе
        Minimum_Discount AS (
            SELECT customer_id, group_id, min(group_min_discount) as Group_Minimum_Discount
            FROM periods p
            GROUP BY customer_id, group_id
            ORDER BY customer_id, group_id ),
        -- средняя скидка по группе
        Group_Average_Discount AS (
            SELECT  customer_id, group_id, avg(group_summ_paid/group_summ)::numeric AS Group_Average_Discount
            FROM purchase_history
            JOIN "Checks" C4 on purchase_history.transaction_id = C4.transaction_id
            WHERE sku_discount > 0
            GROUP BY customer_id, group_id
            ORDER BY customer_id, group_id )

    SELECT DISTINCT af.customer_id, af.group_id, group_affinity_index, Group_Churn_Rate,
                    COALESCE(Group_Stability_Index, 0) AS Group_Stability_Index, Group_Margin,
           Group_Discount_Share, Group_Minimum_Discount, Group_Average_Discount
    FROM Affenity_Index af
         JOIN Churn_Rate cr ON af.group_id = cr.group_id AND af.customer_id = cr.customer_id
         JOIN Stability_Index si ON si.group_id = cr.group_id AND si.customer_id = af.customer_id
         JOIN Margin gm ON gm.customer_id = af.customer_id AND gm.group_id = af.group_id
         JOIN Discount_Share ds ON ds.group_id = cr.group_id AND ds.customer_id = cr.customer_id
         JOIN Minimum_Discount md ON md.group_id = af.group_id AND md.customer_id = af.customer_id
         JOIN Group_Average_Discount gad ON gad.group_id = md.group_id AND gad.customer_id = ds.customer_id
    GROUP BY af.customer_id, af.group_id, group_affinity_index, Group_Churn_Rate, Group_Discount_Share, Group_Minimum_Discount, Group_Average_Discount, Group_Stability_Index, Group_Margin
    ORDER BY af.customer_id, af.group_id;

    -- tests
    select * from groups
        where customer_id <= 3;
    select * from groups
        where group_margin > 0;
    select customer_id, group_churn_rate, group_average_discount
    from groups
        where group_churn_rate < 1;
