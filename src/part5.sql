CREATE OR REPLACE FUNCTION fn_part5(first_date_period TIMESTAMP,
                                    last_date_period TIMESTAMP,
                                    adding_number_of_transactions INTEGER,
                                    customer_churn_rate NUMERIC,
                                    discount_share NUMERIC,
                                    margin NUMERIC
                                    )
RETURNS TABLE(customer_id INTEGER,
			 Start_Date TIMESTAMP,
			 End_Date TIMESTAMP,
			 Required_Transactions_Count NUMERIC,
 			 Group_Name VARCHAR,
 			 Offer_Discount_Depth NUMERIC
             )
LANGUAGE plpgsql
AS $$
BEGIN
RETURN QUERY
    WITH p1 AS (SELECT customers.customer_id,
                          first_date_period,
                          last_date_period,
                          ((SELECT EXTRACT(EPOCH FROM (last_date_period::TIMESTAMP - first_date_period)) /
                                  customer_frequency)::NUMERIC + adding_number_of_transactions) AS req_tr
                   FROM customers),
        p2 AS (SELECT * FROM fn_reward_group(customer_churn_rate, discount_share ,margin))

    SELECT p1.customer_id,
           p1.first_date_period,
           p1.last_date_period,
           p1.req_tr,
           S.group_name,
           p2.Offer_Discount_Depth
            FROM p1
    JOIN p2 ON p1.customer_id = p2.customer_id
    JOIN "SKUGroup" S ON S.group_id = p2.group_id;

END
$$;

DROP FUNCTION fn_part5(first_date_period TIMESTAMP,
                       last_date_period TIMESTAMP,
                       adding_number_of_transactions INTEGER,
                       customer_churn_rate NUMERIC,
                       discount_share NUMERIC,
                       margin NUMERIC);

SELECT * FROM fn_part5('18-08-2022 00:00:00' , '18-08-2022 00:00:00', 1, 3, 70, 30 );

-- ЭТА ЧАСТЬ ОДИНАКОВА ДЛЯ ФУНКЦИЙ 4 и 5

CREATE OR REPLACE FUNCTION fn_reward_group(customer_churn_rate NUMERIC,
                                           discount_share NUMERIC,
                                           margin NUMERIC)
RETURNS TABLE(customer_id INTEGER,
              group_id BIGINT,
			  Offer_Discount_Depth NUMERIC
             )
LANGUAGE plpgsql
AS $$
    DECLARE row RECORD;
            flag BOOL := FALSE;
            person_id INTEGER := 0;
            average_m NUMERIC;
            temp NUMERIC;
BEGIN
    FOR row IN (SELECT groups.customer_id, groups.group_id, group_affinity_index,
                group_churn_rate, group_discount_share, group_minimum_discount,
                DENSE_RANK() OVER (PARTITION BY groups.customer_id ORDER BY group_affinity_index DESC)
                FROM groups
                WHERE group_churn_rate <= customer_churn_rate AND group_discount_share < (discount_share / 100.)
                ORDER BY customer_id, group_minimum_discount)

    LOOP
    average_m = (SELECT AVG(group_summ_paid - group_cost)
                 FROM purchase_history ph
                 WHERE ph.customer_id = row.customer_id
                 AND ph.group_id = row.group_id);
    temp = (FLOOR ((row.group_minimum_discount * 100) / 5.0) * 5)::NUMERIC(10, 2);
    IF (person_id != row.customer_id) THEN
        IF (average_m > 0
            AND row.group_minimum_discount::NUMERIC(10, 2) > 0
            AND average_m * margin / 100. > temp * average_m / 100.) THEN
                IF (temp = 0) THEN
                temp = 5;
                END IF;
            RETURN QUERY (SELECT g.customer_id, g.group_id,
                          temp AS Offer_Discount_Depth
                          FROM groups g
                          WHERE row.customer_id = g.customer_id AND
                                row.group_id = g.group_id);
            person_id = row.customer_id;
        END IF;
    END IF;
    END LOOP;
END
$$;


