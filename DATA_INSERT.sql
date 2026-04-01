USE NordaTrade;

-- =========================
-- DIM_DATE
-- =========================
INSERT INTO dim_date (date_id, year, quarter, month, month_name, week_number, day_of_week, day_name, is_business_day)
SELECT
    d,
    YEAR(d),
    DATEPART(QUARTER, d),
    MONTH(d),
    DATENAME(MONTH, d),
    DATEPART(WEEK, d),
    DATEPART(WEEKDAY, d),
    DATENAME(WEEKDAY, d),
    CASE WHEN DATENAME(WEEKDAY, d) IN ('Saturday','Sunday') THEN 0 ELSE 1 END
FROM (
    SELECT TOP (365*5 + 2)
        DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1, '2022-01-01') AS d
    FROM sys.objects CROSS JOIN sys.objects s2
) t
WHERE d < '2027-01-01';


-- =========================
-- 2. DIM_REGIONS
-- =========================
INSERT INTO dim_regions (country, region_name, territory) VALUES
('Germany','Bavaria','South'), ('Germany','Hesse','Central'),
('France','Ile-de-France','Central'), ('France','Provence','South'),
('Austria','Vienna','East'), ('Austria','Tyrol','West'),
('Switzerland','Zurich','North'), ('Switzerland','Geneva','West'),
('Netherlands','North Holland','North'), ('Netherlands','South Holland','South'),
('Germany','Saxony','East'), ('France','Normandy','North'),
('Austria','Salzburg','Central'), ('Switzerland','Bern','Central'),
('Netherlands','Utrecht','Central'), ('Germany','Hamburg','North'),
('France','Brittany','West'), ('Austria','Styria','South'),
('Switzerland','Basel','North'), ('Netherlands','Limburg','South');


-- =========================
-- 3. DIM_CATEGORIES
-- =========================
INSERT INTO dim_categories (category_name, parent_category_id) VALUES
('Technology', NULL),
('Office Supplies', NULL),
('Industrial Equipment', NULL);

INSERT INTO dim_categories (category_name, parent_category_id) VALUES
('Laptops', 1), ('Desktops', 1), ('Printers', 1), ('Accessories', 1),
('Paper', 2), ('Writing', 2), ('Furniture', 2),
('Tools', 3), ('Machines', 3), ('Safety', 3);

INSERT INTO dim_categories (category_name, parent_category_id) VALUES
('Gaming Laptops', 4), ('Business Laptops', 4),
('Office Chairs', 9), ('Office Tables', 9),
('Hand Tools', 10), ('Power Tools', 10);


-- =========================
-- 4. DIM_PRODUCTS
-- =========================
INSERT INTO dim_products (sku, product_name, category_id, unit_cost, list_price) VALUES
('SKU001','Laptop Pro',1,500,1200),
('SKU002','Laptop Max',1,600,1400),
('SKU003','Desktop Elite',2,400,900),
('SKU004','Printer Plus',3,100,300),
('SKU005','Office Chair',7,80,200),
('SKU006','Desk Table',8,120,350),
('SKU007','Hammer Tool',9,20,60),
('SKU008','Industrial Drill',10,300,900),
('SKU009','USB Cable',11,5,20),
('SKU010','External HDD',12,50,150),
('SKU011','Router Pro',13,70,200),
('SKU012','A4 Paper Pack',14,3,10),
('SKU013','Pen Set',15,2,8),
('SKU014','Cleaning Kit',16,10,40),
('SKU015','Safety Gloves',17,8,25),
('SKU016','Wires Bundle',18,15,50),
('SKU017','Packaging Box',19,2,12),
('SKU018','Mouse Plus',11,10,35),
('SKU019','Keyboard Max',11,20,70),
('SKU020','Monitor Pro',1,150,400);


-- =========================
-- 5. DIM_SALES_REPS
-- =========================
INSERT INTO dim_sales_reps (employee_code, full_name, region_id, hire_date, quota_target) VALUES
('REP001','Rep 1',1,'2025-01-01',500000),
('REP002','Rep 2',2,'2025-02-01',450000),
('REP003','Rep 3',3,'2025-03-01',600000),
('REP004','Rep 4',4,'2025-04-01',550000),
('REP005','Rep 5',5,'2025-05-01',520000),
('REP006','Rep 6',6,'2025-06-01',510000),
('REP007','Rep 7',7,'2025-07-01',530000),
('REP008','Rep 8',8,'2025-08-01',490000),
('REP009','Rep 9',9,'2025-09-01',480000),
('REP010','Rep 10',10,'2025-10-01',470000),
('REP011','Rep 11',11,'2025-11-01',460000),
('REP012','Rep 12',12,'2025-12-01',450000),
('REP013','Rep 13',13,'2024-01-01',440000),
('REP014','Rep 14',14,'2024-02-01',430000),
('REP015','Rep 15',15,'2024-03-01',420000),
('REP016','Rep 16',16,'2024-04-01',410000),
('REP017','Rep 17',17,'2024-05-01',400000),
('REP018','Rep 18',18,'2024-06-01',390000),
('REP019','Rep 19',19,'2024-07-01',380000),
('REP020','Rep 20',20,'2024-08-01',370000);


-- =========================
-- 6. DIM_CUSTOMERS
-- =========================
INSERT INTO dim_customers (customer_code, customer_name, region_id, credit_limit, tier) VALUES
('C001','Customer 1',1,50000,'Gold'),
('C002','Customer 2',3,40000,'Silver'),
('C003','Customer 3',5,30000,'Bronze'),
('C004','Customer 4',7,70000,'Gold'),
('C005','Customer 5',9,45000,'Silver'),
('C006','Customer 6',2,55000,'Gold'),
('C007','Customer 7',4,35000,'Bronze'),
('C008','Customer 8',6,60000,'Gold'),
('C009','Customer 9',8,48000,'Silver'),
('C010','Customer 10',10,32000,'Bronze'),
('C011','Customer 11',11,51000,'Gold'),
('C012','Customer 12',12,42000,'Silver'),
('C013','Customer 13',13,31000,'Bronze'),
('C014','Customer 14',14,72000,'Gold'),
('C015','Customer 15',15,46000,'Silver'),
('C016','Customer 16',16,53000,'Gold'),
('C017','Customer 17',17,37000,'Bronze'),
('C018','Customer 18',18,61000,'Gold'),
('C019','Customer 19',19,49000,'Silver'),
('C020','Customer 20',20,33000,'Bronze');


-- =========================
-- 7. FACT_SALES_ORDERS
-- =========================
INSERT INTO fact_sales_orders (customer_id, sales_rep_id, order_date, order_date_id, shipping_date, status) VALUES
(1,1,'2024-01-01','2024-01-01','2024-01-04' ,'Completed'),
(2,2,'2024-01-05','2024-01-05','2024-01-21','Pending'),
(3,3,'2024-01-10','2024-01-10','2024-01-13','Completed'),
(4,4,'2024-01-15','2024-01-15','2024-01-22','Shipped'),
(5,5,'2024-01-20','2024-01-20','2024-01-23','Completed'),
(6,6,'2024-01-25','2024-01-25','2024-02-10','Pending'),
(7,7,'2024-02-01','2024-02-01','2024-02-04','Completed'),
(8,8,'2024-02-05','2024-02-05','2024-02-12','Shipped'),
(9,9,'2024-02-10','2024-02-10','2024-02-13','Completed'),
(10,10,'2024-02-15','2024-02-15','2024-03-02','Pending');


-- =========================
-- 8. FACT_ORDER_LINE_ITEMS
-- =========================
INSERT INTO fact_order_line_items (order_id, product_id, quantity, unit_price, discount) VALUES
(1,1,2,1200,0.1),(2,2,1,1400,0.05),(3,3,3,900,0),
(4,4,2,300,0.1),(5,5,5,200,0.05),(6,6,1,350,0),
(7,7,4,60,0.1),(8,8,2,900,0.15),(9,9,10,20,0),
(10,10,3,150,0.05);


-- =========================
-- 9. FACT_QUOTAS
-- =========================
INSERT INTO fact_quotas (sales_rep_id, period_start, period_end, period_start_id, period_end_id, quota_amount) VALUES
(1,'2024-01-01','2024-03-31','2024-01-01','2024-03-31',150000),
(2,'2024-01-01','2024-03-31','2024-01-01','2024-03-31',140000),
(3,'2024-01-01','2024-03-31','2024-01-01','2024-03-31',160000);


-- =========================
-- 10. REP-CUSTOMER ASSIGNMENTS
-- =========================
INSERT INTO rep_customer_assignments (sales_rep_id, customer_id, start_date) VALUES
(1,1,'2024-01-01'),(2,2,'2024-01-01'),
(3,3,'2024-01-01'),(4,4,'2024-01-01'),
(5,5,'2024-01-01'),(6,6,'2024-01-01'),
(7,7,'2024-01-01'),(8,8,'2024-01-01'),
(9,9,'2024-01-01'),(10,10,'2024-01-01');


-- =========================
-- 11. PRODUCT_PROMOTIONS
-- =========================
INSERT INTO product_promotions (product_id, promotion_name, discount_rate, start_date, end_date, start_date_id, end_date_id) VALUES
(1, 'New Year Sale', 0.15, '2024-01-01', '2024-01-31', '2024-01-01', '2024-01-31'),
(2, 'Winter Discount', 0.10, '2024-01-05', '2024-02-05', '2024-01-05', '2024-02-05'),
(5, 'Office Essentials Promo', 0.20, '2024-02-01', '2024-02-28', '2024-02-01', '2024-02-28'),
(8, 'Industrial Equipment Sale', 0.25, '2024-03-01', '2024-03-31', '2024-03-01', '2024-03-31'),
(10, 'Storage Offer', 0.15, '2024-03-15', '2024-04-15', '2024-03-15', '2024-04-15');



-- ===========================
-- 12. Pro
-- ===========================





INSERT INTO fact_returns 
(line_item_id, return_date, return_date_id, quantity, return_amount, reason)
VALUES
(4, '2024-01-20', '2024-01-20', 1, 180.00, 'Wrong Item'),
(8, '2024-02-10', '2024-02-10', 1, 540.00, 'Customer Dissatisfied'),
(1, '2024-01-06', '2024-01-06', 1, 720.00, 'Damaged'),
(2, '2024-01-10', '2024-01-10', 1, 420.00, 'Wrong Item'),
(3, '2024-01-15', '2024-01-15', 1, 810.00, 'Damaged'),
(4, '2024-01-20', '2024-01-20', 1, 180.00, 'Customer Dissatisfied'),
(5, '2024-01-25', '2024-01-25', 1, 300.00, 'Damaged'),
(6, '2024-01-30', '2024-01-30', 1, 105.00, 'Customer Dissatisfied'),
(7, '2024-02-06', '2024-02-06', 1, 72.00, 'Customer Dissatisfied'),
(8, '2024-02-10', '2024-02-10', 1, 540.00, 'Damaged'),
(9, '2024-02-15', '2024-02-15', 3, 60.00, 'Customer Dissatisfied'),
(10, '2024-02-20', '2024-02-20', 1, 135.00, 'Customer Dissatisfied'),
(4, '2024-01-20', '2024-01-20', 1, 180.00, 'Wrong Item'),
(8, '2024-02-10', '2024-02-10', 1, 540.00, 'Customer Dissatisfied'),
(1, '2024-01-06', '2024-01-06', 1, 720.00, 'Customer Dissatisfied'),
(2, '2024-01-10', '2024-01-10', 1, 420.00, 'Customer Dissatisfied'),
(3, '2024-01-15', '2024-01-15', 1, 810.00, 'Damaged'),
(4, '2024-01-20', '2024-01-20', 1, 180.00, 'Damaged'),
(5, '2024-01-25', '2024-01-25', 1, 300.00, 'Damaged'),
(6, '2024-01-30', '2024-01-30', 1, 105.00, 'Damaged'),
(7, '2024-02-06', '2024-02-06', 1, 72.00, 'Damaged'),
(8, '2024-02-10', '2024-02-10', 1, 540.00, 'Damaged'),
(9, '2024-02-15', '2024-02-15', 3, 60.00, 'Damaged'),
(10, '2024-02-20', '2024-02-20', 1, 135.00, 'Damaged'),
(1, '2024-01-06', '2024-01-06', 1, 720.00, 'Customer Dissatisfied'),
(2, '2024-01-10', '2024-01-10', 1, 420.00, 'Wrong Item'),
(3, '2024-01-15', '2024-01-15', 1, 810.00, 'Customer Dissatisfied'),
(4, '2024-01-20', '2024-01-20', 1, 180.00, 'Customer Dissatisfied'),
(5, '2024-01-25', '2024-01-25', 1, 300.00, 'Damaged'),
(6, '2024-01-30', '2024-01-30', 1, 105.00, 'Wrong Item'),
(7, '2024-02-06', '2024-02-06', 1, 72.00, 'Wrong Item'),
(8, '2024-02-10', '2024-02-10', 1, 540.00, 'Customer Dissatisfied'),
(9, '2024-02-15', '2024-02-15', 3, 60.00, 'Customer Dissatisfied'),
(10, '2024-02-20', '2024-02-20', 1, 135.00, 'Damaged'),
(1, '2024-01-06', '2024-01-06', 1, 720.00, 'Wrong Item'),
(2, '2024-01-10', '2024-01-10', 1, 420.00, 'Wrong Item'),
(3, '2024-01-15', '2024-01-15', 1, 810.00, 'Damaged'),
(4, '2024-01-20', '2024-01-20', 1, 180.00, 'Customer Dissatisfied'),
(5, '2024-01-25', '2024-01-25', 1, 300.00, 'Damaged'),
(6, '2024-01-30', '2024-01-30', 1, 105.00, 'Customer Dissatisfied'),
(7, '2024-02-06', '2024-02-06', 1, 72.00, 'Damaged'),
(8, '2024-02-10', '2024-02-10', 1, 540.00, 'Wrong Item'),
(9, '2024-02-15', '2024-02-15', 3, 60.00, 'Damaged'),
(10, '2024-02-20', '2024-02-20', 1, 135.00, 'Customer Dissatisfied'),
(1, '2024-01-06', '2024-01-06', 1, 720.00, 'Damaged'),
(2, '2024-01-10', '2024-01-10', 1, 420.00, 'Damaged'),
(3, '2024-01-15', '2024-01-15', 1, 810.00, 'Damaged');