# SQL Foundations — E-commerce Analytics

A beginner-friendly PostgreSQL portfolio project that analyzes a six-month e-commerce dataset using core SQL, joins, aggregation, window functions, CTEs, and business-focused reporting.

## Dataset

The demo dataset represents an e-commerce business from **January–June 2024**:

- **5 tables:** `customers`, `categories`, `products`, `orders`, `order_items`
- **50 customers** across 8 countries
- **13 categories** arranged in a simple parent/child hierarchy
- **30 products**
- **73 orders** across completed, cancelled, refunded, pending, and processing statuses
- **65 order-item rows**
- Revenue analysis generally uses **completed orders only** and calculates product revenue as `quantity × unit_price`.

## Key queries

### Business queries — Q1–Q10

1. **Q1 — Top customers:** Finds the five customers generating the most completed-order revenue.
2. **Q2 — Monthly revenue:** Tracks completed revenue, completed orders, and average order value by month.
3. **Q3 — Revenue by country:** Shows completed revenue and each country's share of total revenue.
4. **Q4 — Top products:** Identifies the ten products generating the most completed-order revenue.
5. **Q5 — Cancellation/refund rate:** Measures the monthly percentage of orders that were cancelled or refunded.
6. **Q6 — Premium vs non-premium:** Compares customer activity and revenue between premium and non-premium segments.
7. **Q7 — Never-ordered products:** Finds products with no matching order items.
8. **Q8 — Category sales:** Summarizes completed units sold, revenue, and average selling price by category.
9. **Q9 — Customer growth:** Counts monthly signups and calculates the cumulative customer base.
10. **Q10 — Customer inactivity:** Finds customers with no completed order in the three months leading up to the dataset's June 30, 2024 analysis cutoff.

### Product performance report — R1–R5

1. **R1 — Product dashboard:** Product revenue, units sold, revenue rank, and revenue share.
2. **R2 — Category trends:** Monthly category revenue with previous-month comparison, MoM growth, and cumulative revenue.
3. **R3 — ABC segmentation:** Classifies products into A/B/C groups using cumulative revenue contribution.
4. **R4 — Market basket analysis:** Finds product pairs purchased together in completed orders.
5. **R5 — Product health score:** Combines sales frequency, revenue, and sales recency into a normalized 0–100-style score.

## Results

The following observations come directly from the demo data and the completed-order revenue logic used in the queries:

- **MacBook Pro 16" generated $17,493 in completed-order revenue**, about **35.6%** of the $49,135 completed-order revenue represented by the order-item data.
- **Premium customers averaged about $1,507 in completed revenue per customer**, compared with about **$758 for non-premium customers** in this sample.
- **France generated $12,504 in completed-order revenue**, the largest country total in the dataset, representing about **25.5%** of completed revenue.

These are descriptive findings from a small demo dataset, not general conclusions about real-world e-commerce behavior.

## Stack

- **PostgreSQL 16**
- SQL
- CTEs
- Aggregate functions
- `CASE`, `FILTER`, and `COALESCE`
- Window functions including `RANK`, `LAG`, `SUM OVER`, and `PERCENT_RANK`

## Repository structure

```text
sql-foundations/
├── README.md
├── schema.sql
├── seed.sql
├── business_queries.sql
└── product_performance_report.sql
```

## How to run

Run the scripts in this order in a PostgreSQL 16 database:

```sql
\i schema.sql
\i seed.sql
\i business_queries.sql
\i product_performance_report.sql
```

The last two files contain multiple standalone queries, so run individual sections when exploring specific results.
