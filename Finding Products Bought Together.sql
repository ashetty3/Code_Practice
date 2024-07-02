
------- Question 1 JULY -------------------------------------------------------------------------------

/* You have a table of customer orders and a table of product inventory. Write a query to find products that are frequently ordered together (in the same order) but are currently low in stock. Define "frequently ordered together" as appearing in the same order more than 100 times, and "low in stock" as having less than 20 units available.

Assume you have the following tables:
orders table:

order_id (int)
customer_id (int)
product_id (int)
order_date (date)
quantity (int)

inventory table:

product_id (int)
product_name (varchar)
stock_quantity (int)

Please write a SQL query to solve this problem.*/

--------------------------------My attempt ------------------------------------------------------

WITH Product_Combo AS -- To find all combinations
(
  SELECT PD1, PD2,OD1 
  FROM (SELECT DISTINCT ORDER_ID AS OD1,PRODUCT_ID AS PD1) ORDERS O1
  JOIN (SELECT DISTINCT ORDER_ID AS OD2, PRODUCT_ID AS PD2 ) ORDERS O2 
  ON OD1 = OD2 AND PD1 <> PD2 
),
removing_dupes AS -- To make sure everything is counted only once for the order 
(
SELECT PD1,PD2 
  FROM Product_Combo PROD
  JOIN (SELECT DISTINCT PD2 AS DUPE_ID,OD1 AS DUPE_OD FROM Product_Combo) PROD2 
  ON PROD.PD1 <> PROD2.DUPE_ID AND DUPE_OD=PROD.OD1
)
,
aggregating AS 
(
SELECT row_number() OVER(ORDER BY PD1, PD2) as rn,PD1,PD2, COUNT(DISTINCT OD1) AS COUNT
FROM removing_dupes
GROUP BY PD1,PD2 
HAVING COUNT(DISTINCT OD1) > 100
)
,
stock1 AS 
(
Select agg1.pd1, p.product_name as product_name1, p.stock as st1 
from (select distinct pd1 from aggregating) agg1
join products p on agg1.pd1 = p.product_id where stock <20
)
,
stock2 AS 
(
Select agg2.pd2, p2.product_name as product_name2, p2.stock as st2
from (select distinct pd2 from aggregating) agg2
join products p2 on agg2.pd2 = p2.product_id where stock <20
)

Select product_name1, max(stock1) as,product_name2,max(stock2) as stock2
from aggregating agg
left join stock1 s1 on s1.pd1 = agg.pd1
left join stock2 s2 on s2.pd2 = agg.pd2
group by product_name1,product_name2, rn
having max(stock1) <20 or max(stock2)<20 

------------------- Better Answer -------------------------------------------------------------

WITH ProductPairs AS (
    SELECT o1.product_id AS product1, o2.product_id AS product2, o1.order_id
    FROM orders o1
    JOIN orders o2 ON o1.order_id = o2.order_id AND o1.product_id < o2.product_id -- Rely on non-equijoins to remove dupes and not explode the data
),
FrequentPairs AS (
    SELECT product1, product2, COUNT(DISTINCT order_id) AS order_count
    FROM ProductPairs
    GROUP BY product1, product2
    HAVING COUNT(DISTINCT order_id) > 100
),
LowStockProducts AS (
    SELECT product_id, product_name, stock_quantity -- Just have this list ready for a better join 
    FROM inventory
    WHERE stock_quantity < 20
)
SELECT 
    fp.product1, 
    lsp1.product_name AS product1_name, 
    lsp1.stock_quantity AS product1_stock,
    fp.product2, 
    lsp2.product_name AS product2_name, 
    lsp2.stock_quantity AS product2_stock,
    fp.order_count
FROM FrequentPairs fp
JOIN LowStockProducts lsp1 ON fp.product1 = lsp1.product_id -- we only wanted entries where both the products are low on stock. 
JOIN LowStockProducts lsp2 ON fp.product2 = lsp2.product_id
ORDER BY fp.order_count DESC;