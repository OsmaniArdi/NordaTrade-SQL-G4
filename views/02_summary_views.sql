USE NordaTrade;
GO

DROP VIEW IF EXISTS vw_summary_sales;
DROP VIEW IF EXISTS vw_summary_customer;
DROP VIEW IF EXISTS vw_summary_product;
DROP VIEW IF EXISTS vw_summary_rep_period;
DROP VIEW IF EXISTS vw_summary_product_returns;
DROP VIEW IF EXISTS vw_summary_quota_monthly;
DROP VIEW IF EXISTS vw_summary_returns;
DROP VIEW IF EXISTS vw_summary_sales_category;
GO

CREATE VIEW vw_summary_sales AS
SELECT 
    country,
    region_name,
    DATETRUNC(MONTH, order_date) AS month,
    SUM(net_price) AS total_revenue,
    SUM(total_cost) AS total_cost,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(quantity) AS units_sold,
    SUM(net_price) - SUM(total_cost) AS gross_margin
FROM vw_base_sales
GROUP BY 
    country, 
    region_name, 
    DATETRUNC(MONTH, order_date)
GO

CREATE VIEW vw_summary_sales_category AS
SELECT 
    category_name,
    country,
    DATETRUNC(MONTH, order_date) AS month,
    SUM(quantity) AS units_sold,
    SUM(net_price) AS total_revenue,
    SUM(total_cost) AS total_cost,
    SUM(net_price) - SUM(total_cost) AS gross_margin
FROM vw_base_sales
GROUP BY 
    category_name,
    country,
    DATETRUNC(MONTH, order_date);
GO

CREATE VIEW vw_summary_customer AS
SELECT 
    customer_id,
    customer_name,
    SUM(net_price) AS lifetime_revenue,
    COUNT(DISTINCT order_id) AS total_orders,
    MAX(order_date) AS last_order_date,
    SUM(net_price) * 1.0 / NULLIF(COUNT(DISTINCT order_id),0) AS avg_order_value
FROM vw_base_sales
GROUP BY customer_id, customer_name;
GO

CREATE VIEW vw_summary_product AS
SELECT 
    product_id,
    product_name,
    category_name,
    SUM(quantity) AS units_sold,
    SUM(net_price) AS revenue,
    SUM(total_cost) AS cost,
    (SUM(net_price) - SUM(total_cost)) * 100.0 / NULLIF(SUM(net_price),0) AS margin_pct
FROM vw_base_sales
GROUP BY product_id, product_name, category_name;
GO

CREATE VIEW vw_summary_product_returns AS
SELECT 
    bs.product_id,
    SUM(bs.quantity) AS total_units_sold,
    SUM(br.returned_quantity) AS total_units_returned
FROM vw_base_sales bs
LEFT JOIN vw_base_returns br
    ON bs.order_id = br.order_id
    AND bs.product_id = br.product_id
GROUP BY bs.product_id;
GO

CREATE VIEW vw_summary_returns AS
SELECT 
    bs.category_name,
    bs.country,
    br.reason,
    DATETRUNC(MONTH, br.return_date) AS month,
    COUNT(*) AS return_count,
    SUM(br.returned_quantity) AS total_units_returned,
    SUM(COALESCE(br.return_amount,0)) AS total_return_value
FROM vw_base_returns br
JOIN vw_base_sales bs 
    ON br.order_id = bs.order_id 
    AND br.product_id = bs.product_id
GROUP BY 
    bs.category_name,
    bs.country,
    br.reason,
    DATETRUNC(MONTH, br.return_date);
GO

CREATE VIEW vw_summary_rep_period AS
SELECT 
    bs.sales_rep_id,
    bs.sales_rep_name,
    bs.region_name,
    d.year,
    d.quarter,
    SUM(bs.net_price) AS revenue,
    COUNT(DISTINCT bs.customer_id) AS customer_count
FROM vw_base_sales bs
JOIN dim_date d 
    ON bs.order_date = d.date_id
GROUP BY 
    bs.sales_rep_id,
    bs.sales_rep_name,
    bs.region_name,
    d.year,
    d.quarter;
GO

CREATE VIEW vw_summary_quota_monthly AS
SELECT 
    sales_rep_id,
    DATETRUNC(MONTH, period_start) AS month,
    quota_amount
FROM fact_quotas;
GO
