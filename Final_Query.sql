-- 1) Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT DISTINCT( market )
FROM   dim_customer
WHERE  region = "apac"
       AND customer = "atliq exclusive"; 
       

-- 2) What is the percentage of unique product increase in 2021 vs. 2020?

 WITH pro_2020 AS
  (SELECT count(distinct(product_code)) AS unique_products_2020
   FROM fact_sales_monthly
   WHERE fiscal_year = 2020),
     pro_2021 AS
  (SELECT count(distinct(product_code)) AS unique_products_2021
   FROM fact_sales_monthly
   WHERE fiscal_year = 2021)
SELECT p1.unique_products_2020,
       p2.unique_products_2021,
       Concat(Round(((p2.unique_products_2021 - p1.unique_products_2020) / p1.unique_products_2020) * 100, 2), '%') AS percentage_chg
FROM pro_2020 AS p1
CROSS JOIN pro_2021 AS p2;
       
       
-- 3) Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.

SELECT SEGMENT,
       count(distinct(product_code)) AS product_count
FROM dim_product
GROUP BY SEGMENT
ORDER BY product_count DESC;

-- 4) Follow-up: Which segment had the most increase in unique products in 2021 vs 2020?

WITH pro_2020 AS
  (SELECT pro.segment AS SEGMENT,
          count(distinct(pro.product_code)) AS product_count_2020
   FROM dim_product AS pro
   JOIN fact_sales_monthly sales ON pro.product_code = sales.product_code
   WHERE sales.fiscal_year =2020
   GROUP BY pro.segment
   ORDER BY product_count_2020 DESC),
     pro_2021 AS
  (SELECT pro.segment AS SEGMENT,
          count(distinct(pro.product_code)) AS product_count_2021
   FROM dim_product AS pro
   JOIN fact_sales_monthly sales ON pro.product_code = sales.product_code
   WHERE sales.fiscal_year =2021
   GROUP BY pro.segment
   ORDER BY product_count_2021 DESC)
SELECT p1.segment AS SEGMENT,
       p1.product_count_2020,
       p2.product_count_2021,
       (p2.product_count_2021 -p1.product_count_2020) AS difference
FROM pro_2020 AS p1
JOIN pro_2021 AS p2 ON p1.segment = p2.segment;

-- 5) Get the products that have the highest and lowest manufacturing costs.

SELECT pro.product_code,
       pro.product,
       cost.manufacturing_cost
FROM dim_product AS pro
JOIN fact_manufacturing_cost AS cost ON pro.product_code = cost.product_code
WHERE cost.manufacturing_cost in
    (SELECT MAX(cost.manufacturing_cost) 
     FROM fact_manufacturing_cost AS cost )
  OR cost.manufacturing_cost in
    (SELECT MIN(cost.manufacturing_cost)
     FROM fact_manufacturing_cost AS cost);
     
-- 6) Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.

SELECT fact.customer_code,
       customer,
       round(avg(pre_invoice_discount_pct)*100, 2) AS average_discount_percentage
FROM dim_customer AS c
JOIN fact_pre_invoice_deductions AS fact ON c.customer_code=fact.customer_code
WHERE c.market="india"
  AND fact.fiscal_year =2021
GROUP BY c.customer_code
ORDER BY average_discount_percentage DESC
LIMIT 5;


-- 7) Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. This analysis helps to get an idea of low and high-performing months and take strategic decisions.

SELECT left(monthname(fs.date), 3) AS MONTH,
       fs.fiscal_year AS YEAR,
       round(sum(fs.sold_quantity * fg.gross_price)/1000000, 2) AS 'Gross sales Amount (In Millions)'
FROM fact_sales_monthly AS fs
JOIN dim_customer AS ds ON fs.customer_code = ds.customer_code
JOIN fact_gross_price AS fg ON fg.product_code = fs.product_code
AND fg.fiscal_year = fs.fiscal_year
WHERE customer = 'Atliq Exclusive'
GROUP BY MONTH,
         YEAR
ORDER BY fs.date;

-- 8) In which quarter of 2020, got the maximum total_sold_quantity? 

WITH result
     AS (SELECT *,
                CASE
                  WHEN date BETWEEN '2019-09-01' AND '2019-11-01' THEN 'Q1'
                  WHEN date BETWEEN '2019-12-01' AND '2020-02-01' THEN 'Q2'
                  WHEN date BETWEEN '2020-03-01' AND '2020-05-01' THEN 'Q3'
                  WHEN date BETWEEN '2020-06-01' AND '2020-08-01' THEN 'Q4'
                END AS Quarter
         FROM   fact_sales_monthly
         WHERE  fiscal_year = 2020)
SELECT r.quarter,
       Sum(r.sold_quantity) AS total_sold_quantity
FROM   result AS r
GROUP  BY r.quarter
ORDER  BY total_sold_quantity; 


-- 9) Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 

WITH result_1
     AS (SELECT ds.channel
                AS
                   channel,
     Concat(Round(Sum(fs.sold_quantity * fp.gross_price) / 1000000, 2), " M")
        AS
     gross_sales_mln
     FROM   dim_customer AS ds
     JOIN fact_sales_monthly AS fs
       ON ds.customer_code = fs.customer_code
     JOIN fact_gross_price AS fp
       ON fp.fiscal_year = fs.fiscal_year
          AND fp.product_code = fs.product_code
     WHERE  fs.fiscal_year = 2021
     GROUP  BY ds.channel
     ORDER  BY gross_sales_mln),
     result_2
     AS (SELECT Concat(
        Round(Sum(fs.sold_quantity * fp.gross_price) / 1000000, 2), " M")
                AS
                total_gross_sales_mln
         FROM   dim_customer AS ds
                JOIN fact_sales_monthly AS fs
                  ON ds.customer_code = fs.customer_code
                JOIN fact_gross_price AS fp
                  ON fp.fiscal_year = fs.fiscal_year
                     AND fp.product_code = fs.product_code
         WHERE  fs.fiscal_year = 2021)
SELECT r1.channel,
       r1.gross_sales_mln,
Concat(Round(( r1.gross_sales_mln / r2.total_gross_sales_mln ) * 100, 2), "%")
AS percentage
FROM   result_1 AS r1,
       result_2 AS r2
ORDER  BY percentage; 


-- 10) Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?

WITH result
     AS (SELECT division,
                dp.product_code    AS product_code,
                product,
                variant,
                Sum(sold_quantity) AS total
         FROM   fact_sales_monthly AS fs
                JOIN dim_product AS dp
                  ON fs.product_code = dp.product_code
         WHERE  fs.fiscal_year = 2021
         GROUP  BY dp.product_code)
SELECT *
FROM  (SELECT division,
              r.product_code,
              product,
              variant,
              total,
              Dense_rank()
                OVER(
                  partition BY r.division
                  ORDER BY total DESC) AS rank_order
       FROM   result AS r) AS final_result
WHERE  final_result.rank_order < 4; 

