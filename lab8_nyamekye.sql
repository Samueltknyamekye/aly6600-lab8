-- ALY6600 Lab 8: CTE queries (Samuel Tweneboah-Kodua Nyamekye)

-- Task 1. Single CTE
-- Customers whose total spending exceeds the average customer total.
-- customer_spend collapses payment to one row per customer first, so
-- the average is taken over customer totals, not over individual
-- payment rows. An average of payment rows would be the average
-- transaction (about $4.20), which every customer's total exceeds.
-- Result: 285 of 599 customers spent more than the average customer
-- total of $112.53, led by customer 526 at $221.55.

WITH customer_spend AS (
    -- One row per customer: lifetime total paid
    SELECT
        pay.customer_id,
        SUM(pay.amount) AS total_spend
    FROM `sakila-aly6600.sakila.payment` AS pay
    GROUP BY pay.customer_id
)
SELECT
    cs.customer_id,
    cs.total_spend,
    ROUND((SELECT AVG(total_spend) FROM customer_spend), 2) AS avg_customer_spend
FROM customer_spend AS cs
WHERE cs.total_spend > (SELECT AVG(total_spend) FROM customer_spend)
ORDER BY cs.total_spend DESC, cs.customer_id;

-- Task 2. Chained CTEs
-- Top five cities by number of above-average-spending customers, with
-- each city's revenue from those customers.
-- Steps: customer_spend -> above_average_customers -> customer_city
--        -> final aggregation by city, ranking and LIMIT.
-- Cities are grouped by city_id, not by name alone, because Sakila
-- holds more than one city with the same name (for example London);
-- grouping by name would merge different places. Country is shown so
-- each city can be told apart. Ties on customer count are broken by
-- revenue, then by city name, so the top five is reproducible.
-- Result: Cape Coral (United States), Saint-Denis (Reunion),
-- Molodetsno (Belarus), Apeldoorn (Netherlands) and Santa Barbara
-- d'Oeste (Brazil), each with exactly 1 above-average customer. No
-- city has more than one, because Sakila's customers are spread
-- almost one per city, so the customer count cannot separate cities
-- and revenue decides the order. RANK() reports the tie honestly:
-- Apeldoorn and Santa Barbara d'Oeste both earned $194.61 and share
-- rank 4. In a real customer base, where cities hold many customers,
-- the count would carry the ranking and revenue would only break ties.

WITH customer_spend AS (
    -- Step 1: one row per customer with lifetime total paid
    SELECT
        pay.customer_id,
        SUM(pay.amount) AS total_spend
    FROM `sakila-aly6600.sakila.payment` AS pay
    GROUP BY pay.customer_id
),
above_average_customers AS (
    -- Step 2: keep customers whose total exceeds the average total
    SELECT
        cs.customer_id,
        cs.total_spend
    FROM customer_spend AS cs
    WHERE cs.total_spend > (SELECT AVG(total_spend) FROM customer_spend)
),
customer_city AS (
    -- Step 3: attach each above-average customer to a city
    -- Path: customer -> address -> city -> country
    SELECT
        aac.customer_id,
        aac.total_spend,
        cty.city_id,
        cty.city,
        ctry.country
    FROM above_average_customers               AS aac
    JOIN `sakila-aly6600.sakila.customer` AS cust ON aac.customer_id = cust.customer_id
    JOIN `sakila-aly6600.sakila.address`  AS addr ON cust.address_id = addr.address_id
    JOIN `sakila-aly6600.sakila.city`     AS cty  ON addr.city_id    = cty.city_id
    JOIN `sakila-aly6600.sakila.country`  AS ctry ON cty.country_id  = ctry.country_id
)
-- Step 4: aggregate by city, rank and keep the top five
SELECT
    RANK() OVER (ORDER BY COUNT(*) DESC, SUM(cc.total_spend) DESC) AS city_rank,
    cc.city,
    cc.country,
    COUNT(*)                     AS above_average_customers,
    ROUND(SUM(cc.total_spend), 2) AS revenue_from_these_customers
FROM customer_city AS cc
GROUP BY cc.city_id, cc.city, cc.country
ORDER BY above_average_customers DESC, revenue_from_these_customers DESC, cc.city
LIMIT 5;