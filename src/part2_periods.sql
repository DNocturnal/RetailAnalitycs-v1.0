DROP MATERIALIZED VIEW Periods CASCADE ;
CREATE MATERIALIZED VIEW IF NOT EXISTS Periods AS
    WITH Period AS (
         SELECT  P.customer_id, group_id, t.transaction_id, ((sku_discount/sku_summ)) as Group_Min_Discount
            FROM "PersonalInformation" P
            JOIN "Cards" C ON P.customer_id = C.customer_id
            JOIN "Transactions" T ON C.customer_card_id = T.customer_card_id
            JOIN "Checks" CH ON CH.transaction_id = T.transaction_id
            JOIN "ProductGrid" PG on CH.sku_id = PG.sku_id
            GROUP BY P.customer_id, PG.group_id, t.transaction_id, sku_discount/sku_summ
            ORDER BY P.customer_id ),
        Date_First_Last_Purchase AS (
            SELECT Ph.customer_id, ph.group_id, min((transaction_datetime)) AS First_Group_Purchase_Date, max((transaction_datetime)) AS Last_Group_Purchase_Date,
                   count(ph.transaction_id) AS Group_Purchase
            FROM Purchase_History PH
            GROUP BY Ph.customer_id, ph.group_id
            ORDER BY Ph.customer_id, group_id ),
        Frequency_Purchase AS (
            SELECT d.customer_id, d.group_id, ((extract(epoch from Last_Group_Purchase_Date -  First_Group_Purchase_Date)/86400 + 1) / Group_Purchase)::numeric AS Group_Frequency
            FROM Date_First_Last_Purchase d
        )
        SELECT  D.Customer_ID, D.Group_ID, First_Group_Purchase_Date, Last_Group_Purchase_Date, Group_Purchase, Group_Frequency,
                CASE
                    WHEN max(group_min_discount) = 0 THEN 0
                    ELSE (min(Group_Min_Discount) FILTER ( WHERE group_min_discount > 0 ))
                    END AS Group_Min_Discount
        FROM Period P
        JOIN Date_First_Last_Purchase D ON D.customer_id = P.customer_id AND p.group_id = d.group_id
        JOIN Frequency_Purchase F ON F.customer_id = D.customer_id AND f.group_id = p.group_id
        GROUP BY D.group_id, d.customer_id, First_Group_Purchase_Date, Last_Group_Purchase_Date, Group_Purchase, Group_Frequency
        ORDER BY D.customer_id, D.group_id;


-- tests
    select * from periods
        where Group_Purchase = 10;
    select * from periods
        where Last_Group_Purchase_Date < '2020-01-01';
    select customer_id, group_id, group_min_discount
    from periods
        where Group_Frequency <= 1;
