# KNOWING THE DATA
#show tables;
select * from dim_customer;
-- this table contains columns such as cust_code, customer, Platform, channel, Market, Sub Zone, Region. 
select * from dim_product;
-- This table consist of prod_code, division, segment, category, product, variant
select * from fact_gross_price;
-- The table includes product code, fiscal_year and gorss_price columns.
select * from fact_manufacturing_cost;
-- It includes the prod_code, cost_year, manufacturing_cost columns
select * from fact_pre_invoice_deductions;
-- This includes cust_code,fiscal_year,pre_invoice_discount_pct
select * from fact_sales_monthly;
-- It consists of date,prod_code,cust_code,sold_qnty,fiscal_year
 
 -- THE FIRST THING WE NEED TO SEARCH IS FOR THE SUB ZONES WHERE THE PRODUCT IS SOLD IN THE APAC REGION. 
 
 
 
# 1. The list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
select market from dim_customer
where customer = 'Atliq Exclusive' and region = 'APAC'
order by market;



# 2.  The percentage of unique product increase in 2021 vs. 2020.
create table dim_date as (select date,fiscal_year,product_code,customer_code from fact_sales_monthly);
select * from dim_date;

with product_count_2020 as 
(select count( distinct product_code) 'unique_product_2020'
 from dim_product
join dim_date using (product_code)
where fiscal_year='2020'),

product_count_2021 as
(select count(distinct product_code) as unique_product_2021
 from dim_product
join dim_date using (product_code)
where fiscal_year='2021')

select unique_product_2020,unique_product_2021,
concat(round((unique_product_2021 - unique_product_2020)*100/unique_product_2020,2),"%") as percentage_change from unique_product_2020,unique_product_2021;



#3. A report with all the unique product counts for each segment and sort them in descending order of product counts.
select segment,count(distinct product_code) product_count from dim_product
group by segment
order by product_count desc;



 #4.  Segment that has the most increase in unique products in 2021 vs 2020.
WITH fy20 AS(
        SELECT segment, COUNT(DISTINCT(fm.product_code)) AS seg20 FROM fact_sales_monthly fm
            JOIN dim_product dp
            ON fm.product_code = dp.product_code
            WHERE fiscal_year = 2020
            GROUP BY dp.segment),
            
    fy21 AS(
        SELECT segment, COUNT(DISTINCT(fm.product_code)) AS seg21 FROM fact_sales_monthly fm
            JOIN dim_product dp
            ON fm.product_code = dp.product_code
            WHERE fiscal_year = 2021
            GROUP BY dp.segment)
            
SELECT fy20.segment, seg20 AS product_count_2020, seg21 AS product_count_2021, seg21-seg20 AS difference FROM fy20
    JOIN fy21
    ON fy20.segment = fy21.segment
    ORDER BY difference DESC;
    
    
    
    #5.Get the products that have the highest and lowest manufacturing costs.
     with product_count_2020 as 
     (
     select segment,count(distinct product_code) fy_2020 from dim_product
     join dim_date using (product_code)
     where fiscal_year=2020
     group by segment
     order by fy_2020
     ),
     product_cnt_2021 as 
     (select segment,count(distinct product_code) fy_2021 from dim_product
     join dim_date using (product_code)
     where fiscal_year=2021
     group by segment
     order by fy_2021)
     select fy_2020,fy_2021,segment, fy_2021 - fy_2020 difference from product_count_2020, product_cnt_2021;
     
     
     
     #6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the
#    fiscal year 2021 and in the Indian market.
    select customer,c.customer_code,concat(round(avg(pre_invoice_discount_pct)*100,2),"%") avg_disc_pcnt from dim_customer c 
    join dim_date d using (customer_code)
	join fact_pre_invoice_deductions p 
    on p.customer_code = c.customer_code 
    and d.fiscal_year = p.fiscal_year
    where market = 'India' and d.fiscal_year = 2021
    group by c.customer_code,customer
    order by avg(pre_invoice_discount_pct) desc;
    
    
    
    #7.  Complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month.

    #select * from fact_gross_price;
    #select * from fact_sales_monthly 
    select dc.customer,month(date) 'month',fiscal_year 'year', sum(round(gross_price*sold_quantity,2)) gross_sales_amount from fact_gross_price gp
    join fact_sales_monthly fm using (product_code,fiscal_year)
    join dim_customer dc using (customer_code)
    where dc.customer='Atliq Exclusive'
    group by month(date) ,fiscal_year;
    
    
    
    #8.  Quarter of 2020 which got the maximum total_sold_quantity.
    
    select quarter(date) as 'Quarter', sum(sold_quantity) total_sold_qnty
    from  fact_sales_monthly
    where fiscal_year=2020
    group by 'Quarter'
    order by total_sold_qnty;
    
    SELECT 
    quarter(date) AS 'Quarter', 
    SUM(sold_quantity) AS total_sold_qnty
FROM 
    fact_sales_monthly
WHERE 
    fiscal_year = 2020
GROUP BY 
    Quarter
ORDER BY 
    total_sold_qnty desc;


#9. Channel that helped the company to bring more gross sales in the fiscal year 2021 and the percentage of contribution.

with cte as(
select channel,sum(round((sold_quantity * gross_price)/1000000, 2)) gross_sales_mln
 from dim_customer c
 join fact_sales_monthly fm
 using (customer_code)
 join fact_gross_price p
 on fm.product_code = p.product_code
 and fm.fiscal_year = p.fiscal_year
 where fm.fiscal_year=2021
 group by channel
 order by c.channel desc)
 select channel, gross_sales_mln,concat(round(100*gross_sales_mln/sum(gross_sales_mln) over() ,2),"%") percentage
 from cte 
 group by channel;


#10  Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021.

WITH product_table AS (
        SELECT dp.division, fm.product_code, dp.product, SUM(fm.sold_quantity) AS total_sold_quantity FROM fact_sales_monthly fm
            JOIN dim_product dp
            ON fm.product_code = dp.product_code
            WHERE fm.fiscal_year = 2021
            GROUP BY fm.product_code, dp.division, dp.product),

    rank_table AS (
        SELECT *, RANK () OVER (PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order FROM product_table)

SELECT * from rank_table
    WHERE rank_order < 4;
    