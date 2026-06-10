-- ============================================================
-- TABLE OVERVIEW
-- sales_pipeline  : 8,800 rows — main fact table
-- sales_teams     : 35 rows   — agent + manager + region
-- products        : 7 rows    — product + series + price
-- accounts        : 85 rows   — company + sector + location
-- ============================================================


-- ============================================================
-- OBJECTIVE 1: PIPELINE METRICS
-- Assess overall sales pipeline health
-- ============================================================

-- Query 1: Opportunities created each month
-- Business Question: When are deals being created? Which month is busiest?
-- LEFT(engage_date, 7) extracts YYYY-MM from the date string

SELECT
    LEFT(engage_date, 7)      AS month,
    COUNT(opportunity_id)     AS total_opportunities
FROM sales_pipeline
WHERE engage_date IS NOT NULL
  AND engage_date != ''
GROUP BY month
ORDER BY total_opportunities DESC;


-- Query 2: Average days to close — Won vs Lost
-- Business Question: How long does it take to close a deal?
--                    Do Won deals take longer than Lost?
-- DATEDIFF calculates days between two dates
-- Only include closed deals (Won or Lost) — Engaging/Prospecting skew the average

SELECT
    deal_stage,
    COUNT(*)                                          AS total_deals,
    ROUND(AVG(DATEDIFF(close_date, engage_date)), 1)  AS avg_days_to_close
FROM sales_pipeline
WHERE deal_stage IN ('Won', 'Lost')
  AND close_date IS NOT NULL
  AND engage_date IS NOT NULL
GROUP BY deal_stage
ORDER BY avg_days_to_close DESC;


-- Query 3: Deal stage breakdown — percentage of each stage
-- Business Question: What share of deals are Won, Lost, Engaging, Prospecting?
-- Subquery returns total row count (8800) for percentage calculation

SELECT
    deal_stage,
    COUNT(*)                                                        AS total_deals,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM sales_pipeline), 1) AS percentage
FROM sales_pipeline
GROUP BY deal_stage
ORDER BY total_deals DESC;


-- Query 4: Win rate per product
-- Business Question: Which product has the highest win rate?
-- CASE WHEN counts Won deals as 1, everything else as 0
-- Only include closed deals to get meaningful win rate

SELECT
    product,
    COUNT(*)                                                              AS total_deals,
    SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END)                  AS won_deals,
    ROUND(SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                                          AS win_rate_pct
FROM sales_pipeline
WHERE deal_stage IN ('Won', 'Lost')
GROUP BY product
ORDER BY win_rate_pct DESC;


-- ============================================================
-- OBJECTIVE 2: SALES AGENT PERFORMANCE
-- Assess individual agents, managers, and regional offices
-- ============================================================


-- Query 5: Win rate per sales agent
-- Business Question: Who is the most effective closer?
-- Same CASE WHEN pattern as Query 4 — just grouped by agent

SELECT
    sales_agent,
    COUNT(*)                                                              AS total_deals,
    SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END)                  AS won_deals,
    ROUND(SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                                          AS win_rate_pct
FROM sales_pipeline
WHERE deal_stage IN ('Won', 'Lost')
GROUP BY sales_agent
ORDER BY win_rate_pct DESC;


-- Query 6: Total revenue by sales agent
-- Business Question: Who generated the most revenue?
-- Only Won deals have close_value — Lost deals are NULL

SELECT
    sales_agent,
    ROUND(SUM(close_value), 0)  AS total_revenue
FROM sales_pipeline
WHERE deal_stage = 'Won'
GROUP BY sales_agent
ORDER BY total_revenue DESC;


-- Query 7: Win rate by manager
-- Business Question: Which manager leads the highest performing team?
-- Requires JOIN to get manager name from sales_teams table

SELECT
    st.manager,
    COUNT(*)                                                              AS total_deals,
    SUM(CASE WHEN sp.deal_stage = 'Won' THEN 1 ELSE 0 END)               AS won_deals,
    ROUND(SUM(CASE WHEN sp.deal_stage = 'Won' THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                                          AS win_rate_pct
FROM sales_pipeline sp
JOIN sales_teams st ON sp.sales_agent = st.sales_agent
WHERE sp.deal_stage IN ('Won', 'Lost')
GROUP BY st.manager
ORDER BY win_rate_pct DESC;


-- Query 8: GTX Plus Pro — units sold by regional office
-- Business Question: Which region sells the most of our premium product?
-- Filter by specific product and Won deals only

SELECT
    st.regional_office,
    COUNT(*)  AS units_sold
FROM sales_pipeline sp
JOIN sales_teams st ON sp.sales_agent = st.sales_agent
WHERE sp.product = 'GTX Plus Pro'
  AND sp.deal_stage = 'Won'
GROUP BY st.regional_office
ORDER BY units_sold DESC;


-- ============================================================
-- OBJECTIVE 3: PRODUCT ANALYSIS
-- Assess product portfolio performance
-- ============================================================


-- Query 9: March deals — top product by revenue vs units sold
-- Business Question: In March, which product made most money?
--                    Is it the same one sold most often?
-- LEFT(close_date, 7) = '2017-03' filters for March 2017

SELECT
    product,
    COUNT(*)                    AS units_sold,
    ROUND(SUM(close_value), 0)  AS total_revenue
FROM sales_pipeline
WHERE deal_stage = 'Won'
  AND LEFT(close_date, 7) = '2017-03'
GROUP BY product
ORDER BY total_revenue DESC;


-- Query 10: Avg difference between listed price and actual close value
-- Business Question: Are we discounting? By how much per product?
-- Positive value = sold below list price (discount given)
-- Requires JOIN to get sales_price from products table

SELECT
    sp.product,
    ROUND(AVG(p.sales_price - sp.close_value), 0)  AS avg_discount
FROM sales_pipeline sp
JOIN products p ON sp.product = p.product
WHERE sp.deal_stage = 'Won'
GROUP BY sp.product
ORDER BY avg_discount DESC;


-- Query 11: Total revenue by product series
-- Business Question: Which product family (GTX / MG / GTK) performs best?
-- Requires JOIN to get series from products table

SELECT
    p.series,
    ROUND(SUM(sp.close_value), 0)  AS total_revenue,
    COUNT(*)                        AS units_sold
FROM sales_pipeline sp
JOIN products p ON sp.product = p.product
WHERE sp.deal_stage = 'Won'
GROUP BY p.series
ORDER BY total_revenue DESC;


-- ============================================================
-- OBJECTIVE 4: ACCOUNT ANALYSIS
-- Understand the company's customer base
-- ============================================================


-- Query 12: Revenue by office location
-- Business Question: Which country/region has the lowest account revenue?
-- Uses accounts.revenue (annual company revenue in $M) — not sales pipeline

SELECT
    office_location,
    ROUND(SUM(revenue), 0)  AS total_revenue
FROM accounts
GROUP BY office_location
ORDER BY total_revenue ASC;


-- Query 13: Gap between oldest and newest customer
-- Business Question: How old is our customer base? Who is oldest and newest?
-- Subqueries in SELECT retrieve company names alongside MIN/MAX years

SELECT
    (SELECT account FROM accounts
     WHERE year_established = (SELECT MAX(year_established) FROM accounts)) AS newest_company,
    (SELECT MAX(year_established) FROM accounts)                             AS newest_year,
    (SELECT account FROM accounts
     WHERE year_established = (SELECT MIN(year_established) FROM accounts)) AS oldest_company,
    (SELECT MIN(year_established) FROM accounts)                             AS oldest_year,
    (SELECT MAX(year_established) - MIN(year_established) FROM accounts)    AS gap_years;


-- Query 14: Subsidiary accounts with most lost opportunities
-- Business Question: Are subsidiary companies losing more deals?
-- Filter accounts where subsidiary_of is not empty = subsidiary companies

SELECT
    sp.account,
    COUNT(*)  AS lost_deals
FROM sales_pipeline sp
JOIN accounts a ON sp.account = a.account
WHERE sp.deal_stage = 'Lost'
  AND a.subsidiary_of IS NOT NULL
  AND a.subsidiary_of != ''
GROUP BY sp.account
ORDER BY lost_deals DESC;


-- Query 15: Total revenue — Acme Corporation + all subsidiaries
-- Business Question: What is Acme Corp's true total revenue including subsidiaries?
-- This is the FINAL PROJECT ANSWER to submit on Maven Analytics
-- Includes Acme itself AND any company where subsidiary_of = 'Acme Corporation'

SELECT
    ROUND(SUM(sp.close_value), 0)  AS acme_total_revenue
FROM sales_pipeline sp
JOIN accounts a ON sp.account = a.account
WHERE sp.deal_stage = 'Won'
  AND (a.account = 'Acme Corporation'
       OR a.subsidiary_of = 'Acme Corporation');

-- ============================================================
