USE NordaTrade;
GO

-- =============================================================
-- RERUN SAFE
-- =============================================================
DELETE FROM fact_returns;
DELETE FROM fact_order_line_items;
DELETE FROM fact_sales_orders;
DELETE FROM fact_quotas;
DELETE FROM rep_customer_assignments;
DELETE FROM product_promotions;
DELETE FROM dim_products;
DELETE FROM dim_categories;
DELETE FROM dim_customers;
DELETE FROM dim_sales_reps;
DELETE FROM dim_regions;
DELETE FROM dim_date;

DBCC CHECKIDENT ('fact_returns', RESEED, 0);
DBCC CHECKIDENT ('fact_order_line_items', RESEED, 0);
DBCC CHECKIDENT ('fact_sales_orders', RESEED, 0);
DBCC CHECKIDENT ('fact_quotas', RESEED, 0);
DBCC CHECKIDENT ('rep_customer_assignments', RESEED, 0);
DBCC CHECKIDENT ('product_promotions', RESEED, 0);
DBCC CHECKIDENT ('dim_products', RESEED, 0);
DBCC CHECKIDENT ('dim_categories', RESEED, 0);
DBCC CHECKIDENT ('dim_customers', RESEED, 0);
DBCC CHECKIDENT ('dim_sales_reps', RESEED, 0);
DBCC CHECKIDENT ('dim_regions', RESEED, 0);

-- TEMP TABLES
DROP TABLE IF EXISTS #cats;
DROP TABLE IF EXISTS #prod_stage;
DROP TABLE IF EXISTS #rep_stage;
DROP TABLE IF EXISTS #cust_stage;
DROP TABLE IF EXISTS #prod_idx;
DROP TABLE IF EXISTS #line_stage;
DROP TABLE IF EXISTS #promo_prods;


-- =========================
-- 1. DIM_DATE  (2022-01-01 → 2026-12-31)
-- =========================
INSERT INTO dim_date (date_id, year, quarter, month, month_name,
                      week_number, day_of_week, day_name, is_business_day)
SELECT d,
       YEAR(d), DATEPART(QUARTER,d), MONTH(d), DATENAME(MONTH,d),
       DATEPART(WEEK,d), DATEPART(WEEKDAY,d), DATENAME(WEEKDAY,d),
       CASE WHEN DATENAME(WEEKDAY,d) IN ('Saturday','Sunday') THEN 0 ELSE 1 END
FROM (
    SELECT TOP (365*5 + 2)
        DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1, '2022-01-01') AS d
    FROM sys.objects CROSS JOIN sys.objects s2
) t
WHERE d < '2027-01-01';
GO


-- =========================
-- 2. DIM_REGIONS
-- =========================
INSERT INTO dim_regions (country, region_name, territory) VALUES
('Germany',     'Bavaria',       'South'),
('Germany',     'Hesse',         'Central'),
('France',      'Ile-de-France', 'Central'),
('France',      'Provence',      'South'),
('Austria',     'Vienna',        'East'),
('Austria',     'Tyrol',         'West'),
('Switzerland', 'Zurich',        'North'),
('Switzerland', 'Geneva',        'West'),
('Netherlands', 'North Holland', 'North'),
('Netherlands', 'South Holland', 'South'),
('Germany',     'Saxony',        'East'),
('France',      'Normandy',      'North'),
('Austria',     'Salzburg',      'Central'),
('Switzerland', 'Bern',          'Central'),
('Netherlands', 'Utrecht',       'Central'),
('Germany',     'Hamburg',       'North'),
('France',      'Brittany',      'West'),
('Austria',     'Styria',        'South'),
('Switzerland', 'Basel',         'North'),
('Netherlands', 'Limburg',       'South');
GO


-- =========================
-- 3. DIM_CATEGORIES 
-- =========================
INSERT INTO dim_categories (category_name, parent_category_id) VALUES
('Technology', NULL), ('Office Supplies', NULL), ('Industrial Equipment', NULL);

INSERT INTO dim_categories (category_name, parent_category_id) VALUES
('Laptops',1),('Desktops',1),('Printers',1),('Accessories',1),
('Paper',2),('Writing',2),('Furniture',2),
('Tools',3),('Machines',3),('Safety',3);

INSERT INTO dim_categories (category_name, parent_category_id) VALUES
('Gaming Laptops',4),('Business Laptops',4),
('Office Chairs',9),('Office Tables',9),
('Hand Tools',10),('Power Tools',10);
GO


-- =========================
-- 4. DIM_PRODUCTS
-- =========================
DECLARE @NumProducts INT = 200;

SELECT category_id,
       ROW_NUMBER() OVER (ORDER BY category_id) AS idx
INTO #cats FROM dim_categories;
DECLARE @CatCount INT = (SELECT COUNT(*) FROM #cats);

SELECT TOP (@NumProducts)
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
INTO #prod_stage
FROM sys.objects a CROSS JOIN sys.objects b;

INSERT INTO dim_products (sku, product_name, category_id, unit_cost, list_price)
SELECT
    'SKU' + RIGHT('000000' + CAST(s.n AS VARCHAR(10)), 6)            AS sku,

    CASE
        WHEN s.n =  1 THEN 'Laptop Pro'
        WHEN s.n =  2 THEN 'Laptop Max'
        WHEN s.n =  3 THEN 'Monitor Pro'
        WHEN s.n =  4 THEN 'Keyboard Max'
        WHEN s.n =  5 THEN 'Mouse Plus'
        WHEN s.n =  6 THEN 'Printer Plus'
        WHEN s.n =  7 THEN 'Router Pro'
        WHEN s.n =  8 THEN 'External HDD Pro'
        WHEN s.n =  9 THEN 'USB Hub Plus'
        WHEN s.n = 10 THEN 'Desk Chair Pro'
        WHEN s.n = 11 THEN 'Office Table Max'
        WHEN s.n = 12 THEN 'Drill Pro'
        WHEN s.n = 13 THEN 'Safety Kit Plus'
        WHEN s.n = 14 THEN 'Power Tool Max'
        WHEN s.n = 15 THEN 'Scanner Pro'
        ELSE 'Product ' + CAST(s.n AS VARCHAR(10))
    END                                                              AS product_name,

    c.category_id                                                    AS category_id,

    uc.unit_cost                                                     AS unit_cost,

    CASE
        WHEN s.n <= 40 THEN CAST(uc.unit_cost * (3.5 + (ABS(CHECKSUM(NEWID())) % 16) * 0.1) AS DECIMAL(10,2))
        ELSE                CAST(uc.unit_cost * (1.5 + (ABS(CHECKSUM(NEWID())) % 14) * 0.1) AS DECIMAL(10,2))
    END                                                              AS list_price

FROM #prod_stage s
JOIN #cats c ON c.idx = ((s.n - 1) % @CatCount) + 1
CROSS APPLY (
    SELECT CASE
             WHEN s.n <= 40 THEN CAST((ABS(CHECKSUM(NEWID())) % 50)  + 10  AS DECIMAL(10,2))
             ELSE                CAST((ABS(CHECKSUM(NEWID())) % 400) + 100 AS DECIMAL(10,2))
           END AS unit_cost
) uc;

DROP TABLE #prod_stage;
DROP TABLE #cats;
GO


-- =========================
-- 5. DIM_SALES_REPS 
-- =========================
DECLARE @NumSalesReps INT = 50;

SELECT TOP (@NumSalesReps)
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
INTO #rep_stage
FROM sys.objects a CROSS JOIN sys.objects b;

INSERT INTO dim_sales_reps (employee_code, full_name, region_id, hire_date, quota_target)
SELECT
    'REP' + RIGHT('000000' + CAST(n AS VARCHAR(10)), 6)              AS employee_code,
    'Representative ' + CAST(n AS VARCHAR(10))                       AS full_name,
    (ABS(CHECKSUM(NEWID())) % 20) + 1                                AS region_id,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 1095, '2022-01-01')        AS hire_date,
    CAST(((ABS(CHECKSUM(NEWID())) % 41) + 30) * 10000 AS DECIMAL(12,2)) AS quota_target
FROM #rep_stage;

DROP TABLE #rep_stage;
GO


-- =========================
-- 6. DIM_CUSTOMERS 
-- =========================
DECLARE @NumCustomers INT = 500;

SELECT TOP (@NumCustomers)
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
INTO #cust_stage
FROM sys.objects a CROSS JOIN sys.objects b;

INSERT INTO dim_customers (customer_code, customer_name, region_id, credit_limit, tier)
SELECT
    'C' + RIGHT('000000' + CAST(n AS VARCHAR(10)), 6)                AS customer_code,
    'Customer ' + CAST(n AS VARCHAR(10))                             AS customer_name,

    CASE
        WHEN n <= 60 THEN
            CASE (n % 4)
                WHEN 0 THEN 1
                WHEN 1 THEN 2
                WHEN 2 THEN 11
                ELSE            16
            END
        ELSE (ABS(CHECKSUM(NEWID())) % 20) + 1
    END                                                              AS region_id,

    CASE
        WHEN n <= 25 THEN CAST(((ABS(CHECKSUM(NEWID())) % 5) + 6) * 10000 AS DECIMAL(12,2))
        ELSE              CAST(((ABS(CHECKSUM(NEWID())) % 91) + 10) * 1000  AS DECIMAL(12,2))
    END                                                              AS credit_limit,

    CASE
        WHEN n <= 25 THEN 'Gold'
        WHEN n <= 60 THEN CASE ABS(CHECKSUM(NEWID())) % 2 WHEN 0 THEN 'Silver' ELSE 'Bronze' END
        ELSE              CASE ABS(CHECKSUM(NEWID())) % 3
                              WHEN 0 THEN 'Gold'
                              WHEN 1 THEN 'Silver'
                              ELSE        'Bronze'
                          END
    END                                                              AS tier

FROM #cust_stage;

DROP TABLE #cust_stage;
GO


-- =========================
-- 7. FACT_SALES_ORDERS  
-- =========================
DECLARE @NumOrders    INT = 10000;
DECLARE @OrderStart DATE = '2022-01-01';
DECLARE @OrderEnd   DATE = CAST(GETDATE() AS DATE);
DECLARE @SpanDays   INT  = DATEDIFF(DAY, @OrderStart, @OrderEnd) + 1;
INSERT INTO fact_sales_orders (customer_id, sales_rep_id, order_date, order_date_id, shipping_date, status)
SELECT
    ((s.n - 1) % 450) + 1,
    ((s.n - 1) % 45) + 1,
    s.order_date,
    s.order_date,
    DATEADD(DAY, s.ship_lag, s.order_date),
    s.status
FROM (
    SELECT TOP (@NumOrders)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL))                    AS n,
        DATEADD(DAY, ABS(CHECKSUM(NEWID())) % @SpanDays, @OrderStart) AS order_date,
        CASE ABS(CHECKSUM(NEWID())) % 10
            WHEN 0 THEN ABS(CHECKSUM(NEWID())) % 16 + 15
            ELSE        ABS(CHECKSUM(NEWID())) % 12 + 3
        END                                                           AS ship_lag,
        CASE ABS(CHECKSUM(NEWID())) % 20
            WHEN 0  THEN 'Pending'
            WHEN 1  THEN 'Pending'
            WHEN 2  THEN 'Pending'
            WHEN 3  THEN 'Shipped'
            WHEN 4  THEN 'Shipped'
            WHEN 5  THEN 'Shipped'
            WHEN 6  THEN 'Partially Delivered'
            WHEN 7  THEN 'Partially Delivered'
            WHEN 8  THEN 'Delivered'
            WHEN 9  THEN 'Delivered'
            WHEN 10 THEN 'Delivered'
            WHEN 11 THEN 'Delivered'
            ELSE         'Completed'
        END                                                           AS status
    FROM sys.objects a CROSS JOIN sys.objects b CROSS JOIN sys.objects c
) s;
GO


-- =========================
-- 8. FACT_ORDER_LINE_ITEMS
-- =========================

SELECT product_id, list_price,
       ROW_NUMBER() OVER (ORDER BY product_id) AS idx
INTO #prod_idx FROM dim_products;
DECLARE @ProdCount INT = (SELECT COUNT(*) FROM #prod_idx);
DECLARE @NoSaleCount INT = 5;
DECLARE @ActiveProdCount INT = @ProdCount - @NoSaleCount;

SELECT
    order_id,
    ROW_NUMBER() OVER (ORDER BY order_id)     AS rn,
    (ABS(CHECKSUM(NEWID())) % 10) + 1         AS quantity,
    CASE ABS(CHECKSUM(NEWID())) % 4
        WHEN 0 THEN CAST(0.00 AS DECIMAL(5,2))
        WHEN 1 THEN CAST(0.05 AS DECIMAL(5,2))
        WHEN 2 THEN CAST(0.10 AS DECIMAL(5,2))
        ELSE        CAST(0.15 AS DECIMAL(5,2))
    END                                       AS discount
INTO #line_stage
FROM fact_sales_orders;

INSERT INTO fact_order_line_items (order_id, product_id, quantity, unit_price, discount)
SELECT
    ls.order_id,
    pi.product_id,
    ls.quantity,
    pi.list_price,
    ls.discount
FROM #line_stage ls
JOIN #prod_idx pi ON pi.idx = ((ls.rn - 1) % @ActiveProdCount) + 1;

INSERT INTO fact_order_line_items (order_id, product_id, quantity, unit_price, discount)
SELECT
    ls.order_id,
    pi.product_id,
    (ABS(CHECKSUM(NEWID())) % 5) + 1,
    pi.list_price,
    CAST(0.00 AS DECIMAL(5,2))
FROM #line_stage ls
JOIN #prod_idx pi ON pi.idx = ((ls.rn) % @ActiveProdCount) + 1
WHERE ABS(CHECKSUM(NEWID())) % 10 < 3;

UPDATE li
SET li.quantity = 1,
    li.unit_price = CASE WHEN li.unit_price > 200 THEN 200 ELSE li.unit_price END
FROM fact_order_line_items li
JOIN fact_sales_orders o ON o.order_id = li.order_id
WHERE o.customer_id <= 40;

DROP TABLE #line_stage;
DROP TABLE #prod_idx;
GO


-- =========================
-- 9. FACT_QUOTAS
-- =========================
INSERT INTO fact_quotas (sales_rep_id, period_start, period_end,
                         period_start_id, period_end_id, quota_amount)
SELECT
    r.sales_rep_id,
    q.ps, q.pe, q.ps, q.pe,
    CAST(((ABS(CHECKSUM(NEWID())) % 13) + 8) * 10000 AS DECIMAL(12,2))
FROM dim_sales_reps r
CROSS JOIN (VALUES
    (CAST('2022-01-01' AS DATE), CAST('2022-03-31' AS DATE)),
    (CAST('2022-04-01' AS DATE), CAST('2022-06-30' AS DATE)),
    (CAST('2022-07-01' AS DATE), CAST('2022-09-30' AS DATE)),
    (CAST('2022-10-01' AS DATE), CAST('2022-12-31' AS DATE)),
    (CAST('2023-01-01' AS DATE), CAST('2023-03-31' AS DATE)),
    (CAST('2023-04-01' AS DATE), CAST('2023-06-30' AS DATE)),
    (CAST('2023-07-01' AS DATE), CAST('2023-09-30' AS DATE)),
    (CAST('2023-10-01' AS DATE), CAST('2023-12-31' AS DATE)),
    (CAST('2024-01-01' AS DATE), CAST('2024-03-31' AS DATE)),
    (CAST('2024-04-01' AS DATE), CAST('2024-06-30' AS DATE)),
    (CAST('2024-07-01' AS DATE), CAST('2024-09-30' AS DATE)),
    (CAST('2024-10-01' AS DATE), CAST('2024-12-31' AS DATE))
) q (ps, pe);
GO


-- =========================
-- 10. REP-CUSTOMER ASSIGNMENTS
-- =========================
INSERT INTO rep_customer_assignments (sales_rep_id, customer_id, start_date)
SELECT r.sales_rep_id, c.customer_id, '2022-01-01'
FROM dim_sales_reps r
JOIN dim_customers  c
  ON (c.customer_id % 45) = ((r.sales_rep_id - 1) % 45)
WHERE r.sales_rep_id <= (SELECT MIN(sales_rep_id) + 44 FROM dim_sales_reps);
GO


-- =========================
-- 11. PRODUCT_PROMOTIONS
-- =========================
SELECT TOP 7 product_id,
       ROW_NUMBER() OVER (ORDER BY product_id) AS rn
INTO #promo_prods FROM dim_products ORDER BY product_id;

INSERT INTO product_promotions (product_id, promotion_name, discount_rate,
                                start_date, end_date, start_date_id, end_date_id)
SELECT pp.product_id, pd.pname, pd.drate, pd.sd, pd.ed, pd.sd, pd.ed
FROM (VALUES
    (1,'New Year Sale',       CAST(0.15 AS DECIMAL(5,2)),CAST('2022-01-01' AS DATE),CAST('2022-01-31' AS DATE)),
    (2,'Summer Promo',        CAST(0.10 AS DECIMAL(5,2)),CAST('2022-06-01' AS DATE),CAST('2022-06-30' AS DATE)),
    (3,'Black Friday Deal',   CAST(0.20 AS DECIMAL(5,2)),CAST('2022-11-25' AS DATE),CAST('2022-11-30' AS DATE)),
    (4,'Industrial Sale',     CAST(0.25 AS DECIMAL(5,2)),CAST('2023-03-01' AS DATE),CAST('2023-03-31' AS DATE)),
    (5,'Year-End Clearance',  CAST(0.15 AS DECIMAL(5,2)),CAST('2023-12-15' AS DATE),CAST('2023-12-31' AS DATE)),
    (6,'Spring Office Promo', CAST(0.10 AS DECIMAL(5,2)),CAST('2024-03-01' AS DATE),CAST('2024-03-31' AS DATE)),
    (7,'Storage Offer',       CAST(0.15 AS DECIMAL(5,2)),CAST('2024-06-01' AS DATE),CAST('2024-06-30' AS DATE))
) pd (rn, pname, drate, sd, ed)
JOIN #promo_prods pp ON pp.rn = pd.rn;

DROP TABLE #promo_prods;
GO


-- =========================
-- 12. FACT_RETURNS
-- =========================
INSERT INTO fact_returns (line_item_id, return_date, return_date_id,
                          quantity, return_amount, reason)
SELECT
    li.line_item_id,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 14 + 5, o.order_date),
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 14 + 5, o.order_date),
    1,
    CAST(li.unit_price * (1 - li.discount) AS DECIMAL(12,2)),
    CASE ABS(CHECKSUM(NEWID())) % 3
        WHEN 0 THEN 'Damaged'
        WHEN 1 THEN 'Wrong Item'
        ELSE        'Customer Dissatisfied'
    END
FROM fact_order_line_items li
JOIN fact_sales_orders o ON li.order_id = o.order_id
WHERE ABS(CHECKSUM(NEWID())) % 8 = 0;
GO

;WITH li_by_cat AS (
    SELECT 
        li.line_item_id,
        o.order_date,
        p.category_id,
        ROW_NUMBER() OVER (PARTITION BY p.category_id ORDER BY NEWID()) AS rn
    FROM fact_order_line_items li
    JOIN fact_sales_orders o ON li.order_id = o.order_id
    JOIN dim_products p ON li.product_id = p.product_id
)
INSERT INTO fact_returns (line_item_id, return_date, return_date_id,
                          quantity, return_amount, reason)
SELECT
    l.line_item_id,
    DATEADD(DAY, 7, l.order_date),
    DATEADD(DAY, 7, l.order_date),
    1,
    CAST(li.unit_price * (1 - li.discount) AS DECIMAL(12,2)),
    'Category Sample'
FROM li_by_cat l
JOIN fact_order_line_items li ON li.line_item_id = l.line_item_id
WHERE l.rn = 1
  AND NOT EXISTS (
        SELECT 1 
        FROM fact_returns r 
        WHERE r.line_item_id = l.line_item_id
  );
