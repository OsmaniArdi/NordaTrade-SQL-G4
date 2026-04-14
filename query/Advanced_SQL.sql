USE NordaTrade;


-- -----------------------------------------------------
-- Customer RFM Segmentation
-- -----------------------------------------------------
WITH customer_orders AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        MAX(o.order_date) AS last_order_date,
        COUNT(o.order_id) AS frequency,
        COALESCE(SUM(li.net_price), 0) AS monetary
    FROM dim_customers c
    LEFT JOIN fact_sales_orders o 
        ON c.customer_id = o.customer_id
    LEFT JOIN fact_order_line_items li 
        ON o.order_id = li.order_id
    GROUP BY c.customer_id, c.customer_name
),
rfm AS (
    SELECT *,
        DATEDIFF(DAY, last_order_date, (SELECT MAX(order_date) FROM fact_sales_orders)) AS recency
    FROM customer_orders
),
scored AS (
    SELECT *,
        CASE 
            WHEN recency <= 30 THEN 5
            WHEN recency <= 90 THEN 4
            WHEN recency <= 180 THEN 3
            WHEN recency <= 365 THEN 2
            ELSE 1
        END AS r_score,
        CASE 
            WHEN frequency >= 10 THEN 5
            WHEN frequency >= 5 THEN 4
            WHEN frequency >= 3 THEN 3
            WHEN frequency >= 1 THEN 2
            ELSE 1
        END AS f_score,
        CASE 
            WHEN monetary >= 5000 THEN 5
            WHEN monetary >= 2000 THEN 4
            WHEN monetary >= 1000 THEN 3
            WHEN monetary > 0 THEN 2
            ELSE 1
        END AS m_score
    FROM rfm
)
SELECT *,
    CASE 
		WHEN r_score >=4 AND f_score >=4 THEN 'Champions' 
		WHEN f_score >=4 THEN 'Loyal' 
		WHEN r_score <=2 AND f_score >=3 THEN 'At Risk' 
		WHEN r_score =1 THEN 'Lost' 
		ELSE 'New' 
	END AS segment
FROM scored;

-- ------------------------------------------------------
-- Month-over-Month Revenue
-- ------------------------------------------------------
WITH monthly_revenue AS (
    SELECT 
        r.country,
        d.year,
        d.month,
        SUM(li.net_price) AS revenue
    FROM fact_sales_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    JOIN dim_regions r ON c.region_id = r.region_id
    JOIN dim_date d ON o.order_date = d.date_id
    JOIN fact_order_line_items li ON o.order_id = li.order_id
    GROUP BY r.country, d.year, d.month
)
SELECT *,
    LAG(revenue) OVER (PARTITION BY country ORDER BY year, month) AS prev_revenue,
    revenue - LAG(revenue) OVER (PARTITION BY country ORDER BY year, month) AS change,
    (revenue - LAG(revenue) OVER (PARTITION BY country ORDER BY year, month)) 
        / LAG(revenue) OVER (PARTITION BY country ORDER BY year, month) AS pct_change
FROM monthly_revenue;

-- ----------------------------------------------
-- Running Total by Quarter
-- ----------------------------------------------
SELECT 
    r.region_name,
    d.year,
    d.quarter,
    o.order_id,
    SUM(li.net_price) AS order_revenue,
    SUM(SUM(li.net_price)) OVER (
        PARTITION BY r.region_name, d.year, d.quarter
        ORDER BY o.order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM fact_sales_orders o
JOIN dim_sales_reps sr ON o.sales_rep_id = sr.sales_rep_id
JOIN dim_regions r ON sr.region_id = r.region_id
JOIN dim_date d ON o.order_date = d.date_id
JOIN fact_order_line_items li ON o.order_id = li.order_id
GROUP BY r.region_name, d.year, d.quarter, o.order_id, o.order_date;

-- -----------------------------------------------
-- Rank Sales Reps Within Region
-- -----------------------------------------------
WITH last_quarter AS (
    SELECT TOP 1
        d.year,
        d.quarter
    FROM dim_date d
    WHERE d.date_id < GETDATE()
    GROUP BY d.year, d.quarter
    ORDER BY d.year DESC, d.quarter DESC
),
rep_sales AS (
    SELECT 
        sr.sales_rep_id,
        sr.full_name,
        r.region_name,
        SUM(li.net_price) AS revenue,
        MAX(q.quota_amount) AS quota
    FROM dim_sales_reps sr
    JOIN dim_regions r ON sr.region_id = r.region_id
    LEFT JOIN fact_sales_orders o ON sr.sales_rep_id = o.sales_rep_id
    LEFT JOIN dim_date d ON o.order_date = d.date_id
    LEFT JOIN fact_order_line_items li ON o.order_id = li.order_id
    LEFT JOIN fact_quotas q ON sr.sales_rep_id = q.sales_rep_id
    JOIN last_quarter lq 
        ON d.year = lq.year AND d.quarter = lq.quarter
    GROUP BY sr.sales_rep_id, sr.full_name, r.region_name
),
calc AS (
    SELECT *,
        revenue * 1.0 / quota AS attainment
    FROM rep_sales
)
SELECT *,
    RANK() OVER (PARTITION BY region_name ORDER BY attainment DESC) AS rank_in_region,
    AVG(attainment) OVER (PARTITION BY region_name) AS region_avg
FROM calc;

-- ------------------------------------------
-- Top Customer per Country
-- ------------------------------------------
WITH customer_revenue AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        r.country,
        c.tier,
        SUM(li.net_price) AS revenue
    FROM dim_customers c
    JOIN dim_regions r ON c.region_id = r.region_id
    JOIN fact_sales_orders o ON c.customer_id = o.customer_id
    JOIN fact_order_line_items li ON o.order_id = li.order_id
    WHERE YEAR(o.order_date) = (
        SELECT YEAR(MAX(order_date)) FROM fact_sales_orders
    )
    GROUP BY c.customer_id, c.customer_name, r.country, c.tier
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY country ORDER BY revenue DESC) AS rn
    FROM customer_revenue
)
SELECT * 
FROM ranked
WHERE rn = 1;

-- ----------------------------------------------------------------------------
-- Products Never Ordered in High-Revenue Regions
-- ----------------------------------------------------------------------------
SELECT p.product_id, p.product_name
FROM dim_products p
WHERE NOT EXISTS (
    SELECT 1
    FROM fact_order_line_items li
    JOIN fact_sales_orders o ON li.order_id = o.order_id
    JOIN dim_customers c ON o.customer_id = c.customer_id
    JOIN dim_regions r ON c.region_id = r.region_id
    WHERE li.product_id = p.product_id
    AND r.region_id IN (
        SELECT r2.region_id
        FROM fact_sales_orders o2
        JOIN dim_customers c2 ON o2.customer_id = c2.customer_id
        JOIN dim_regions r2 ON c2.region_id = r2.region_id
        JOIN fact_order_line_items li2 ON o2.order_id = li2.order_id
        WHERE o2.order_date >= DATEADD(YEAR, -1, GETDATE())
        GROUP BY r2.region_id
        HAVING SUM(li2.net_price) > 1000000
    )
);


-- ------------------------------------------------------------------------
-- TEAM QUERY
-- ------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- Top 3 Customers per Country

WITH customer_revenue AS (
    SELECT
        c.customer_id,
        c.customer_name,
        r.country,
        SUM(li.net_price) AS revenue
    FROM dim_customers c
    JOIN dim_regions r ON c.region_id = r.region_id
    JOIN fact_sales_orders o ON c.customer_id = o.customer_id
    JOIN fact_order_line_items li ON o.order_id = li.order_id
    GROUP BY c.customer_id, c.customer_name, r.country
)
SELECT
    customer_id,
    customer_name,
    country,
    revenue
FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY country ORDER BY revenue DESC) AS rn
    FROM customer_revenue
) x
WHERE rn <= 3
ORDER BY country, revenue DESC;


-- ----------------------------------------------------------------------------
-- Monthly Revenue Trend by Country

WITH monthly_revenue AS (
    SELECT
        r.country,
        d.year,
        d.month,
        SUM(li.net_price) AS revenue
    FROM fact_sales_orders o
    JOIN dim_customers c ON o.customer_id = c.customer_id
    JOIN dim_regions r ON c.region_id = r.region_id
    JOIN dim_date d ON o.order_date = d.date_id
    JOIN fact_order_line_items li ON o.order_id = li.order_id
    GROUP BY r.country, d.year, d.month
)
SELECT
    country,
    year,
    month,
    revenue,
    LAG(revenue) OVER (PARTITION BY country ORDER BY year, month) AS prev_revenue,
    revenue - LAG(revenue) OVER (PARTITION BY country ORDER BY year, month) AS diff
FROM monthly_revenue
ORDER BY country, year, month;

