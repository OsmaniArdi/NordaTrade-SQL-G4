USE NordaTrade;
GO

DROP VIEW IF EXISTS dbo.vw_sales_executive_summary;
DROP VIEW IF EXISTS dbo.vw_customer_360;
DROP VIEW IF EXISTS dbo.vw_product_performance;
DROP VIEW IF EXISTS dbo.vw_rep_performance_scorecard;
DROP VIEW IF EXISTS dbo.vw_monthly_trend;
DROP VIEW IF EXISTS dbo.vw_returns_analysis;
GO

-- Executive Summary
CREATE VIEW vw_sales_executive_summary AS
SELECT 
    s.country,
    s.region_name,
    s.month,
    SUM(s.total_revenue) AS total_revenue,
    SUM(s.gross_margin) AS gross_margin,
    SUM(s.order_count) AS order_count,
    SUM(s.total_revenue) / NULLIF(SUM(s.order_count),0) AS avg_order_value,
    SUM(q.quota_amount) AS total_quota,
    SUM(s.total_revenue) * 100.0 / NULLIF(SUM(q.quota_amount),0) AS quota_attainment_pct
FROM vw_summary_sales s
LEFT JOIN vw_summary_quota_quarter q
    ON YEAR(s.month) = q.year
    AND DATEPART(QUARTER, s.month) = q.quarter
GROUP BY 
    s.country,
    s.region_name,
    s.month;
GO

-- Customer 360
CREATE VIEW vw_customer_360 AS
WITH rfm AS (
    SELECT 
        sc.*,
        DATEDIFF(DAY, sc.last_order_date, MAX(sc.last_order_date) OVER()) AS recency
    FROM vw_summary_customer sc
),
scored AS (
    SELECT *,
        CASE WHEN recency <= 30 THEN 5
             WHEN recency <= 90 THEN 4
             WHEN recency <= 180 THEN 3
             WHEN recency <= 365 THEN 2
             ELSE 1 END AS r_score,

        CASE WHEN total_orders >= 10 THEN 5
             WHEN total_orders >= 5 THEN 4
             WHEN total_orders >= 3 THEN 3
             WHEN total_orders >= 1 THEN 2
             ELSE 1 END AS f_score,

        CASE WHEN lifetime_revenue >= 5000 THEN 5
             WHEN lifetime_revenue >= 2000 THEN 4
             WHEN lifetime_revenue >= 1000 THEN 3
             ELSE 2 END AS m_score
    FROM rfm
),
latest_rep AS (
    SELECT 
        rca.customer_id,
        rca.sales_rep_id,
        ROW_NUMBER() OVER (
            PARTITION BY rca.customer_id 
            ORDER BY rca.start_date DESC
        ) AS rn
    FROM rep_customer_assignments rca
)
SELECT 
    s.customer_id,
    s.customer_name,
    s.lifetime_revenue,
    s.total_orders AS order_frequency,
    s.last_order_date,
    s.avg_order_value,
    r.return_rate_pct,
    rep.full_name AS assigned_rep,
    s.r_score,
    s.f_score,
    s.m_score,
    CASE 
        WHEN s.r_score >=4 AND s.f_score >=4 THEN 'Champions'
        WHEN s.f_score >=4 THEN 'Loyal'
        WHEN s.r_score <=2 AND s.f_score >=3 THEN 'At Risk'
        WHEN s.r_score =1 THEN 'Lost'
        ELSE 'New'
    END AS rfm_segment
FROM scored s
LEFT JOIN vw_summary_customer_returns r 
    ON s.customer_id = r.customer_id
LEFT JOIN latest_rep lr 
    ON s.customer_id = lr.customer_id AND lr.rn = 1
LEFT JOIN dim_sales_reps rep 
    ON lr.sales_rep_id = rep.sales_rep_id;
GO

-- Product Performance
CREATE VIEW vw_product_performance AS
SELECT 
    sp.product_id,
    sp.sku, 
    sp.product_name,
    sp.category_name,
    sp.units_sold,
    sp.revenue AS net_revenue,
    sp.margin_pct AS gross_margin_pct,
    pr.total_units_returned * 100.0 
        / NULLIF(pr.total_units_sold,0) AS return_rate_pct,
    RANK() OVER (
        PARTITION BY sp.category_name 
        ORDER BY sp.revenue DESC
    ) AS category_rank

FROM vw_summary_product sp
LEFT JOIN vw_summary_product_returns pr 
    ON sp.product_id = pr.product_id;
GO

-- Rep Scorecard
CREATE VIEW vw_rep_performance_scorecard AS
WITH current_period AS (
    SELECT 
        YEAR(GETDATE()) AS current_year,
        DATEPART(QUARTER, GETDATE()) AS current_quarter
)
SELECT 
    r.sales_rep_id,
    r.sales_rep_name,
    r.region_name,
    r.year,
    r.quarter,
    r.revenue,
    r.customer_count,
    SUM(CASE 
        WHEN r.year = cp.current_year 
        THEN r.revenue 
    END) OVER (PARTITION BY r.sales_rep_id) AS revenue_ytd,
    SUM(CASE 
        WHEN r.year = cp.current_year 
         AND r.quarter = cp.current_quarter 
        THEN r.revenue 
    END) OVER (PARTITION BY r.sales_rep_id) AS revenue_qtd,
    q.quota_amount,
    r.revenue * 100.0 / NULLIF(q.quota_amount,0) AS attainment_pct,
    RANK() OVER (
        PARTITION BY r.region_name, r.year, r.quarter
        ORDER BY r.revenue DESC
    ) AS rank_in_region
FROM vw_summary_rep_period r
CROSS JOIN current_period cp
LEFT JOIN vw_summary_quota_quarter q
    ON r.sales_rep_id = q.sales_rep_id
    AND r.year = q.year
    AND r.quarter = q.quarter
GO

-- Monthly Trend
CREATE VIEW vw_monthly_trend AS
SELECT 
    country,
    month,
    total_revenue,
    order_count,
    total_revenue * 1.0 / NULLIF(order_count,0) AS avg_order_value,
    LAG(total_revenue) OVER (PARTITION BY country ORDER BY month) AS prev_month_revenue,
    (total_revenue - LAG(total_revenue) OVER (PARTITION BY country ORDER BY month)) * 100.0
        / NULLIF(LAG(total_revenue) OVER (PARTITION BY country ORDER BY month),0) AS mom_change_pct
FROM vw_summary_sales;
GO

-- Returns Analysis
CREATE VIEW vw_returns_analysis AS
SELECT 
    r.category_name,
    r.country,
    r.reason,
    r.month,
    r.return_count,
    r.total_units_returned,
    s.units_sold,
    r.total_units_returned * 100.0 / NULLIF(s.units_sold,0) AS return_rate_pct,
    r.total_return_value
FROM vw_summary_returns r
LEFT JOIN vw_summary_sales_category s
    ON r.category_name = s.category_name
    AND r.country = s.country
    AND r.month = s.month;
GO
