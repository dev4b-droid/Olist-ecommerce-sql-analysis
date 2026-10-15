-- ============================================================
-- Olist Marketplace: Delivery Delays and Seller Performance
-- Database: MySQL 8.0+
-- ============================================================
-- BEFORE RUNNING:
--   1. Server side:  SET GLOBAL local_infile = 1;
--   2. Client side:  enable local infile in your connection
--      (MySQL Workbench: Edit Connection > Advanced > Others > OPT_LOCAL_INFILE=1,
--       then reconnect)
--   3. Replace C:/path/to/dataset/ in every LOAD DATA statement with the
--      folder that holds the Olist CSV files.
--
-- NOTE: This script drops and recreates the olist database,
--       so it can be run any number of times.
-- ============================================================

SET GLOBAL local_infile = 1;

DROP DATABASE IF EXISTS olist;
CREATE DATABASE olist;
USE olist;

-- Creating Tables (Customers, Sellers, Products, Orders, Order_items, Order_payments, Order_reviews)
CREATE TABLE customers (
  customer_id CHAR(32) PRIMARY KEY,
  customer_unique_id CHAR(32),
  customer_zip_code_prefix INT,
  customer_city VARCHAR(64),
  customer_state CHAR(2)
);

CREATE TABLE sellers (
  seller_id CHAR(32) PRIMARY KEY,
  seller_zip_code_prefix INT,
  seller_city VARCHAR(64),
  seller_state CHAR(2)
);

CREATE TABLE products (
  product_id CHAR(32) PRIMARY KEY,
  product_category_name VARCHAR(64),
  product_name_lenght INT,
  product_description_lenght INT,
  product_photos_qty INT,
  product_weight_g INT,
  product_length_cm INT,
  product_height_cm INT,
  product_width_cm INT
);

CREATE TABLE orders (
  order_id CHAR(32) PRIMARY KEY,
  customer_id CHAR(32),
  order_status VARCHAR(20),
  order_purchase_timestamp DATETIME,
  order_approved_at DATETIME NULL,
  order_delivered_carrier_date DATETIME NULL,
  order_delivered_customer_date DATETIME NULL,
  order_estimated_delivery_date DATETIME
);

CREATE TABLE order_items (
  order_id CHAR(32),
  order_item_id INT,
  product_id CHAR(32),
  seller_id CHAR(32),
  shipping_limit_date DATETIME,
  price DECIMAL(10,2),
  freight_value DECIMAL(10,2),
  PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
  order_id CHAR(32),
  payment_sequential INT,
  payment_type VARCHAR(20),
  payment_installments INT,
  payment_value DECIMAL(10,2),
  PRIMARY KEY (order_id, payment_sequential)
);

-- no primary key: review_id has duplicates in the raw data
CREATE TABLE order_reviews (
  review_id CHAR(32),
  order_id CHAR(32),
  review_score TINYINT,
  review_comment_title VARCHAR(255),
  review_comment_message TEXT,
  review_creation_date DATETIME,
  review_answer_timestamp DATETIME
);

-- Load Dataset into Tables
-- (geolocation and product_category_name_translation are not used in this analysis,
--  so they are not created or loaded)

LOAD DATA LOCAL INFILE 'C:/path/to/dataset/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/path/to/dataset/olist_sellers_dataset.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/path/to/dataset/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS
(product_id, product_category_name, @a, @b, @c, @d, @e, @f, @g)
SET product_name_lenght = NULLIF(@a,''),
    product_description_lenght = NULLIF(@b,''),
    product_photos_qty = NULLIF(@c,''),
    product_weight_g = NULLIF(@d,''),
    product_length_cm = NULLIF(@e,''),
    product_height_cm = NULLIF(@f,''),
    product_width_cm = NULLIF(@g,'');

LOAD DATA LOCAL INFILE 'C:/path/to/dataset/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS
(order_id, customer_id, order_status, @a, @b, @c, @d, @e)
SET order_purchase_timestamp = NULLIF(@a,''),
    order_approved_at = NULLIF(@b,''),
    order_delivered_carrier_date = NULLIF(@c,''),
    order_delivered_customer_date = NULLIF(@d,''),
    order_estimated_delivery_date = NULLIF(@e,'');

LOAD DATA LOCAL INFILE 'C:/path/to/dataset/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/path/to/dataset/olist_order_payments_dataset.csv'
INTO TABLE order_payments
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- The reviews file uses Windows line endings (\r\n). Escaping is switched off
-- (ESCAPED BY '') because some review texts contain backslashes, which would
-- otherwise break the quote handling and drop a row.
LOAD DATA LOCAL INFILE 'C:/path/to/dataset/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ',' ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\r\n' IGNORE 1 ROWS;

-- Checking whether all the data is loaded or not 
SELECT COUNT(*) AS CUSTOMERS FROM customers;
SELECT COUNT(*) AS ITEMS FROM order_items;
SELECT COUNT(*) AS PAYMENTS FROM order_payments;
SELECT COUNT(*) AS REVIEWS FROM order_reviews;
SELECT COUNT(*) AS ORDERS FROM orders;
SELECT COUNT(*) AS PRODUCTS FROM products;
SELECT COUNT(*) AS SELLERS FROM sellers;

-- WE HAVE 4 QUESTIONS TO ANSWER 
-- QUESTION 1: Does late delivery hurt review scores?
-- QUESTION 2: What is the month-on-month revenue growth?
-- QUESTION 3: Who are the top sellers?
-- QUESTION 4: Who are the repeat customers?

-- Order data is spread across several tables, so we first build one order-level view that holds everything the four questions need.
-- We are creating a view which will contain the following 
-- order id, customer id, order purchase time, delay days, delivery days, late flag, review score, item count, price, freight value, amount

CREATE OR REPLACE VIEW order_analysis AS

WITH ranked_reviews AS (
    SELECT
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY review_answer_timestamp DESC,
                     review_creation_date DESC
        ) AS sr_no,
        order_id,
        review_score
    FROM order_reviews
),

delivery AS (
    SELECT
        order_id,
        customer_id,
        order_purchase_timestamp,
        DATEDIFF(
            order_delivered_customer_date,
            order_purchase_timestamp
        ) AS delivery_days,

        DATEDIFF(
            order_estimated_delivery_date,
            order_delivered_customer_date
        ) AS delay_days,

        CASE
            WHEN DATEDIFF(
                order_estimated_delivery_date,
                order_delivered_customer_date
            ) < 0 THEN 1
            ELSE 0
        END AS late_flag

    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND (
          order_delivered_carrier_date <= order_delivered_customer_date
          OR order_delivered_carrier_date IS NULL
      )
),

items AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        SUM(price) AS price,
        SUM(freight_value) AS freight_value
    FROM order_items
    GROUP BY order_id
),

payments AS (
    SELECT
        order_id,
        SUM(payment_value) AS amount
    FROM order_payments
    GROUP BY order_id
)

SELECT
    d.order_id,
    d.customer_id,
    d.order_purchase_timestamp,
    d.delivery_days,
    d.delay_days,
    d.late_flag,
    r.review_score,
    i.item_count,
    i.price,
    i.freight_value,
    p.amount

FROM delivery AS d

LEFT JOIN ranked_reviews AS r
    ON d.order_id = r.order_id
   AND r.sr_no = 1

LEFT JOIN items AS i
    ON d.order_id = i.order_id

LEFT JOIN payments AS p
    ON d.order_id = p.order_id;
    
-- View is created

-- QUESTION 1 : does late delivery hurt review scores?

-- Finding what percent of orders belong to late delivered and on time delivered category 
SELECT
late_flag,
COUNT(DISTINCT order_id) as order_count,
ROUND(AVG(review_score), 2) AS avg_review_score,
ROUND(
COUNT(DISTINCT order_id) * 100.0
/ SUM(COUNT(DISTINCT order_id)) OVER (),
2
) AS order_percentage
FROM order_analysis
GROUP BY late_flag;
-- Result: 6.77% of delivered orders are late; late orders average 2.3 stars vs 4.3 for on-time.

-- Analysing further by dividing delay days into 5 buckets and finding what percent of orders belong to these buckets 
WITH late_analysis AS
( 
SELECT *, 
CASE 
WHEN delay_days >= 0 THEN 'on_time'
WHEN delay_days BETWEEN -3 AND -1 THEN 'little_late'
WHEN delay_days BETWEEN -7 AND -4 THEN 'normal_late'
WHEN delay_days BETWEEN -14 AND -8 THEN 'moderate_late'
ELSE 'very_late'
END AS late_category
FROM order_analysis
)
SELECT late_category, COUNT(order_id) AS orders_count, ROUND(AVG(review_score),1) AS avg_review, 
ROUND(COUNT(DISTINCT order_id)*100/ SUM(COUNT(DISTINCT order_id)) OVER(),2) AS order_percentage
FROM late_analysis
GROUP BY late_category
ORDER BY avg_review DESC;
-- Result: average review falls from 4.3 (on time) to 3.3 (1-3 days late), 2.1 (4-7 days) and about 1.7 once 8+ days late; most of the damage happens in the first week.

-- Finding which states are most prone to late deliveries and how this affects reviews there
WITH state_analysis AS
(
SELECT
    c.customer_state,
    COUNT(DISTINCT v.order_id) AS total_orders,
    SUM(v.late_flag) AS late_orders,
    ROUND(AVG(v.review_score), 2) AS avg_review_score
FROM order_analysis AS v
LEFT JOIN customers AS c
    ON v.customer_id = c.customer_id
GROUP BY c.customer_state
)
SELECT *, ROUND(late_orders*100/total_orders,1) as late_rate
FROM state_analysis
HAVING total_orders >= 500
ORDER BY late_rate DESC;
-- Result: late rate ranges from 4.0% (PR) to 17.4% (MA); RJ has 12.1% late on 12,349 orders; high-late states score lower (MA 3.83 vs SP 4.25).

-- ALL of the above steps were done to see how delivering late affects reviews we analysed it at 3 levels: 
-- 1. Surface level 
-- 2. Dividing lateness into buckets of how late they are 
-- 3. Not looking how late they are but where the orders are getting late 
-- Using avg review score as a metric in all the three analysis because it gives us a pretty decent idea of what reviews each category is getting which will tell us which category needs priority 

-- Question 2: month-on-month revenue growth

-- Sep to Dec 2016 and Sep to Oct 2018 are excluded, because they have too few orders to give meaningful growth.
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS month,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(price) AS revenue,
        ROUND(
            SUM(price) / COUNT(DISTINCT order_id),
            2
        ) AS average_order_value
    FROM order_analysis
    WHERE order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp < '2018-09-01'
    GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
),
-- since all the things we want to achieve can't be done in one query we used 2 CTEs 
revenue_growth AS (
    SELECT
        month,
        total_orders,
        revenue,
        average_order_value,

        LAG(revenue) OVER (
            ORDER BY month
        ) AS previous_month_revenue

    FROM monthly_revenue
)

SELECT
    month,
    total_orders,
    ROUND(revenue, 2) AS revenue,
    average_order_value,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,
    ROUND(
        (revenue - previous_month_revenue)
        / NULLIF(previous_month_revenue, 0) * 100,
        2
    ) AS mom_growth_percentage,
	ROUND(
        SUM(revenue) OVER (
            ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS cumulative_revenue

FROM revenue_growth
ORDER BY month;
-- Result: monthly revenue grew about 7.5x (R$111.6K in Jan 2017 to R$838.6K in Aug 2018), peaking in Nov 2017 (R$987.6K); total R$13.18M over 20 months.

-- This gives us the revenue growth for every month, so we can see how it changes over time.

-- Question 3: seller rankings

-- For seller rankings we need seller id for which we will use seller table and since our order_analysis view doesn't have seller id we need to make new view for this 
CREATE OR REPLACE VIEW seller_orders AS 
SELECT o.order_id, o.seller_id, SUM(o.price) AS revenue, MAX(v.order_purchase_timestamp) AS order_purchase_timestamp, MAX(v.late_flag) AS late_flag, AVG(v.review_score) AS review
FROM order_items AS o
INNER JOIN order_analysis AS v
ON o.order_id = v.order_id
GROUP BY o.order_id, o.seller_id;

CREATE OR REPLACE VIEW seller_summary AS 
SELECT seller_id, COUNT(order_id) AS order_count, SUM(revenue) AS earning, AVG(review) AS avg_review, ROUND(AVG(late_flag)*100, 2) AS late_per
FROM seller_orders
GROUP BY seller_id;

--  seller_orders keeps one row per seller per order, so it can be used when time matters. seller_summary condenses it to one row per seller for overall analysis.

-- Overall Top 10 
WITH problem AS (
SELECT
    v.seller_id,
    v.order_count,
    v.earning,
    v.avg_review,
    v.late_per,
    s.seller_state,
    DENSE_RANK() OVER (
        ORDER BY v.earning DESC
    ) AS earning_rank
FROM seller_summary AS v
LEFT JOIN sellers AS s
    ON v.seller_id = s.seller_id
)
SELECT * FROM problem 
WHERE earning_rank <= 10;
-- Result: the top seller earns about R$227K from 1,124 orders; the top 10 sellers earn about 13.3% of revenue, and 9 of the 10 are in SP.

-- Statewise Top 3
WITH p2 AS 
(
SELECT
    v.seller_id,
    v.order_count,
    v.earning,
    v.avg_review,
    v.late_per,
    s.seller_state,
    DENSE_RANK() OVER ( 
        PARTITION BY s.seller_state 
        ORDER BY v.earning DESC
    ) AS earning_rank
FROM seller_summary AS v
LEFT JOIN sellers AS s
    ON v.seller_id = s.seller_id
)
SELECT * FROM p2
WHERE earning_rank <= 3;
-- Result: sellers cluster in SP, which holds about 60% of sellers and 64% of revenue.

-- Decile analysis

WITH seller_deciles AS (
    SELECT
        seller_id,
        earning,
        NTILE(10) OVER (
            ORDER BY earning DESC
        ) AS earning_decile
    FROM seller_summary
)
SELECT COUNT(*) AS sellers_decile_1
FROM seller_deciles
WHERE earning_decile = 1;

WITH seller_deciles AS (
    SELECT
        seller_id,
        earning,
        NTILE(10) OVER (
            ORDER BY earning DESC
        ) AS earning_decile
    FROM seller_summary
)
SELECT
    ROUND(
        SUM(CASE
            WHEN earning_decile = 1 THEN earning
            ELSE 0
        END) * 100.0 / SUM(earning),
        2
    ) AS decile_1_revenue_percentage
FROM seller_deciles;
 -- Result: decile 1 (297 sellers) earns 67.12% of revenue; the bottom half of sellers earns only about 3%.
 
-- Flags the top 30 sellers by revenue who have a below-average review or an above-average late rate compared with the market.
CREATE OR REPLACE VIEW seller_category AS

WITH ranked_sellers AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            ORDER BY earning DESC
        ) AS earn_rank
    FROM seller_summary
    WHERE order_count > 30
),

top_30 AS (
    SELECT *
    FROM ranked_sellers
    WHERE earn_rank <= 30
),

benchmarks AS (
    SELECT
        AVG(avg_review) AS avg_review_benchmark,
        AVG(late_per) AS avg_late_benchmark
    FROM ranked_sellers
)

SELECT
    t.seller_id,
    t.order_count,
    t.earning,
    t.avg_review,
    t.late_per,

    CASE
        WHEN t.avg_review < b.avg_review_benchmark
             OR t.late_per > b.avg_late_benchmark
        THEN 'Flagged'
        ELSE 'Not Flagged'
    END AS seller_flag

FROM top_30 AS t
CROSS JOIN benchmarks AS b;

SELECT
    COUNT(*) AS total_sellers,
    SUM(CASE
        WHEN seller_flag = 'Flagged' THEN 1
        ELSE 0
    END) AS flagged_sellers,
    ROUND(
        100.0 * SUM(
            CASE WHEN seller_flag = 'Flagged' THEN 1 ELSE 0 END
        ) / COUNT(*),
        2
    ) AS flagged_seller_percentage
FROM seller_category;
-- Result: 21 of the top 30 sellers (70%) are worse than the marketplace benchmark on review score or late rate.

-- Question 4: repeat customers

CREATE OR REPLACE VIEW customer_base AS 
SELECT o.order_id, o.order_purchase_timestamp, o.price, o.late_flag, o.review_score, c.customer_unique_id
FROM order_analysis AS o
LEFT JOIN customers AS c
ON o.customer_id = c.customer_id;

WITH customer_orders AS (
    SELECT
        customer_unique_id,
        COUNT(order_id) AS total_orders
    FROM customer_base
    GROUP BY customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(
        CASE
            WHEN total_orders > 1 THEN 1
            ELSE 0
        END
    ) AS repeat_customers,
    ROUND(
        SUM(
            CASE
                WHEN total_orders > 1 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS repeat_customer_percentage
FROM customer_orders;

-- Result: 2,798 repeat customers, 3.00% of 93,330.

WITH customer_orders AS (
    SELECT
        customer_unique_id,
        COUNT(order_id) AS total_orders
    FROM customer_base
    GROUP BY customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(
        CASE
            WHEN total_orders > 1 THEN total_orders
            ELSE 0
        END
    ) AS repeat_order,
    ROUND(
        SUM(
            CASE
                WHEN total_orders > 1 THEN total_orders
                ELSE 0
            END
        ) * 100.0 / SUM(total_orders),
        2
    ) AS repeat_order_percentage
FROM customer_orders;

-- Result: repeat customers placed 5,915 orders, 6.13% of all orders.

WITH customer_order AS (
    SELECT
        customer_unique_id,
        COUNT(order_id) AS total_orders,
        SUM(price) AS revenue
    FROM customer_base
    GROUP BY customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(
        CASE
            WHEN total_orders > 1 THEN revenue
            ELSE 0
        END
    ) AS repeat_revenue,
    ROUND(
        SUM(
            CASE
                WHEN total_orders > 1 THEN revenue
                ELSE 0
            END
        ) * 100.0 / SUM(revenue),
        2
    ) AS repeat_revenue_percentage
FROM customer_order;

-- Result: repeat customers generated R$727,389.92, 5.5% of revenue.

WITH order_gaps AS (
    SELECT
        customer_unique_id,
        order_id,
        DATEDIFF(
            order_purchase_timestamp,
            LAG(order_purchase_timestamp) OVER (
                PARTITION BY customer_unique_id
                ORDER BY order_purchase_timestamp, order_id
            )
        ) AS gap_days
    FROM customer_base
),

customer_gaps AS (
    SELECT
        customer_unique_id,
        COUNT(*) AS order_count,
        MAX(gap_days) AS max_gap
    FROM order_gaps
    GROUP BY customer_unique_id
),

classified AS (
    SELECT
        customer_unique_id,
        CASE
            WHEN max_gap IS NULL THEN 'One-time'
            WHEN max_gap = 0 THEN 'Repeat, same day only'
            ELSE 'Returned on a later day'
        END AS customer_type
    FROM customer_gaps
)

SELECT
    customer_type,
    COUNT(*) AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS customer_percentage
FROM classified
GROUP BY customer_type
ORDER BY customers DESC;
-- Result: 97.00% one-time, 2.16% returned on a later day, 0.84% repeat on the same day only.
-- Above query classifies the customers into groups and sees how many customers belong to a particular group 

CREATE OR REPLACE VIEW customer_first_order AS
WITH cust_orders AS (
    SELECT
        c.customer_unique_id,
        oa.order_id,
        oa.order_purchase_timestamp AS ts,
        DATE(oa.order_purchase_timestamp) AS order_date,
        oa.late_flag,
        oa.review_score
    FROM order_analysis AS oa
    JOIN customers AS c
        ON oa.customer_id = c.customer_id
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY ts, order_id
        ) AS order_number,
        MIN(order_date) OVER (
            PARTITION BY customer_unique_id
        ) AS first_date
    FROM cust_orders
),
flags AS (
    SELECT
        customer_unique_id,
        MAX(CASE
                WHEN DATEDIFF(order_date, first_date) BETWEEN 1 AND 90
                THEN 1 ELSE 0
            END) AS returned_90
    FROM ranked
    GROUP BY customer_unique_id
)
SELECT
    r.customer_unique_id,
    r.first_date,
    r.late_flag AS first_late_flag,
    r.review_score AS first_review_score,
    f.returned_90
FROM ranked AS r
JOIN flags AS f
    ON r.customer_unique_id = f.customer_unique_id
WHERE r.order_number = 1;

SELECT
    DATE_FORMAT(first_date, '%Y-%m') AS cohort_month,
    COUNT(*) AS cohort_size,
    SUM(returned_90) AS returned_within_90_days,
    ROUND(SUM(returned_90) * 100.0 / COUNT(*), 2) AS return_rate_90d
FROM customer_first_order
WHERE first_date >= '2017-01-01'
  AND first_date <  '2018-06-01'
GROUP BY DATE_FORMAT(first_date, '%Y-%m')
ORDER BY cohort_month;
-- Result: 90-day return rate stays between 0.84% and 1.82% across cohorts (about 1.3% overall), with no clear trend.

-- by first-order lateness
SELECT
    first_late_flag,
    COUNT(*) AS customers,
    SUM(returned_90) AS returned_within_90_days,
    ROUND(AVG(returned_90) * 100, 2) AS return_rate_90d
FROM customer_first_order
WHERE first_date >= '2017-01-01'
  AND first_date <  '2018-06-01'
GROUP BY first_late_flag;
-- Result: customers whose first order was late returned within 90 days at 1.02% vs 1.32% for on-time first orders.

-- by first-order review score
SELECT
    first_review_score,
    COUNT(*) AS customers,
    SUM(returned_90) AS returned_within_90_days,
    ROUND(AVG(returned_90) * 100, 2) AS return_rate_90d
FROM customer_first_order
WHERE first_date >= '2017-01-01'
  AND first_date <  '2018-06-01'
GROUP BY first_review_score
ORDER BY first_review_score;
-- Result: 90-day return rate rises from 1.02% for 1-star first orders to 1.43% for 5-star ones.

-- END OF THE QUERIES 
-- FOR WRITE UP AND IN DETAIL MARKDOWNS SEE README.md