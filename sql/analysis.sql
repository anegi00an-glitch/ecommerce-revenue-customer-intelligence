-- Olist Brazilian E-Commerce analysis
-- Load the public Olist CSV tables into PostgreSQL before running.

-- 1. Monthly order revenue
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month,
    ROUND(SUM(oi.price + oi.freight_value)::numeric, 2) AS gross_order_value,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT o.customer_id) AS customers
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1
ORDER BY 1;

-- 2. Average order value
SELECT
    ROUND(SUM(oi.price + oi.freight_value)::numeric / COUNT(DISTINCT o.order_id), 2) AS average_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable');

-- 3. Top product categories by merchandise revenue
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
    ROUND(SUM(oi.price)::numeric, 2) AS merchandise_revenue,
    COUNT(DISTINCT oi.order_id) AS orders,
    SUM(oi.order_item_id) AS item_lines
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY 1
ORDER BY merchandise_revenue DESC
LIMIT 20;

-- 4. Customer order frequency
WITH customer_orders AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS orders
    FROM orders
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS customers,
    COUNT(*) FILTER (WHERE orders = 1) AS one_order_customers,
    COUNT(*) FILTER (WHERE orders > 1) AS repeat_customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE orders > 1) / COUNT(*)::numeric, 2) AS repeat_customer_pct
FROM customer_orders;

-- 5. Review score by delivery timeliness
SELECT
    CASE
        WHEN o.order_delivered_customer_date::date <= o.order_estimated_delivery_date::date THEN 'on_or_before_estimate'
        ELSE 'late'
    END AS delivery_status,
    COUNT(DISTINCT r.review_id) AS reviews,
    ROUND(AVG(r.review_score)::numeric, 2) AS avg_review_score
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- 6. Payment-method mix
SELECT
    payment_type,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(payment_value)::numeric, 2) AS payment_value,
    ROUND(100.0 * SUM(payment_value) / SUM(SUM(payment_value)) OVER (), 2) AS payment_share_pct
FROM order_payments
GROUP BY payment_type
ORDER BY payment_value DESC;

-- 7. Seller concentration
SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id) AS orders,
    ROUND(SUM(oi.price)::numeric, 2) AS merchandise_revenue
FROM order_items oi
GROUP BY oi.seller_id
ORDER BY merchandise_revenue DESC
LIMIT 25;
