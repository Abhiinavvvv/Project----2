CREATE DATABASE retail_analytics;
USE retail_analytics;


CREATE TABLE sales (
  order_id VARCHAR(10) PRIMARY KEY,
  order_date DATE,
  customer_id VARCHAR(10),
  product_id VARCHAR(10),
  store_id VARCHAR(10),
  sales_channel VARCHAR(20),
  quantity INT,
  unit_price FLOAT,
  discount_pct FLOAT,
  total_amount FLOAT,
  cost_price FLOAT,
  profit FLOAT,
  is_returned INT,
  order_month VARCHAR(7),
  order_year INT
);
CREATE TABLE customers (
  customer_id VARCHAR(10) PRIMARY KEY,
  first_name VARCHAR(50),
  last_name VARCHAR(50),
  gender VARCHAR(10),
  age FLOAT,
  signup_date DATE,
  region VARCHAR(20),
  age_group VARCHAR(20),
  tenure_days INT
);
CREATE TABLE products (
  product_id VARCHAR(10) PRIMARY KEY,
  product_name VARCHAR(100),
  category VARCHAR(50),
  brand VARCHAR(50),
  cost_price FLOAT,
  unit_price FLOAT,
  margin_pct FLOAT
);
CREATE TABLE stores (
  store_id VARCHAR(10) PRIMARY KEY,
  store_name VARCHAR(100),
  store_type VARCHAR(50),
  region VARCHAR(20),
  city VARCHAR(50),
  operating_cost FLOAT
);
CREATE TABLE returns (
  return_id VARCHAR(10) PRIMARY KEY,
  order_id VARCHAR(10),
  return_date DATE,
  return_reason VARCHAR(50)
);
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM stores;
SELECT COUNT(*) FROM sales;
SELECT COUNT(*) FROM returns;


UPDATE sales
SET store_id = NULL
WHERE store_id = 'Online';


-- Add relationships for the sales table
ALTER TABLE sales
  ADD CONSTRAINT fk_sales_customer
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

ALTER TABLE sales
  ADD CONSTRAINT fk_sales_product
  FOREIGN KEY (product_id) REFERENCES products(product_id);

ALTER TABLE sales
  ADD CONSTRAINT fk_sales_store
  FOREIGN KEY (store_id) REFERENCES stores(store_id);

SELECT * FROM returns;
SELECT * FROM sales LIMIT 10;
SELECT * FROM customers LIMIT 10;
SELECT * FROM products LIMIT 10;
SELECT * FROM stores LIMIT 10;
SELECT * FROM returns LIMIT 10;




-- Derived metrices 
-- Profit Calculation
SELECT 
  order_id,
  total_amount,
  cost_price,
  (total_amount - cost_price) AS profit
FROM sales
LIMIT 20;

--  Discount Percentage Calculation
SELECT 
  order_id,
  quantity,
  unit_price,
  total_amount,
  (1 - (total_amount / (quantity * unit_price))) * 100 AS discount_percent
FROM sales
LIMIT 20;

-- Customer Value
SELECT
    customer_id,
    SUM(total_amount) AS customer_value
FROM sales
GROUP BY customer_id;

-- Customer Profit Value 
SELECT
    customer_id,
    SUM(total_amount - cost_price) AS customer_profit
FROM sales
GROUP BY customer_id;

--  Return Rate by Product
SELECT 
    p.product_id,
    p.product_name,
    COUNT(r.return_id) * 1.0 / COUNT(s.order_id) AS return_rate
FROM products p
LEFT JOIN sales s ON p.product_id = s.product_id
LEFT JOIN returns r ON s.order_id = r.order_id
GROUP BY p.product_id, p.product_name;

-- Total revenue
SELECT SUM(total_amount) AS total_revenue FROM sales;





-- BUSINESS QUESTIONS

-- 1. What is the total revenue generated in the last 12 months?
SELECT SUM(total_amount) AS total_revenue
FROM sales
WHERE order_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH);

-- 2. Which are the top 5 best-selling products by quantity?
SELECT p.product_id, p.product_name, SUM(s.quantity) AS total_quantity
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_quantity DESC
LIMIT 5;

-- 3. How many customers are from each region? 
SELECT st.region, COUNT(DISTINCT c.customer_id) AS customer_count
FROM customers c
JOIN sales s ON c.customer_id = s.customer_id
JOIN stores st ON s.store_id = st.store_id
GROUP BY st.region;

-- 4. Which store has the highest profit in the past year?
SELECT st.store_id, st.store_name, SUM(s.total_amount - s.cost_price) AS total_profit
FROM sales s
JOIN stores st ON s.store_id = st.store_id
WHERE s.order_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
GROUP BY st.store_id, st.store_name
ORDER BY total_profit DESC
LIMIT 1;

-- 5. What is the return rate by product category?
SELECT p.category,
       100 * COUNT(r.return_id) * 1.0 / COUNT(s.order_id) AS return_rate_percent
FROM products p
LEFT JOIN sales s ON p.product_id = s.product_id
LEFT JOIN returns r ON s.order_id = r.order_id
GROUP BY p.category;

-- 6. What is the average revenue per customer by age group?
SELECT age_group, AVG(total_spent) AS avg_revenue
FROM (
  SELECT c.customer_id, c.age_group, SUM(s.total_amount) AS total_spent
  FROM sales s
  JOIN customers c ON s.customer_id = c.customer_id
  GROUP BY c.customer_id, c.age_group
) sub
GROUP BY age_group;

-- 7. Which sales channel (Online vs In-Store) is more profitable on average?
SELECT s.sales_channel, AVG(s.total_amount - s.cost_price) AS avg_profit
FROM sales s
GROUP BY s.sales_channel;


-- 8. How has monthly profit changed over the last 2 years by region?
SELECT (DATE_FORMAT(s.order_date, '%b-%Y')) AS month, st.region, SUM(s.total_amount - s.cost_price) AS profit
FROM sales s
JOIN stores st ON s.store_id = st.store_id
WHERE s.order_date >= DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
GROUP BY month, st.region
ORDER BY month, st.region;


-- 9. Identify the top 3 products with the highest return rate in each category.
WITH product_stats AS (
  SELECT
    p.category,
    p.product_id,
    p.product_name,
    COUNT(DISTINCT s.order_id) AS total_sales,
    COUNT(DISTINCT r.return_id) AS returns,
    COUNT(DISTINCT r.return_id) * 1.0 / COUNT(DISTINCT s.order_id) AS return_rate
  FROM products p
  LEFT JOIN sales s ON p.product_id = s.product_id
  LEFT JOIN returns r ON s.order_id = r.order_id
  GROUP BY p.category, p.product_id, p.product_name
)
SELECT
  category, product_id, product_name, return_rate
FROM (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY category ORDER BY return_rate DESC) AS rn
  FROM product_stats
) ranked
WHERE rn <= 3
ORDER BY category, return_rate DESC;


-- 10. Which 5 customers have contributed the most to total profit, and what is their tenure with the company?
SELECT 
  c.customer_id, 
  c.first_name, 
  c.last_name,
  SUM(s.total_amount - s.cost_price) AS total_profit,
  c.tenure_days
FROM sales s
JOIN customers c ON s.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.tenure_days
ORDER BY total_profit DESC
LIMIT 5;


drop database retail_analytics