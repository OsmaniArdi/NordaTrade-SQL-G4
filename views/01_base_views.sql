USE NordaTrade;
GO

DROP VIEW IF EXISTS vw_base_sales;
DROP VIEW IF EXISTS vw_base_returns;
GO

CREATE VIEW vw_base_sales AS
SELECT 
    o.order_id,
    o.order_date,
    c.customer_id,
    c.customer_name,
    c.tier,
    r.country,
    r.region_name,
    rep.sales_rep_id,
    rep.full_name AS sales_rep_name,
    p.product_id,
	p.sku,
    p.product_name,
    cat.category_name,
    li.quantity,
    li.unit_price,
    li.discount,
    li.total_price,
    li.net_price,
    (li.quantity * p.unit_cost) AS total_cost
FROM fact_sales_orders o
JOIN fact_order_line_items li ON o.order_id = li.order_id
JOIN dim_customers c ON o.customer_id = c.customer_id
JOIN dim_products p ON li.product_id = p.product_id
JOIN dim_categories cat ON p.category_id = cat.category_id
JOIN dim_sales_reps rep ON o.sales_rep_id = rep.sales_rep_id
JOIN dim_regions r ON c.region_id = r.region_id;
GO

CREATE VIEW vw_base_returns AS
SELECT 
    r.return_id,
    r.return_date,
    li.line_item_id,
    li.product_id,
    li.order_id,
    li.quantity AS sold_quantity,
    r.quantity AS returned_quantity,
    r.return_amount,
    r.reason
FROM fact_returns r
JOIN fact_order_line_items li 
    ON r.line_item_id = li.line_item_id;
GO
