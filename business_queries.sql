-- business_queries.sql
-- PostgreSQL 16
-- Revenue analysis uses completed orders unless otherwise stated.

-- ============================================================
-- Q1 — Top 5 customers by completed-order revenue
-- ============================================================
SELECT
    c.id,
    c.name,
    COUNT(DISTINCT o.id) AS completed_orders,
    SUM(oi.quantity * oi.unit_price) AS completed_revenue
FROM customers c
JOIN orders o
    ON c.id = o.customer_id
JOIN order_items oi
    ON o.id = oi.order_id
WHERE o.status = 'completed'
GROUP BY c.id, c.name
ORDER BY completed_revenue DESC
LIMIT 5;


-- ============================================================
-- Q2 — Monthly completed revenue
-- ============================================================
WITH completed_order_values AS (
    SELECT
        o.id AS order_id,
        DATE_TRUNC('month', o.order_date)::date AS month,
        o.total_amount
    FROM orders o
    WHERE o.status = 'completed'
),
monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::date AS month,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM orders o
    JOIN order_items oi
        ON o.id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT
    m.month,
    COUNT(c.order_id) AS completed_orders,
    m.revenue,
    ROUND(AVG(c.total_amount)::numeric, 2) AS avg_order_value
FROM monthly_revenue m
JOIN completed_order_values c
    ON m.month = c.month
GROUP BY m.month, m.revenue
ORDER BY m.month;


-- ============================================================
-- Q3 — Revenue by shipping country and share of total
-- ============================================================
WITH country_revenue AS (
    SELECT
        o.shipping_country AS country,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM orders o
    JOIN order_items oi
        ON o.id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY o.shipping_country
)
SELECT
    country,
    revenue,
    ROUND(
        (100.0 * revenue / NULLIF(SUM(revenue) OVER (), 0))::numeric,
        2
    ) AS revenue_share_pct
FROM country_revenue
ORDER BY revenue DESC;


-- ============================================================
-- Q4 — Top 10 products by completed-order revenue
-- ============================================================
SELECT
    p.id,
    p.name AS product_name,
    c.name AS category,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.quantity * oi.unit_price) AS revenue
FROM products p
JOIN categories c
    ON p.category_id = c.id
JOIN order_items oi
    ON p.id = oi.product_id
JOIN orders o
    ON oi.order_id = o.id
WHERE o.status = 'completed'
GROUP BY p.id, p.name, c.name
ORDER BY revenue DESC
LIMIT 10;


-- ============================================================
-- Q5 — Monthly cancellation/refund rate
-- ============================================================
SELECT
    DATE_TRUNC('month', order_date)::date AS month,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE status IN ('cancelled', 'refunded')
    ) AS cancelled_or_refunded,
    ROUND(
        (
            100.0 * COUNT(*) FILTER (
                WHERE status IN ('cancelled', 'refunded')
            ) / NULLIF(COUNT(*), 0)
        )::numeric,
        2
    ) AS cancellation_refund_rate_pct
FROM orders
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY month;


-- ============================================================
-- Q6 — Premium vs non-premium customer behavior
-- ============================================================
WITH customer_metrics AS (
    SELECT
        c.id AS customer_id,
        c.is_premium,
        COUNT(DISTINCT o.id) FILTER (
            WHERE o.status = 'completed'
        ) AS completed_orders,
        COALESCE(
            SUM(oi.quantity * oi.unit_price) FILTER (
                WHERE o.status = 'completed'
            ),
            0
        ) AS completed_revenue
    FROM customers c
    LEFT JOIN orders o
        ON c.id = o.customer_id
    LEFT JOIN order_items oi
        ON o.id = oi.order_id
    GROUP BY c.id, c.is_premium
)
SELECT
    CASE WHEN is_premium THEN 'Premium' ELSE 'Non-premium' END AS customer_segment,
    COUNT(*) AS customers,
    COUNT(*) FILTER (WHERE completed_orders > 0) AS customers_with_completed_orders,
    SUM(completed_orders) AS completed_orders,
    SUM(completed_revenue) AS total_revenue,
    ROUND(AVG(completed_revenue)::numeric, 2) AS avg_revenue_per_customer
FROM customer_metrics
GROUP BY is_premium
ORDER BY is_premium DESC;


-- ============================================================
-- Q7 — Products never ordered
-- ============================================================
SELECT
    p.id,
    p.name,
    p.price,
    p.stock_quantity
FROM products p
LEFT JOIN order_items oi
    ON p.id = oi.product_id
WHERE oi.product_id IS NULL
ORDER BY p.name;


-- ============================================================
-- Q8 — Category sales summary
-- ============================================================
SELECT
    c.id,
    c.name AS category,
    COALESCE(SUM(
        CASE WHEN o.status = 'completed' THEN oi.quantity ELSE 0 END
    ), 0) AS units_sold,
    COALESCE(SUM(
        CASE
            WHEN o.status = 'completed'
            THEN oi.quantity * oi.unit_price
            ELSE 0
        END
    ), 0) AS revenue,
    ROUND(
        (
            COALESCE(SUM(
                CASE
                    WHEN o.status = 'completed'
                    THEN oi.quantity * oi.unit_price
                    ELSE 0
                END
            ), 0)
            / NULLIF(
                SUM(CASE WHEN o.status = 'completed' THEN oi.quantity ELSE 0 END),
                0
            )
        )::numeric,
        2
    ) AS avg_selling_price
FROM categories c
LEFT JOIN products p
    ON c.id = p.category_id
LEFT JOIN order_items oi
    ON p.id = oi.product_id
LEFT JOIN orders o
    ON oi.order_id = o.id
GROUP BY c.id, c.name
ORDER BY revenue DESC;


-- ============================================================
-- Q9 — Monthly signups with cumulative customer count
-- ============================================================
WITH monthly_signups AS (
    SELECT
        DATE_TRUNC('month', signup_date)::date AS month,
        COUNT(*) AS new_customers
    FROM customers
    GROUP BY DATE_TRUNC('month', signup_date)
)
SELECT
    month,
    new_customers,
    SUM(new_customers) OVER (
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_customers
FROM monthly_signups
ORDER BY month;


-- ============================================================
-- Q10 — Customers inactive for 3+ months
-- Dataset analysis end date: 2024-06-30
-- Customers with no completed order are also included.
-- ============================================================
WITH last_completed_order AS (
    SELECT
        customer_id,
        MAX(order_date) AS last_order_date
    FROM orders
    WHERE status = 'completed'
    GROUP BY customer_id
)
SELECT
    c.id,
    c.name,
    c.country,
    l.last_order_date,
    DATE '2024-06-30' - l.last_order_date AS days_since_last_order
FROM customers c
LEFT JOIN last_completed_order l
    ON c.id = l.customer_id
WHERE l.last_order_date IS NULL
   OR l.last_order_date <= DATE '2024-03-31'
ORDER BY l.last_order_date NULLS FIRST, c.name;
