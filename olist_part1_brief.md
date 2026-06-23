# Data Academy · The Olist Challenge — Part 1

## From raw CSV to a clean data layer

---

## The case

You are the data team at **Olist**, a marketplace connecting thousands of small sellers with customers across Brazil. Leadership has no visibility into the business: they don't know how much they really sell, why customers complain, or which sellers perform.

Data arrives from the operational system raw and dirty. Your job is to build the pipeline that turns that chaos into trusted information leadership can act on.

This is a real data-consultancy engagement: what a client pays for isn't the pretty chart — it's the governed pipeline behind it.

> **Scope of Part 1.** In this first delivery you build the pipeline from raw data up to a **clean, typed STAGING layer**. Business modeling (CORE), the BI layer and the dashboard come in Part 2. Foundations first.

---

## The stack

| Tool | Role in Part 1 |
|---|---|
| **Git** | Version control from minute one |
| **Python** | Ingestion of the CSVs into Snowflake's RAW layer |
| **Snowflake** | Warehouse where the 4 layers live (medallion) |
| **dbt Cloud** | In-warehouse cleaning and transformation (STAGING layer) |

The architecture is **medallion**: one schema per layer. In Part 1 you work the first two.

```
RAW  →  STAGING  →  [ CORE  →  BI ]   ← Part 2
raw      clean
```

---

## The dataset

Real Brazilian e-commerce (2016–2018): **9 tables, ~100,000 orders**. Everything centers on `orders`. Before touching anything, study the entity-relationship diagram (ERD) and understand which keys join the tables.

Tables: `orders`, `customers`, `order_items`, `order_payments`, `order_reviews`, `products`, `sellers`, `geolocation`, `product_category_name_translation`.

---

## The phases

### Phase 0 — Get the data & set up the repo

**0.1 — Generate your Kaggle API token**

The dataset lives on Kaggle and is downloaded programmatically, which needs a personal API token. Generate your own:

1. Log in to Kaggle and go to **Settings** (top-right menu, under your avatar).
2. Scroll to the **API** section and click **Create New Token**.
3. A token is generated. **Copy it immediately** — Kaggle won't show it again.
4. Place it **outside the repo**, in your home folder, with restricted permissions:
   - **macOS / Linux / WSL:** save it to `~/.kaggle/kaggle.json` (or `~/.kaggle/access_token` if you got an `access_token`-style key), then `chmod 600` it.
   - **Windows (native):** save it to `C:\Users\<you>\.kaggle\kaggle.json`. Restrict access to your user only.

> **Why this way?** A token is a **personal secret**. Each of you uses your own — never shared, never written into the repo or this document. This is exactly how access is granted in a real engagement: you receive your own credential, you keep it safe. Sharing one key across a team causes rate-limit and security problems.

**0.2 — Set up the repository**

- Create the repo with a clear folder structure and initialize git.
- Write a `.gitignore` that makes it **impossible** to commit a secret or a dataset.
- Write a **reproducible, idempotent** download script for the dataset.

```gitignore
# secrets — never versioned
.kaggle/
kaggle.json
access_token
*.env
.env
# data — never versioned
data/raw_csv/
*.csv
*.zip
# build artifacts
target/
dbt_packages/
__pycache__/
```

> **Why this way?** Whatever can be automated gets automated — a manual download isn't reproducible. And the `.gitignore` is your safety net: even if you `git add` everything by accident, secrets and data stay out.

**Deliverable:** initialized repo, correct `.gitignore`, download script, and the 9 CSVs locally.

### Phase 1 — Build the Snowflake layers

Create the project database and the four schemas.

```sql
CREATE DATABASE IF NOT EXISTS DATA_ACADEMY;
USE DATABASE DATA_ACADEMY;

CREATE SCHEMA IF NOT EXISTS RAW;       -- raw data, as it lands
CREATE SCHEMA IF NOT EXISTS STAGING;   -- clean and typed (dbt)
CREATE SCHEMA IF NOT EXISTS CORE;      -- star schema (dbt)
CREATE SCHEMA IF NOT EXISTS BI;        -- friendly views for consumption
```

> **Why this way?** Separating layers into schemas is what makes the pipeline auditable and lets each stage have one clear responsibility. It's the standard you'll see at any Snowflake client.

**Deliverable:** database with the four layers created.

### Phase 2 — Ingest into RAW

Load the 9 CSVs into Snowflake with a Python script (official connector, `PUT` + `COPY INTO`).

- All columns as **VARCHAR**.
- Add load metadata: `_loaded_at`, `_source_file`.
- The script must be **idempotent**: rerunning it leaves everything identical.

> **Why VARCHAR?** RAW is a faithful 1:1 copy of the source. Loading everything as text means no `COPY` ever fails because of a wrongly-guessed type, and you don't fight types during ingestion. Casting belongs in STAGING, where it's explicit and tested.

> **Why metadata columns?** `_loaded_at` and `_source_file` give you basic traceability — when a row arrived and which file it came from. It's cheap to add and invaluable when something looks off later.

**Deliverable:** the 9 tables populated in `RAW` + a verification query with row counts per table.

### Phase 3 — Data quality (profiling)

Dirt isn't visible by looking at a table — it's discovered by interrogating it. Profile the RAW layer across the **6 quality dimensions**: completeness, uniqueness, granularity, validity, integrity, types.

> **Why profile before cleaning?** You can't fix what you haven't measured. The profiling tells you *exactly* what to clean and how much — and it produces the evidence for your quality report. Cleaning blind leads to wrong assumptions.

Use the cheat sheet below. As a minimum you must detect and describe: the `geolocation` duplicates, the `customer_id` vs `customer_unique_id` difference, the typos in `products` columns, and the nulls in `orders` dates.

**Deliverable:** a report (queries + findings) documenting the dirt found, organized by dimension.

### Phase 4 — Staging in dbt

Build the STAGING layer: **one `stg_` view per source table**.

- Declare the RAW tables as dbt `sources`.
- Per model: cast types, rename columns to something consistent, standardize nulls and whitespace.
- **No joins.** Each model cleans a single table.
- Special case `geolocation`: filter coordinates outside Brazil and aggregate to one point per zip code.

> **Why one view per table, with no joins?** Staging's only job is to make each source table clean and presentable on its own. Combining tables is business logic — that belongs in CORE. Keeping the boundary sharp means each layer stays simple, reusable and easy to debug.

> **Why views and not tables?** A view doesn't copy data; it's a saved query over RAW that applies the transformations on read. It costs ~0 storage. CORE will use tables because it's queried heavily and worth materializing.

**Deliverable:** a dbt project with 9 `stg_` models that run without error (`dbt run`), sources declared, and the RAW → STAGING lineage visible.

---

## Profiling cheat sheet

Run these against your `RAW` layer. They're organized by the 6 quality dimensions — copy, run, and write down what you find.

```sql
USE DATABASE DATA_ACADEMY;
USE SCHEMA RAW;

-- ============================================================
-- 0. SANITY CHECK — row counts per table
-- ============================================================
SELECT 'ORDERS' AS table_name, COUNT(*) AS rows FROM ORDERS
UNION ALL SELECT 'CUSTOMERS', COUNT(*) FROM CUSTOMERS
UNION ALL SELECT 'ORDER_ITEMS', COUNT(*) FROM ORDER_ITEMS
UNION ALL SELECT 'ORDER_PAYMENTS', COUNT(*) FROM ORDER_PAYMENTS
UNION ALL SELECT 'ORDER_REVIEWS', COUNT(*) FROM ORDER_REVIEWS
UNION ALL SELECT 'PRODUCTS', COUNT(*) FROM PRODUCTS
UNION ALL SELECT 'SELLERS', COUNT(*) FROM SELLERS
UNION ALL SELECT 'GEOLOCATION', COUNT(*) FROM GEOLOCATION
UNION ALL SELECT 'PRODUCT_CATEGORY_NAME_TRANSLATION', COUNT(*) FROM PRODUCT_CATEGORY_NAME_TRANSLATION
ORDER BY rows DESC;

-- ============================================================
-- 1. COMPLETENESS — nulls where it hurts
-- ============================================================
-- ORDERS: delivery dates are null for non-delivered / cancelled orders
SELECT
  COUNT(*)                                          AS total,
  COUNT(*) - COUNT(order_approved_at)               AS missing_approved,
  COUNT(*) - COUNT(order_delivered_customer_date)   AS missing_delivered,
  COUNT(*) - COUNT(order_delivered_carrier_date)    AS missing_shipped
FROM ORDERS;

-- ORDERS: which statuses exist? (explains the nulls above)
SELECT order_status, COUNT(*) AS rows
FROM ORDERS GROUP BY order_status ORDER BY rows DESC;

-- PRODUCTS: nulls in category and dimensions
SELECT
  COUNT(*)                                AS total,
  COUNT(*) - COUNT(product_category_name) AS missing_category,
  COUNT(*) - COUNT(product_weight_g)      AS missing_weight
FROM PRODUCTS;

-- REVIEWS: most comment fields come empty
SELECT
  COUNT(*)                                   AS total,
  COUNT(*) - COUNT(review_comment_title)     AS missing_title,
  COUNT(*) - COUNT(review_comment_message)   AS missing_message
FROM ORDER_REVIEWS;

-- ============================================================
-- 2. UNIQUENESS — duplicates in what should be unique
-- ============================================================
-- GEOLOCATION: the star offender. Many rows per zip, each with a
-- slightly different lat/lng. Must aggregate to one point per zip.
SELECT
  COUNT(*)                                                AS total_rows,
  COUNT(DISTINCT geolocation_zip_code_prefix)             AS unique_zips,
  COUNT(*) / COUNT(DISTINCT geolocation_zip_code_prefix)  AS avg_rows_per_zip
FROM GEOLOCATION;

-- GEOLOCATION: worst offenders
SELECT geolocation_zip_code_prefix, COUNT(*) AS repeats
FROM GEOLOCATION GROUP BY geolocation_zip_code_prefix
ORDER BY repeats DESC LIMIT 10;

-- REVIEWS: is review_id really unique? (there are duplicates)
SELECT review_id, COUNT(*) AS times
FROM ORDER_REVIEWS GROUP BY review_id
HAVING COUNT(*) > 1 ORDER BY times DESC LIMIT 10;

-- ============================================================
-- 3. GRANULARITY — what is one row?
-- ============================================================
-- CUSTOMERS: the classic trap. customer_id is unique PER ORDER,
-- customer_unique_id is the REAL customer. Mixing them breaks
-- repurchase rate. Look at the difference:
SELECT
  COUNT(*)                            AS rows,
  COUNT(DISTINCT customer_id)         AS customer_id_distinct,
  COUNT(DISTINCT customer_unique_id)  AS real_customers
FROM CUSTOMERS;

-- ORDER_ITEMS: one order has several lines (don't inflate amounts)
SELECT order_id, COUNT(*) AS lines
FROM ORDER_ITEMS GROUP BY order_id ORDER BY lines DESC LIMIT 10;

-- PAYMENTS: an order can have several payments
SELECT order_id, COUNT(*) AS payments
FROM ORDER_PAYMENTS GROUP BY order_id
HAVING COUNT(*) > 1 ORDER BY payments DESC LIMIT 10;

-- ============================================================
-- 4. VALIDITY — impossible or anomalous values
-- ============================================================
-- PAYMENTS: 'not_defined' payment type and installments = 0
SELECT payment_type, COUNT(*) AS rows
FROM ORDER_PAYMENTS GROUP BY payment_type ORDER BY rows DESC;

SELECT payment_installments, COUNT(*) AS rows
FROM ORDER_PAYMENTS GROUP BY payment_installments
ORDER BY TRY_TO_NUMBER(payment_installments);

-- GEOLOCATION: coordinates outside Brazil (approx lat [-34, 5], lng [-74, -34])
SELECT COUNT(*) AS coords_outside_brazil
FROM GEOLOCATION
WHERE TRY_TO_DOUBLE(geolocation_lat) NOT BETWEEN -34 AND 5
   OR TRY_TO_DOUBLE(geolocation_lng) NOT BETWEEN -74 AND -34;

-- ============================================================
-- 5. REFERENTIAL INTEGRITY — do the keys join?
-- ============================================================
-- PRODUCTS categories with NO english translation (incomplete join)
SELECT DISTINCT p.product_category_name
FROM PRODUCTS p
LEFT JOIN PRODUCT_CATEGORY_NAME_TRANSLATION t
  ON p.product_category_name = t.product_category_name
WHERE t.product_category_name IS NULL
  AND p.product_category_name IS NOT NULL;

-- Items pointing to a non-existent order? (orphan FK)
SELECT COUNT(*) AS items_without_order
FROM ORDER_ITEMS i
LEFT JOIN ORDERS o ON i.order_id = o.order_id
WHERE o.order_id IS NULL;

-- ============================================================
-- 6. DISGUISED TYPES — text hiding dates / numbers
-- ============================================================
-- In RAW everything is VARCHAR. Before casting in STAGING, check
-- the cast won't fail (TRY_TO_* returns NULL when it can't parse).
SELECT
  COUNT(*)                                          AS total,
  COUNT(order_purchase_timestamp)                   AS non_null_text,
  COUNT(TRY_TO_TIMESTAMP(order_purchase_timestamp)) AS parses_ok
FROM ORDERS;

SELECT
  COUNT(*)                            AS total,
  COUNT(TRY_TO_DOUBLE(price))         AS price_ok,
  COUNT(TRY_TO_DOUBLE(freight_value)) AS freight_ok
FROM ORDER_ITEMS;
```

---

## Rules of the game

- **Work layer by layer, in order.** Don't jump to staging without RAW populated and profiled.
- **Everything reproducible.** Anyone should be able to clone the repo and rebuild the pipeline.
- **Secrets are never versioned.** No tokens, no passwords, no `.env`.
- **Commit often, with clear messages** (e.g. `staging (data cleaning)`).
- **Document your decisions**, especially *where* you choose to clean something and *why* there.

---

## Your business angle

Although the technical pipeline is the same for everyone, each of you (or team) picks a **business angle** now, to defend in Part 2: customer retention, logistics performance, satisfaction & reviews, or seller performance. Keep it in mind while profiling: what data will your angle need?

---

## Grading rubric — Part 1

| Criterion | Weight | What's assessed |
|---|---|---|
| **Setup & git** | 15% | Clean structure, leak-free `.gitignore`, secrets outside the repo, reproducible download, meaningful commits |
| **Ingestion into RAW** | 20% | Correct, idempotent Python script; 9 tables loaded; VARCHAR + metadata; row-count verification |
| **Data quality** | 25% | Profiling across the 6 dimensions; key issues detected and well described |
| **Staging in dbt** | 30% | 9 clean models that run error-free; sources; correct casts and renames; `geolocation` case solved; lineage visible |
| **Judgment & documentation** | 10% | Justified decisions, clean cleaning-vs-modeling boundary, readable code |

**Achievement levels per criterion:** Insufficient / Developing / Competent / Excellent.

> The heaviest weight is on **staging + data quality (55%)**: that's where data-engineering craft shows. Setup and ingestion are the common floor; judgment is the ceiling.

---

## What's coming in Part 2

With RAW and STAGING in place, you'll build the business model: the **star schema** in CORE (dimensions + facts, joins, resolving `customer_unique_id`), dbt **tests and documentation**, and the **BI layer** served with the KPIs so the dashboard comes easy. That's where your business angle comes to life.

