-- Independent portfolio SQL
-- Dataset: Olist Brazilian E-Commerce Public Dataset

-- 1) Order-level KPI base
WITH order_base AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_status,
        o.order_purchase_timestamp::timestamp AS purchased_at,
        o.order_delivered_customer_date::timestamp AS delivered_at,
        o.order_estimated_delivery_date::timestamp AS estimated_delivery_at
    FROM olist.orders o
),
item_value AS (
    SELECT
        order_id,
        SUM(price) AS item_revenue,
        SUM(freight_value) AS freight_revenue
    FROM olist.order_items
    GROUP BY order_id
)
SELECT
    COUNT(*) AS orders,
    COUNT(*) FILTER (WHERE order_status = 'delivered') AS delivered_orders,
    ROUND(SUM(COALESCE(item_revenue, 0))::numeric, 2) AS item_revenue,
    ROUND(SUM(COALESCE(freight_revenue, 0))::numeric, 2) AS freight_revenue,
    ROUND(SUM(COALESCE(item_revenue, 0) + COALESCE(freight_revenue, 0))::numeric, 2) AS gross_order_value
FROM order_base
LEFT JOIN item_value USING (order_id);

-- 2) Monthly commercial trend
WITH order_value AS (
    SELECT
        o.order_id,
        DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM olist.orders o
    JOIN olist.order_items oi ON oi.order_id = o.order_id
    GROUP BY 1, 2
)
SELECT
    month,
    COUNT(*) AS orders,
    ROUND(SUM(order_value)::numeric, 2) AS revenue,
    ROUND(AVG(order_value)::numeric, 2) AS average_order_value
FROM order_value
GROUP BY month
ORDER BY month;

-- 3) Delivery performance and customer experience
WITH delivery AS (
    SELECT
        o.order_id,
        CASE
            WHEN o.order_delivered_customer_date IS NULL THEN 'not_delivered'
            WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 'on_time'
            ELSE 'late'
        END AS delivery_status
    FROM olist.orders o
),
reviews AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM olist.order_reviews
    GROUP BY order_id
)
SELECT
    d.delivery_status,
    COUNT(*) AS orders,
    ROUND(AVG(r.review_score)::numeric, 2) AS avg_review_score
FROM delivery d
LEFT JOIN reviews r USING (order_id)
GROUP BY d.delivery_status
ORDER BY d.delivery_status;
