-- product_performance_report.sql
-- PostgreSQL 16
-- All five reports use CTEs for readability.
-- Revenue is based on completed orders only.

-- ============================================================
-- R1 — Product dashboard
-- ============================================================
WITH product_sales AS (
    SELECT
        p.id AS product_id,
        p.name AS product_name,
        c.name AS category,
        p.price AS list_price,
        COALESCE(SUM(CASE WHEN o.status = 'completed' THEN oi.quantity ELSE 0 END), 0) AS total_units_sold,
        COALESCE(SUM(
            CASE
                WHEN o.status = 'completed'
                THEN oi.quantity * oi.unit_price
                ELSE 0
            END
        ), 0) AS total_revenue
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN order_items oi ON p.id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.id
    GROUP BY p.id, p.name, c.name, p.price
),
product_metrics AS (
    SELECT
        *,
        RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        SUM(total_revenue) OVER () AS all_product_revenue
    FROM product_sales
)
SELECT
    product_name AS name,
    category,
    list_price,
    total_units_sold,
    total_revenue,
    revenue_rank,
    ROUND((100.0 * total_revenue / NULLIF(all_product_revenue, 0))::numeric, 2) AS revenue_share_pct
FROM product_metrics
ORDER BY revenue_rank, name;


-- ============================================================
-- R2 — Monthly trend by category
-- ============================================================
WITH monthly_category_revenue AS (
    SELECT
        c.id AS category_id,
        c.name AS category,
        DATE_TRUNC('month', o.order_date)::date AS month,
        SUM(oi.quantity * oi.unit_price) AS monthly_revenue
    FROM categories c
    JOIN products p ON p.category_id = c.id
    JOIN order_items oi ON oi.product_id = p.id
    JOIN orders o ON o.id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY c.id, c.name, DATE_TRUNC('month', o.order_date)
),
trend_metrics AS (
    SELECT
        category,
        month,
        monthly_revenue,
        LAG(monthly_revenue) OVER (
            PARTITION BY category ORDER BY month
        ) AS previous_month_revenue,
        SUM(monthly_revenue) OVER (
            PARTITION BY category
            ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue
    FROM monthly_category_revenue
)
SELECT
    category,
    TO_CHAR(month, 'YYYY-MM') AS month,
    monthly_revenue,
    previous_month_revenue,
    CASE
        WHEN previous_month_revenue IS NULL OR previous_month_revenue = 0 THEN NULL
        ELSE ROUND(
            (
                100.0 * (monthly_revenue - previous_month_revenue)
                / previous_month_revenue
            )::numeric,
            2
        )
    END AS mom_growth_pct,
    cumulative_revenue
FROM trend_metrics
ORDER BY category, month;


-- ============================================================
-- R3 — ABC product segmentation
-- ============================================================
WITH product_revenue AS (
    SELECT
        p.id AS product_id,
        p.name AS product_name,
        COALESCE(SUM(
            CASE
                WHEN o.status = 'completed'
                THEN oi.quantity * oi.unit_price
                ELSE 0
            END
        ), 0) AS total_revenue
    FROM products p
    LEFT JOIN order_items oi ON p.id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.id
    GROUP BY p.id, p.name
),
ranked_revenue AS (
    SELECT
        *,
        SUM(total_revenue) OVER (
            ORDER BY total_revenue DESC, product_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue,
        SUM(total_revenue) OVER () AS all_revenue
    FROM product_revenue
),
abc_metrics AS (
    SELECT
        *,
        100.0 * cumulative_revenue / NULLIF(all_revenue, 0) AS cumulative_revenue_pct
    FROM ranked_revenue
)
SELECT
    product_name,
    total_revenue,
    ROUND(cumulative_revenue_pct::numeric, 2) AS cumulative_revenue_pct,
    CASE
        WHEN cumulative_revenue_pct <= 80 THEN 'A'
        WHEN cumulative_revenue_pct <= 95 THEN 'B'
        ELSE 'C'
    END AS abc_segment
FROM abc_metrics
ORDER BY total_revenue DESC, product_name;


-- ============================================================
-- R4 — Market basket analysis
-- ============================================================
WITH completed_order_products AS (
    SELECT DISTINCT
        oi.order_id,
        oi.product_id,
        p.name AS product_name
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    JOIN products p ON oi.product_id = p.id
    WHERE o.status = 'completed'
),
product_pairs AS (
    SELECT
        a.product_name AS product_1,
        b.product_name AS product_2,
        a.order_id
    FROM completed_order_products a
    JOIN completed_order_products b
        ON a.order_id = b.order_id
       AND a.product_id < b.product_id
)
SELECT
    product_1,
    product_2,
    COUNT(*) AS times_bought_together
FROM product_pairs
GROUP BY product_1, product_2
ORDER BY times_bought_together DESC, product_1, product_2;


-- ============================================================
-- R5 — Product health score
-- ============================================================
WITH product_activity AS (
    SELECT
        p.id AS product_id,
        p.name AS product_name,
        COUNT(DISTINCT CASE
            WHEN o.status = 'completed' THEN o.id
        END) AS sales_frequency,
        COALESCE(SUM(CASE
            WHEN o.status = 'completed'
            THEN oi.quantity * oi.unit_price
            ELSE 0
        END), 0) AS total_revenue,
        MAX(CASE
            WHEN o.status = 'completed' THEN o.order_date
        END) AS last_sale_date
    FROM products p
    LEFT JOIN order_items oi ON p.id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.id
    GROUP BY p.id, p.name
),
recency_metrics AS (
    SELECT
        *,
        DATE '2024-06-30' - last_sale_date AS days_since_last_sale
    FROM product_activity
),
percentile_metrics AS (
    SELECT
        *,
        PERCENT_RANK() OVER (ORDER BY sales_frequency) AS sales_frequency_pct,
        PERCENT_RANK() OVER (ORDER BY total_revenue) AS revenue_pct,
        -- Fewer days since last sale = better recency, so sort ascending.
        PERCENT_RANK() OVER (
            ORDER BY days_since_last_sale ASC NULLS LAST
        ) AS recency_pct
    FROM recency_metrics
)
SELECT
    product_name,
    sales_frequency,
    total_revenue,
    last_sale_date,
    days_since_last_sale,
    ROUND((100.0 * sales_frequency_pct)::numeric, 2) AS sales_frequency_percentile,
    ROUND((100.0 * revenue_pct)::numeric, 2) AS revenue_percentile,
    ROUND((100.0 * recency_pct)::numeric, 2) AS recency_percentile,
    ROUND(
        (100.0 * (sales_frequency_pct + revenue_pct + recency_pct) / 3)::numeric,
        2
    ) AS health_score
FROM percentile_metrics
ORDER BY health_score DESC, product_name;
