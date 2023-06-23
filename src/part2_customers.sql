-- CLIENTS
DROP MATERIALIZED VIEW IF EXISTS Customers CASCADE;

CREATE MATERIALIZED VIEW IF NOT EXISTS Customers AS
    --Значение среднего чека клиента в рублях за анализируемый период
WITH  Id_Average_Check AS(
    SELECT pi.customer_id AS customer_id,
    (SUM(transaction_summ) / COUNT(transaction_summ))::numeric AS "customer_average_check"
    FROM "PersonalInformation" pi
    JOIN "Cards" c ON pi.customer_id = c.customer_id
    JOIN "Transactions" t ON c.customer_card_id = t.customer_card_id
    GROUP BY pi.customer_id
    ORDER BY customer_average_check DESC),

    -- Значение частоты визитов клиента в среднем количестве дней между транзакциями.
    Frequency AS(
         SELECT pi.customer_id as customer_id,
        (max(date(transaction_datetime ))-min(date(transaction_datetime )))/count(transaction_id)::numeric as customer_frequency
        FROM "PersonalInformation" pi
        JOIN "Cards" c ON  pi.customer_id = c.customer_id
        JOIN "Transactions" t ON c.customer_card_id = t.customer_card_id
        GROUP BY pi.customer_id
        ORDER BY customer_frequency ASC),

    --Количество дней, прошедших с даты предыдущей транзакции клиента.
    Inactive_Period AS(
        SELECT pi.customer_id,
        (extract(epoch from (SELECT * FROM "DateOfAnalysisFormation"))-extract(epoch from max(transaction_datetime)))/86400 AS customer_inactive_period
        FROM "PersonalInformation" pi
        JOIN "Cards" c ON  pi.customer_id = c.customer_id
        JOIN "Transactions" t ON c.customer_card_id = t.customer_card_id
        GROUP BY pi.customer_id
        ORDER BY customer_inactive_period ASC ),

    -- Значение коэффициента оттока клиента
    Churn_Rate AS (
        SELECT IP.customer_id, customer_inactive_period/customer_frequency::numeric  AS customer_churn_rate
        FROM Inactive_Period IP
        JOIN Frequency F ON IP.customer_id = F.customer_id
        ORDER BY customer_churn_rate ASC ),

    -- для определения каждого клиента к процентному соотношению
    Percentile_Calculation_Check AS (
        SELECT customer_id, customer_average_check,
        CUME_DIST() OVER (ORDER BY customer_average_check DESC) AS percent_check_rank
        FROM Id_Average_Check),

    Percentile_Calculation_Frequency AS (
        SELECT customer_id, customer_frequency,
        CUME_DIST() OVER (ORDER BY customer_frequency ASC) AS percent_frequency_rank
        FROM Frequency),

    Percentile_Calculation_Churn AS (
        SELECT customer_id, customer_frequency,
        CUME_DIST() OVER (ORDER BY customer_frequency ASC) AS percent_frequency_rank
        FROM Frequency),

    Churn_Rate_Value AS (
        SELECT customer_id, customer_churn_rate
        FROM Churn_Rate ),

    -- для определения сегмента
    Check_Segment AS (
        SELECT customer_id, customer_average_check,
           CASE
               WHEN percent_check_rank <= 0.1 THEN 'High'
               WHEN percent_check_rank > 0.1 AND percent_check_rank <= 0.35 THEN 'Medium'
               ELSE 'Low'
           END AS customer_average_check_segment
        FROM Percentile_Calculation_Check),

    Frequency_Segment AS (
        SELECT customer_id, customer_frequency,
           CASE
               WHEN percent_frequency_rank <= 0.1 THEN 'Often'
               WHEN percent_frequency_rank > 0.1 AND percent_frequency_rank <= 0.35 THEN 'Occasionally'
               ELSE 'Rarely'
           END AS customer_frequency_segment
        FROM Percentile_Calculation_Frequency),

    Churn_Segment AS(
        SELECT customer_id,
           CASE
               WHEN customer_churn_rate <= 2 THEN 'Low'
               WHEN customer_churn_rate > 2 AND customer_churn_rate <= 5 THEN 'Medium'
               ELSE 'High'
           END AS customer_churn_segment
        FROM Churn_Rate_Value),

--     Номер сегмента, к которому принадлежит клиент
   Segment_Number AS (
        SELECT C.customer_id,

                    CASE customer_average_check_segment
                        WHEN 'Low' THEN 0
                        WHEN 'Medium' THEN 9
                        ELSE 18 END +
                    CASE customer_frequency_segment
                        WHEN 'Rarely' THEN 0
                        WHEN 'Occasionally' THEN 3
                        ELSE 6 END +
                    CASE customer_churn_segment
                        WHEN 'Low' THEN 1
                        WHEN 'Medium' THEN 2
                        ELSE 3
                    END AS customer_segment
                FROM Check_Segment C
                JOIN Frequency_Segment F ON C.customer_id = F.customer_id
                JOIN Churn_Segment CS ON CS.customer_id = F.customer_id),
--     select * from segment_number

--Определение перечня магазинов клиента

    All_Store_And_Share AS(
        SELECT pi.customer_id, transaction_store_id, count(transaction_store_id) as share_1
        FROM "PersonalInformation" pi
        JOIN "Cards" c ON  pi.customer_id = c.customer_id
        JOIN "Transactions" t ON c.customer_card_id = t.customer_card_id
        GROUP BY pi.customer_id,transaction_store_id
        ORDER BY customer_id
    ),
    Count_Share2 AS (
        SELECT pi.customer_id, c1.transaction_store_id, share_1, count(t.transaction_store_id) as share_2
        FROM "PersonalInformation" pi
        JOIN "Cards" c ON  pi.customer_id = c.customer_id
        JOIN "Transactions" t ON c.customer_card_id = t.customer_card_id
        JOIN All_Store_And_Share c1 ON c1.customer_id = pi.customer_id
        GROUP BY pi.customer_id, c1.transaction_store_id, c1.share_1
        ORDER BY customer_id
    ),
    -- Определение доли транзакций
    Calculation_in_Share AS(
     SELECT ASAS.customer_id, asas.transaction_store_id, asas.share_1, share_2, asas.share_1/share_2::numeric as calculation_share
        FROM Count_Share2 CS
        JOIN All_Store_And_Share ASAS ON  CS.customer_id = ASAS.customer_id
        GROUP BY ASAS.customer_id,asas.transaction_store_id, asas.share_1, share_2
        ORDER BY customer_id
    ),
--     select * from calculation_in_share
 -- три последние транзакции
    All_Transaction AS (
        SELECT
            Customer_ID,
            transaction_id,
            Transaction_Store_ID,
            ROW_NUMBER() OVER (PARTITION BY Customer_ID ORDER BY Transaction_DateTime DESC) as store_number, transaction_datetime
        FROM
            "Transactions" t
        JOIN "Cards" C2 on C2.customer_card_id = t.customer_card_id ),

    Three_Last_Transaction AS(
        SELECT Customer_ID,
            CASE
                WHEN store_number = 1 THEN transaction_store_id
            END AS store1,
            CASE
                WHEN store_number = 2 THEN transaction_store_id
            END AS store2,
            CASE
                WHEN store_number = 3 THEN transaction_store_id
            END AS store3
        FROM All_Transaction
        WHERE store_number <= 3
            GROUP BY Customer_ID, transaction_store_id, store_number
            ORDER BY customer_id),
    Store1 AS (
         SELECT t.customer_id, store1, calculation_share as calc_share1
         FROM Three_Last_Transaction t
         JOIN Calculation_in_Share c ON c.customer_id = t.customer_id and transaction_store_id = store1
         WHERE store1 is not null
         GROUP BY t.customer_id , store1, calculation_share ),
     Store2 AS (
         SELECT t.customer_id, store2, calculation_share as calc_share2
          FROM Three_Last_Transaction t
         JOIN Calculation_in_Share c ON c.customer_id = t.customer_id and transaction_store_id = store2
         WHERE store2 is not null
         GROUP BY t.customer_id ,  store2, calculation_share),
     Store3 AS (
         SELECT t.customer_id,  store3, calculation_share as calc_share3
         FROM Three_Last_Transaction t
         JOIN Calculation_in_Share c ON c.customer_id = t.customer_id and transaction_store_id = store3
         WHERE store3 is not null
         GROUP BY t.customer_id ,  store3, calculation_share),
    -- В случае, если три последние транзакции совершены в одном и том же магазине
    AllStore AS (
         SELECT s1.customer_id, s1.store1, calc_share1, s2.store2, calc_share2, s3.store3, calc_share3
         FROM Store1 s1
         JOIN Store2 s2 ON s1.customer_id = s2.customer_id
         JOIN Store3 s3 ON s2.customer_id = s3.customer_id
         GROUP BY s1.customer_id , s1.store1, s2.store2, s3.store3, calc_share1, calc_share2, calc_share3),
    -- в случае максимальной доли
    Max_Calc_Share AS (
        SELECT customer_id,
           CASE
             WHEN calc_share1 >= calc_share2 AND calc_share1 >= calc_share3 THEN store1
             WHEN calc_share2 >= calc_share1 AND calc_share2 >= calc_share3 THEN store2
             ELSE store3
           END AS primary_store,
           CASE
             WHEN calc_share1 >= calc_share2 AND calc_share1 >= calc_share3 THEN calc_share1
             WHEN calc_share2 >= calc_share1 AND calc_share2 >= calc_share3 THEN calc_share2
             ELSE calc_share3
           END AS max_calc_share
        FROM AllStore),
    -- в случае самой поздней по времени транзакции
    Last_datetime AS (
        SELECT customer_id, transaction_store_id AS primary_store2, transaction_datetime
        FROM All_Transaction a
        WHERE store_number = 1
    ),
    Primary_Store AS (
        SELECT a.customer_id,
            CASE
                WHEN store1 = store2 and store2 = store3 THEN store1
                WHEN calc_share1 = calc_share2 and calc_share2 = calc_share3 THEN m.primary_store
                ELSE l.primary_store2
            END AS Customer_Primary_Store
        FROM AllStore a
        JOIN Max_Calc_Share m ON m.customer_id = a.customer_id
        JOIN Last_datetime l ON a.customer_id = l.customer_id
        GROUP BY a.customer_id, store1, store2, store3, primary_store, primary_store2, calc_share3, calc_share2, calc_share1)

    SELECT iac.customer_id, iac.customer_average_check, cs.customer_average_check_segment, f.customer_frequency,
       fs.customer_frequency_segment, ip.customer_inactive_period, customer_churn_rate, customer_churn_segment, customer_segment, customer_primary_store
    FROM Id_Average_Check iac
         JOIN Check_Segment cs ON iac.customer_id = cs.customer_id
         JOIN Frequency f ON iac.customer_id = f.customer_id
         JOIN Frequency_Segment fs ON iac.customer_id = fs.customer_id
         JOIN Inactive_Period ip ON iac.customer_id = ip.customer_id
         JOIN Churn_Rate cr ON iac.customer_id = cr.customer_id
         JOIN Churn_Segment css ON iac.customer_id = css.customer_id
         JOIN Segment_Number sn ON iac.customer_id = sn.customer_id
         JOIN Primary_Store ps ON iac.customer_id = ps.customer_id
    ORDER BY iac.customer_id;

-- tests
    select * from customers
        where customer_primary_store = 4;
    select * from customers
        where customer_churn_segment = 'Medium';
    select * from customers
        where customer_id > 10 and customer_average_check < 900;
