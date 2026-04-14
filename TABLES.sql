IF DB_ID('NordaTrade') IS NULL
    CREATE DATABASE NordaTrade;
GO

USE NordaTrade;
GO


IF OBJECT_ID('fact_returns') IS NOT NULL DROP TABLE fact_returns;
IF OBJECT_ID('fact_order_line_items') IS NOT NULL DROP TABLE fact_order_line_items;
IF OBJECT_ID('fact_sales_orders') IS NOT NULL DROP TABLE fact_sales_orders;
IF OBJECT_ID('fact_quotas') IS NOT NULL DROP TABLE fact_quotas;
IF OBJECT_ID('rep_customer_assignments') IS NOT NULL DROP TABLE rep_customer_assignments;
IF OBJECT_ID('product_promotions') IS NOT NULL DROP TABLE product_promotions;

IF OBJECT_ID('dim_products') IS NOT NULL DROP TABLE dim_products;
IF OBJECT_ID('dim_categories') IS NOT NULL DROP TABLE dim_categories;
IF OBJECT_ID('dim_customers') IS NOT NULL DROP TABLE dim_customers;
IF OBJECT_ID('dim_sales_reps') IS NOT NULL DROP TABLE dim_sales_reps;
IF OBJECT_ID('dim_regions') IS NOT NULL DROP TABLE dim_regions;
IF OBJECT_ID('dim_date') IS NOT NULL DROP TABLE dim_date;



-- =========================
-- DIMENSION TABLES
-- =========================

CREATE TABLE dim_regions (
    region_id INT IDENTITY(1,1) PRIMARY KEY,
    country NVARCHAR(50) NOT NULL,
    region_name NVARCHAR(50) NOT NULL,
    territory NVARCHAR(50) NOT NULL,
    CONSTRAINT uq_region UNIQUE (country, region_name, territory)
);


CREATE TABLE dim_date (
    date_id DATE PRIMARY KEY,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    month_name NVARCHAR(20),
    week_number INT NOT NULL,
    day_of_week INT,
    day_name NVARCHAR(20),
    is_business_day BIT
);


CREATE TABLE dim_sales_reps (
    sales_rep_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_code NVARCHAR(20) NOT NULL UNIQUE,
    full_name NVARCHAR(100) NOT NULL,
    region_id INT NOT NULL,
    hire_date DATE NOT NULL,
    created_at DATETIME DEFAULT GETDATE(),

    CONSTRAINT fk_rep_region
        FOREIGN KEY (region_id) REFERENCES dim_regions(region_id)
);


CREATE TABLE dim_customers (
    customer_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_code NVARCHAR(20) NOT NULL UNIQUE,
    customer_name NVARCHAR(100) NOT NULL,
    region_id INT NOT NULL,
    credit_limit DECIMAL(12,2) NOT NULL CHECK (credit_limit >= 0),
    tier NVARCHAR(10) NOT NULL CHECK (tier IN ('Gold','Silver','Bronze')),
    created_at DATETIME DEFAULT GETDATE(),

    CONSTRAINT fk_customer_region
        FOREIGN KEY (region_id) REFERENCES dim_regions(region_id)
);


CREATE TABLE dim_categories (
    category_id INT IDENTITY(1,1) PRIMARY KEY,
    category_name NVARCHAR(100) NOT NULL,
    parent_category_id INT NULL,

    CONSTRAINT fk_category_parent
        FOREIGN KEY (parent_category_id)
        REFERENCES dim_categories(category_id)
);


CREATE TABLE dim_products (
    product_id INT IDENTITY(1,1) PRIMARY KEY,
    sku NVARCHAR(50) NOT NULL UNIQUE,
    product_name NVARCHAR(100) NOT NULL,
    category_id INT NOT NULL,
    unit_cost DECIMAL(10,2) NOT NULL CHECK (unit_cost > 0),
    list_price DECIMAL(10,2) NOT NULL CHECK (list_price > 0),
    is_active BIT DEFAULT 1,
    created_at DATETIME DEFAULT GETDATE(),

    CONSTRAINT fk_product_category
        FOREIGN KEY (category_id) REFERENCES dim_categories(category_id)
);


-- =========================
-- FACT TABLES
-- =========================

CREATE TABLE fact_sales_orders (
    order_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT NOT NULL,
    sales_rep_id INT NOT NULL,
    order_date DATE NOT NULL,
    order_date_id DATE NOT NULL,
    shipping_date DATE NULL,
    status NVARCHAR(50) DEFAULT 'Pending',
    order_total DECIMAL(14,2) NULL,

    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id),

    CONSTRAINT fk_order_rep
        FOREIGN KEY (sales_rep_id) REFERENCES dim_sales_reps(sales_rep_id),

    CONSTRAINT fk_order_date
        FOREIGN KEY (order_date_id) REFERENCES dim_date(date_id)
);


CREATE TABLE fact_order_line_items (
    line_item_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price > 0),
    discount DECIMAL(5,2) DEFAULT 0 CHECK (discount BETWEEN 0 AND 1),

    total_price AS (quantity * unit_price) PERSISTED,
    discount_amount AS (quantity * unit_price * discount) PERSISTED,
    net_price AS (quantity * unit_price * (1 - discount)) PERSISTED,

    CONSTRAINT fk_line_order
        FOREIGN KEY (order_id) REFERENCES fact_sales_orders(order_id),

    CONSTRAINT fk_line_product
        FOREIGN KEY (product_id) REFERENCES dim_products(product_id)
);


CREATE TABLE fact_returns (
    return_id INT IDENTITY(1,1) PRIMARY KEY,
    line_item_id INT NOT NULL,
    return_date DATE NOT NULL,
    return_date_id DATE NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    return_amount DECIMAL(12,2) NULL,
    reason NVARCHAR(100),

    CONSTRAINT fk_return_line
        FOREIGN KEY (line_item_id)
        REFERENCES fact_order_line_items(line_item_id),

    CONSTRAINT fk_return_date
        FOREIGN KEY (return_date_id)
        REFERENCES dim_date(date_id)
);


CREATE TABLE fact_quotas (
    quota_id INT IDENTITY(1,1) PRIMARY KEY,
    sales_rep_id INT NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    period_start_id DATE,
    period_end_id DATE,
    quota_amount DECIMAL(12,2) NOT NULL,

    CONSTRAINT fk_quota_rep
        FOREIGN KEY (sales_rep_id)
        REFERENCES dim_sales_reps(sales_rep_id),

    CONSTRAINT fk_quota_start_date
        FOREIGN KEY (period_start_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_quota_end_date
        FOREIGN KEY (period_end_id)
        REFERENCES dim_date(date_id)
);


-- =========================
-- BRIDGE / MAPPING
-- =========================

CREATE TABLE rep_customer_assignments (
    assignment_id INT IDENTITY(1,1) PRIMARY KEY,
    sales_rep_id INT NOT NULL,
    customer_id INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NULL,

    CONSTRAINT fk_assign_rep
        FOREIGN KEY (sales_rep_id)
        REFERENCES dim_sales_reps(sales_rep_id),

    CONSTRAINT fk_assign_customer
        FOREIGN KEY (customer_id)
        REFERENCES dim_customers(customer_id)
);


CREATE TABLE product_promotions (
    promotion_id INT IDENTITY(1,1) PRIMARY KEY,
    product_id INT NOT NULL,
    promotion_name NVARCHAR(100) NOT NULL,
    discount_rate DECIMAL(5,2) NOT NULL CHECK (discount_rate BETWEEN 0 AND 1),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    start_date_id DATE,
    end_date_id DATE,

    CONSTRAINT fk_promo_product
        FOREIGN KEY (product_id)
        REFERENCES dim_products(product_id),

    CONSTRAINT fk_promo_start_date
        FOREIGN KEY (start_date_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_promo_end_date
        FOREIGN KEY (end_date_id)
        REFERENCES dim_date(date_id)
);
