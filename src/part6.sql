CREATE OR REPLACE FUNCTION fn_part6(count_of_group INTEGER,
                                    churn_rate NUMERIC,
                                    stability_index NUMERIC,
                                    SKU_share NUMERIC,
                                    margin NUMERIC
                                    )
RETURNS TABLE(customer_ID INTEGER,
			 SKU_name VARCHAR,
 			 Offer_Discount_Depth NUMERIC
             )
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
WITH CTE1 AS (SELECT G.customer_id, G.group_id, G.group_affinity_index, PG.sku_id,
               PG.sku_name, C.customer_primary_store, G.group_minimum_discount,
               S.transaction_store_id, C.customer_average_check_segment, sku_retail_price,
               MAX(sku_retail_price - sku_purchase_price) OVER (PARTITION BY G.group_id) AS max_marg,
               (sku_retail_price - sku_purchase_price) AS marg FROM groups G
                JOIN "ProductGrid" PG ON PG.group_id = G.group_id
                JOIN "Stores" S ON PG.sku_id = S.sku_id
                JOIN customers C ON C.customer_primary_store = S.transaction_store_id
                WHERE group_churn_rate <= churn_rate AND group_stability_index < stability_index AND customer_average_check_segment = 'Low'
                ORDER BY G.customer_id),
    CTE2 AS (SELECT DISTINCT * FROM CTE1
             WHERE marg = max_marg),
    CTE3 AS (SELECT CTE2.*, row_number() OVER
              (PARTITION BY CTE2.customer_id ORDER BY CTE2.group_affinity_index) AS group_count
             FROM CTE2),
    CTE4 AS (SELECT CTE3.*,
             (SELECT count(*) FROM "Checks" C WHERE C.sku_id = CTE3.sku_id) /
             (SELECT count(*) FROM "Checks" C
              JOIN "ProductGrid" PG ON C.sku_id = PG.sku_id
              WHERE PG.group_id = CTE3.group_id)::NUMERIC AS SKUshare
              FROM CTE3
              WHERE group_count <= count_of_group),
    CTE5 AS (SELECT CTE4.*,
             (FLOOR((CTE4.group_minimum_discount * 100) / 5) * 5)::NUMERIC AS disc,
             CEIL(((((margin::numeric / 100) * CTE4.max_marg) / CTE4.sku_retail_price) * 100) / 5) * 5 AS acdisc
             FROM CTE4
             WHERE SKUshare <= SKU_share / 100),
    CTE6 AS (SELECT CTE5.customer_id,
             CTE5.sku_name,
               (CASE
                   WHEN CTE5.acdisc >= CTE5.disc THEN
                       CASE
                           WHEN CTE5.disc > 0 THEN
                            CTE5.disc
                            ELSE '5'::INTEGER
                       END
               END) AS discount
               FROM CTE5)
    SELECT * FROM CTE6
    WHERE discount IS NOT NULL;
END
$$;

SELECT * FROM fn_part6(5,3,0.5,100,30);


DROP FUNCTION fn_part6(count_of_group INTEGER,
                        churn_rate NUMERIC,
                        stability_index NUMERIC,
                        SKU_share NUMERIC,
                        margin NUMERIC);
