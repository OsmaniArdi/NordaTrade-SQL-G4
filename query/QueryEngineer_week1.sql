USE NordaTrade;
GO


-- Q1: German customers with high credit limit
SELECT
    c.customer_code AS CustomerCode,
    c.customer_name AS CustomerName,
    c.tier AS Tier,
    c.credit_limit AS CreditLimit,
    r.country AS Country,
    r.region_name AS Region
FROM dim_customers c
INNER JOIN dim_regions r ON c.region_id = r.region_id
WHERE r.country = 'Germany'
    AND c.tier = 'Gold'
    AND c.credit_limit > 50000
ORDER BY c.credit_limit DESC;

--------------------------------------------------

-- Q2: Orders with Pending or Partially Delivered status
SELECT 
    o.order_id,
    c.customer_name,
    o.order_date,
    o.status,
    SUM(li.quantity * li.unit_price) AS total_order_value
FROM dbo.fact_sales_orders o
JOIN dbo.dim_customers c 
    ON o.customer_id = c.customer_id
JOIN dbo.fact_order_line_items li 
    ON o.order_id = li.order_id
WHERE o.status IN ('Pending', 'Partially Delivered')
  AND DATEPART(QUARTER, o.order_date) = 3
  AND YEAR(o.order_date) = (
      SELECT MAX(YEAR(i.order_date))
      FROM dbo.fact_sales_orders i
      WHERE DATEPART(QUARTER, i.order_date) = 3
        AND i.status IN ('Pending', 'Partially Delivered')
  )
GROUP BY 
    o.order_id,
    c.customer_name,
    o.order_date,
    o.status;

--------------------------------------------------

-- Q3: Products with high margin
SELECT 
    product_id,
    product_name,
    unit_cost,
    list_price,
    ROUND((list_price - unit_cost) * 1.0 / NULLIF(list_price, 0) * 100, 1) AS margin_percent 
FROM dbo.dim_products
WHERE (list_price - unit_cost) * 1.0 / NULLIF(list_price, 0) > 0.3
ORDER BY margin_percent DESC;

--------------------------------------------------

-- Q4: Sales reps with no customer assignment
SELECT 
    r.sales_rep_id,
    r.full_name
FROM dbo.dim_sales_reps r
LEFT JOIN dbo.rep_customer_assignments rc
    ON r.sales_rep_id = rc.sales_rep_id
   AND (rc.end_date IS NULL OR rc.end_date >= DATEADD(MONTH, -6, GETDATE()))
WHERE rc.customer_id IS NULL;

--------------------------------------------------

-- Q5: Products with Pro / Plus / Max in the name
SELECT 
    product_id,
    product_name
FROM dbo.dim_products
WHERE product_name LIKE '%Pro%'
   OR product_name LIKE '%Plus%'
   OR product_name LIKE '%Max%';

--------------------------------------------------

-- Q6: Delayed orders
SELECT 
    o.order_id,
    o.order_date,
    o.shipping_date
FROM dbo.fact_sales_orders o
JOIN dbo.dim_customers c 
    ON o.customer_id = c.customer_id
JOIN dbo.dim_regions r 
    ON c.region_id = r.region_id
WHERE DATEDIFF(day, o.order_date, o.shipping_date) > 14
  AND r.country = 'Germany';
--------------------------------------------------
--------------------------------------------------

-- KPI 1: Gross Revenue
SELECT
    d.year AS Year,
    d.month AS Month,
    r.country AS Country,
    SUM(li.quantity * li.unit_price) AS GrossRevenue
FROM dbo.fact_order_line_items li
INNER JOIN dbo.fact_sales_orders o 
    ON li.order_id = o.order_id
INNER JOIN dbo.dim_customers c 
    ON o.customer_id = c.customer_id
INNER JOIN dbo.dim_regions r 
    ON c.region_id = r.region_id
INNER JOIN dbo.dim_date d 
    ON o.order_date = d.date_id
GROUP BY 
    d.year,
    d.month,
    r.country
ORDER BY 
    d.year,
    d.month,
    r.country;

--------------------------------------------------

-- KPI 2: Net Revenue
SELECT 
    d.year,
    d.quarter,
    p.category_id,
    SUM(li.quantity * li.unit_price * (1 - li.discount)) AS net_revenue
FROM dbo.fact_order_line_items li
JOIN dbo.fact_sales_orders o 
    ON li.order_id = o.order_id
JOIN dbo.dim_products p 
    ON li.product_id = p.product_id
JOIN dbo.dim_date d 
    ON o.order_date = d.date_id
GROUP BY d.year, d.quarter, p.category_id;

--------------------------------------------------

-- KPI 3: Gross Margin %
SELECT 
    p.category_id,
    SUM(
        li.quantity * li.unit_price * (1 - li.discount)
        - li.quantity * p.unit_cost
    ) * 1.0
    / NULLIF(SUM(li.quantity * li.unit_price * (1 - li.discount)), 0) * 100 AS gross_margin_percent
FROM dbo.fact_order_line_items li
JOIN dbo.dim_products p 
    ON li.product_id = p.product_id
GROUP BY p.category_id;

--------------------------------------------------

-- KPI 4: Average Order Value
SELECT 
    c.region_id,
    d.month,
    SUM(li.quantity * li.unit_price * (1 - li.discount)) * 1.0
    / COUNT(DISTINCT o.order_id) AS avg_order_value
FROM dbo.fact_order_line_items li
JOIN dbo.fact_sales_orders o 
    ON li.order_id = o.order_id
JOIN dbo.dim_customers c 
    ON o.customer_id = c.customer_id
JOIN dbo.dim_date d 
    ON o.order_date = d.date_id
GROUP BY c.region_id, d.month;

--------------------------------------------------

-- KPI 5: Return Rate by Product
SELECT 
    p.product_name,
    SUM(ISNULL(r.quantity, 0)) * 1.0 / NULLIF(SUM(li.quantity), 0) * 100 AS return_rate
FROM dbo.fact_order_line_items li
LEFT JOIN dbo.fact_returns r 
    ON li.line_item_id = r.line_item_id
JOIN dbo.dim_products p 
    ON li.product_id = p.product_id
GROUP BY p.product_name;
--------------------------------------------------

-- KPI 6: Quota Attainment %
SELECT 
    r.sales_rep_id,
    SUM(li.quantity * li.unit_price * (1 - li.discount)) * 1.0
    / NULLIF(SUM(q.quota_amount), 0) * 100 AS quota_attainment
FROM dbo.fact_sales_orders o
JOIN dbo.fact_order_line_items li 
    ON o.order_id = li.order_id
JOIN dbo.fact_quotas q 
    ON o.sales_rep_id = q.sales_rep_id
   AND o.order_date BETWEEN q.period_start AND q.period_end
JOIN dbo.dim_sales_reps r 
    ON o.sales_rep_id = r.sales_rep_id
GROUP BY r.sales_rep_id;

--------------------------------------------------

-- KPI 7: Customer Order Frequency
SELECT 
    c.customer_id,
    c.tier,
    COUNT(o.order_id) * 1.0 / NULLIF(COUNT(DISTINCT d.quarter), 0) AS order_frequency
FROM dbo.fact_sales_orders o
JOIN dbo.dim_customers c 
    ON o.customer_id = c.customer_id
JOIN dbo.dim_date d 
    ON o.order_date = d.date_id
GROUP BY c.customer_id, c.tier;

--------------------------------------------------

-- KPI 8: Top 10 Products by Revenue
SELECT TOP 10
    p.product_name,
    SUM(li.quantity * li.unit_price * (1 - li.discount)) AS total_revenue
FROM dbo.fact_order_line_items li
JOIN dbo.dim_products p 
    ON li.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_revenue DESC;

GO

-------------------------------------------------
-------------------------------------------------

-- HAVING 1: Low margin OR high return categories
SELECT 
    p.category_id,
    AVG((li.unit_price - p.unit_cost) * 1.0 / NULLIF(li.unit_price, 0)) * 100 AS avg_margin,
    SUM(ISNULL(r.quantity, 0)) * 1.0 / NULLIF(SUM(li.quantity), 0) * 100 AS return_rate
FROM dbo.fact_order_line_items li
JOIN dbo.dim_products p 
    ON li.product_id = p.product_id
LEFT JOIN dbo.fact_returns r 
    ON li.line_item_id = r.line_item_id
GROUP BY p.category_id
HAVING 
    AVG((li.unit_price - p.unit_cost) * 1.0 / NULLIF(li.unit_price, 0)) * 100 < 25
    OR SUM(ISNULL(r.quantity, 0)) * 1.0 / NULLIF(SUM(li.quantity), 0) * 100 > 10;

--------------------------------------------------

-- HAVING 2: Reps with revenue but low quota attainment
SELECT 
    r.sales_rep_id,
    SUM(li.quantity * li.unit_price * (1 - li.discount)) AS revenue,
    SUM(q.quota_amount) AS quota
FROM dbo.fact_sales_orders o
JOIN dbo.fact_order_line_items li 
    ON o.order_id = li.order_id
JOIN dbo.fact_quotas q 
    ON o.sales_rep_id = q.sales_rep_id
   AND o.order_date BETWEEN q.period_start AND q.period_end
JOIN dbo.dim_sales_reps r 
    ON o.sales_rep_id = r.sales_rep_id
GROUP BY r.sales_rep_id
HAVING 
    SUM(li.quantity * li.unit_price * (1 - li.discount)) >= 1500
    AND SUM(li.quantity * li.unit_price * (1 - li.discount)) 
        < 0.8 * SUM(q.quota_amount);

--------------------------------------------------

-- HAVING 3: High frequency but low value customers
SELECT 
    c.customer_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    AVG(li.quantity * li.unit_price) AS avg_order_value
FROM dbo.fact_sales_orders o
JOIN dbo.fact_order_line_items li 
    ON o.order_id = li.order_id
JOIN dbo.dim_customers c 
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id
HAVING  COUNT(DISTINCT o.order_id) > 20
  AND  AVG(li.quantity * li.unit_price) < 1000;



-- ===========================================================
-- TEAM MEMBERS QUERY
-- ===========================================================

-- Top Customers 
SELECT TOP 5
    c.customer_id,
    c.customer_name,
    SUM(li.quantity * li.unit_price * (1 - li.discount)) AS lifetime_value
FROM fact_sales_orders o
JOIN fact_order_line_items li 
    ON o.order_id = li.order_id
JOIN dim_customers c 
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY lifetime_value DESC;

-- Inactive Customers
SELECT 
    c.customer_id,
    c.customer_name,
    MAX(o.order_date) AS last_order_date
FROM dim_customers c
LEFT JOIN fact_sales_orders o 
    ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING MAX(o.order_date) < DATEADD(MONTH, -6, GETDATE())
    OR MAX(o.order_date) IS NULL;


-- Product with no sales

SELECT 
    p.product_id,
    p.product_name
FROM dim_products p
LEFT JOIN fact_order_line_items li 
    ON p.product_id = li.product_id
WHERE li.product_id IS NULL;


-- Top 5 sales rep

SELECT TOP 5
    r.sales_rep_id,
    r.full_name,
    SUM(li.quantity * li.unit_price * (1 - li.discount)) AS total_revenue
FROM fact_sales_orders o
JOIN fact_order_line_items li 
    ON o.order_id = li.order_id
JOIN dim_sales_reps r 
    ON o.sales_rep_id = r.sales_rep_id
GROUP BY r.sales_rep_id, r.full_name
ORDER BY total_revenue DESC;

--------------------------------------------------

-- Full Order Summary
SELECT
    o.order_id,
    o.order_date,
    o.shipping_date,
    o.status,
    c.customer_id,
    c.customer_code,
    c.customer_name,
    c.tier AS customer_tier,
    r.region_id,
    r.country,
    r.region_name,
    r.territory,
    sr.sales_rep_id,
    sr.employee_code,
    sr.full_name AS sales_rep_name,
    li.line_item_id,
    li.product_id,
    p.sku,
    p.product_name,
    p.category_id,
    li.quantity,
    li.unit_price,
    li.discount,
    li.total_price,
    li.discount_amount,
    li.net_price
FROM dbo.fact_sales_orders o
JOIN dbo.dim_customers c 
    ON o.customer_id = c.customer_id
JOIN dbo.dim_regions r 
    ON c.region_id = r.region_id
JOIN dbo.dim_sales_reps sr 
    ON o.sales_rep_id = sr.sales_rep_id
JOIN dbo.fact_order_line_items li 
    ON o.order_id = li.order_id
JOIN dbo.dim_products p 
    ON li.product_id = p.product_id;

--------------------------------------------------

-- Orphan Detection (customers with no orders)
SELECT
    c.customer_id,
    c.customer_code,
    c.customer_name,
    c.tier,
    c.credit_limit,
    r.country,
    r.region_name
FROM dbo.dim_customers c
LEFT JOIN dbo.fact_sales_orders o 
    ON c.customer_id = o.customer_id
LEFT JOIN dbo.dim_regions r 
    ON c.region_id = r.region_id
WHERE o.order_id IS NULL
ORDER BY c.customer_id;

--------------------------------------------------

-- Rep-Customer Mismatch
SELECT
    o.order_id,
    o.order_date,
    c.customer_id,
    c.customer_name,
    o.sales_rep_id AS order_sales_rep_id,
    osr.full_name AS order_sales_rep_name,
    a.sales_rep_id AS assigned_sales_rep_id,
    asr.full_name AS assigned_sales_rep_name
FROM dbo.fact_sales_orders o
JOIN dbo.dim_customers c 
    ON o.customer_id = c.customer_id
LEFT JOIN dbo.rep_customer_assignments a
    ON o.customer_id = a.customer_id
   AND o.order_date >= a.start_date
   AND (a.end_date IS NULL OR o.order_date <= a.end_date)
LEFT JOIN dbo.dim_sales_reps osr 
    ON o.sales_rep_id = osr.sales_rep_id
LEFT JOIN dbo.dim_sales_reps asr 
    ON a.sales_rep_id = asr.sales_rep_id
WHERE a.sales_rep_id IS NULL
   OR o.sales_rep_id <> a.sales_rep_id
ORDER BY o.order_id;

--------------------------------------------------

-- Revenue by Geography
SELECT
    r.country,
    r.region_name,
    r.territory,
    SUM(li.net_price) AS net_revenue
FROM dbo.fact_sales_orders o
JOIN dbo.dim_customers c 
    ON o.customer_id = c.customer_id
JOIN dbo.dim_regions r 
    ON c.region_id = r.region_id
JOIN dbo.fact_order_line_items li 
    ON o.order_id = li.order_id
GROUP BY 
    r.country,
    r.region_name,
    r.territory
ORDER BY 
    r.country,
    r.region_name,
    r.territory;

--------------------------------------------------

-- Product Cost vs Actual Sell Price
SELECT
    li.line_item_id,
    li.order_id,
    li.product_id,
    p.product_name,
    li.quantity,
    p.unit_cost,
    li.unit_price,
    li.discount,
    li.net_price,
    li.quantity * p.unit_cost AS total_cost,
    li.net_price - (li.quantity * p.unit_cost) AS realized_margin_value,
    (li.net_price - (li.quantity * p.unit_cost)) * 1.0 / NULLIF(li.net_price, 0) AS realized_margin_pct
FROM dbo.fact_order_line_items li
JOIN dbo.dim_products p 
    ON li.product_id = p.product_id
ORDER BY li.line_item_id;

--------------------------------------------------

-- Unordered Active Products in Last 12 Months
SELECT
    p.product_id,
    p.sku,
    p.product_name,
    p.category_id,
    p.is_active
FROM dbo.dim_products p
LEFT JOIN dbo.fact_order_line_items li 
    ON p.product_id = li.product_id
LEFT JOIN dbo.fact_sales_orders o 
    ON li.order_id = o.order_id
   AND o.order_date >= DATEADD(MONTH, -12, CAST(GETDATE() AS DATE))
WHERE p.is_active = 1
GROUP BY
    p.product_id,
    p.sku,
    p.product_name,
    p.category_id,
    p.is_active
HAVING COUNT(o.order_id) = 0
ORDER BY p.product_id;
