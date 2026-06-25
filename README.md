# Olist Data Pipeline

End-to-end data pipeline for the Olist Brazilian e-commerce dataset (2016–2018).
Medallion architecture in Snowflake (**RAW → STAGING → CORE → BI**), built with
Python ingestion and dbt transformations.

```
RAW  →  STAGING  →  CORE  →  BI
raw      clean       model    served
```

---

## Stack

| Tool | Role |
|---|---|
| **Git / GitHub** | Version control |
| **Python** | Ingestion of CSVs into Snowflake's RAW layer |
| **Snowflake** | Warehouse — one schema per medallion layer |
| **dbt Cloud** | In-warehouse transformation (STAGING + CORE + BI layers) |
| **Tableau Desktop** | Dashboard, connected to the BI schema only |

---

## Repository structure

```
.
├── download_data.py          # Kaggle dataset download (idempotent)
├── load_raw.py                # Loads CSVs into Snowflake RAW (VARCHAR + metadata)
├── inspect_kaggle_auth.py     # Kaggle credential sanity check
├── snowflake_connect.py       # Snowflake connection helper
├── requirements.txt
├── .gitignore                  # keeps secrets and raw data out of git
└── dbt/ (or repo root, depending on setup)
    ├── dbt_project.yml
    ├── models/
    │   ├── staging/
    │   │   ├── _olist__sources.yml
    │   │   ├── stg_customers.sql
    │   │   ├── stg_sellers.sql
    │   │   ├── stg_products.sql
    │   │   ├── stg_orders.sql
    │   │   ├── stg_order_items.sql
    │   │   ├── stg_order_payments.sql
    │   │   ├── stg_order_reviews.sql
    │   │   ├── stg_geolocation.sql
    │   │   └── stg_product_category_name_translation.sql
    │   └── core/
    │       ├── _core.yml
    │       ├── dim_customers.sql
    │       ├── dim_products.sql
    │       ├── dim_sellers.sql
    │       ├── fct_orders.sql
    │       └── fct_order_items.sql
    │   └── bi/
    │       ├── bi_orders.sql
    │       ├── bi_delivery_satisfaction.sql
    │       └── bi_reviews_by_state.sql
    ├── macros/
    │   └── generate_schema_name.sql
    ├── analyses/
    │   ├── staging_validation_checks.sql
    │   └── bi_validation_checks.sql
    └── tests/
        └── assert_fct_order_items_unique_grain.sql
```

---

## Part 1 — RAW → STAGING

**Phase 0–2.** Dataset downloaded via the Kaggle API (personal token, never
committed — kept outside the repo and excluded by `.gitignore`). Loaded into
Snowflake `RAW` with the official Python connector: all columns as `VARCHAR`,
plus `_loaded_at` / `_source_file` metadata for traceability. The load script
is idempotent.

**Phase 3 — Profiling.** RAW was profiled across the 6 quality dimensions
before any cleaning. Key findings:

- **Uniqueness** — `geolocation` has many duplicate rows per zip code prefix.
- **Granularity** — `customer_id` is unique per *order*; `customer_unique_id`
  is the real, repeat customer.
- **Validity** — a small number of `geolocation` coordinates fall outside
  Brazil's bounding box.
- **Completeness** — `orders` has expected nulls in delivery/approval dates
  (non-delivered or cancelled orders) and in `product_category_name`;
  `order_reviews` has nulls/empty values in comment fields.
- **Types** — most source columns arrive as text and need casting in staging
  (dates, prices, scores, installments, coordinates).
- **Source typos** — `products` has two misspelled column names inherited
  from the source (`product_name_lenght`, `product_description_lenght`,
  missing the "t" in "length"); `product_category_name_translation` has a
  column with a stray leading underscore (`_product_category_name`).

**Phase 4 — Staging.** One `stg_` view per source table, declared via dbt
`sources` (never touching RAW table names directly in models). Per model:
type casting with `TRY_CAST` (fails safe to `NULL` instead of breaking the
build), column renames to fix inherited typos, and whitespace/blank
standardization with `TRIM`. No joins — staging cleans one table at a time.

- **Materialization:** all staging models are **views** (cheap, ~0 storage,
  recomputed on read) — configured project-wide in `dbt_project.yml`.
- **Schema isolation:** a custom `generate_schema_name` macro ensures staging
  models land in the `STAGING` schema exactly (not concatenated with the
  default dev schema).
- **Special case — `geolocation`:** filtered to coordinates inside Brazil's
  approximate bounding box, then aggregated to **one row per zip code
  prefix** (`AVG` for lat/lng, `MODE` for city/state — the most frequent
  label, robust against occasional dirty duplicates).
- **Validation:** `analyses/staging_validation_checks.sql` documents the
  checks run to confirm cleaning didn't silently drop or corrupt data
  (row counts RAW vs STAGING, cast integrity, expected nulls preserved).

---

## Part 2 — STAGING → CORE (star schema)

CORE reorganizes the clean staging tables into a **Kimball star schema**:
dimensions describe entities, facts measure events. CORE reads staging via
`{{ ref(...) }}` (never `source()` directly), and is materialized as
**tables** (queried heavily, worth persisting) — set project-wide for the
`core/` folder.

### Dimensions

- **`dim_customers`** — grain: `customer_id` (per order). Carries
  `customer_unique_id` as an attribute (not the key), enriched with
  geolocation via `LEFT JOIN` on zip code prefix.
- **`dim_products`** — joined to the category translation table; categories
  with no English translation are labelled `'unknown'` via `COALESCE`
  (staging *detects* the missing translation, CORE *decides* what to show).
- **`dim_sellers`** — same "entity + location" pattern as `dim_customers`.

All dimension joins to geolocation are `LEFT JOIN`, so entities without a
matching zip code are kept (with nulls) rather than silently dropped.

### Facts

- **`fct_order_items`** — grain: one row per order line. Carries the FKs
  that connect to every dimension (`product_id`, `seller_id`, `order_id`).
  Metric: `item_total_value = price + freight_value`.
- **`fct_orders`** — grain: one row per order. Items and payments are
  **aggregated by `order_id` before joining** to avoid fan-out (an order
  has many lines and many payments — joining at the wrong grain would
  multiply rows). Metrics: `order_value`, `delivery_days`, and
  `is_late_delivery` (three explicit states — `1` late, `0` on time, `NULL`
  not yet delivered — so an undelivered order is never miscounted as
  "on time").

### Tests

19 tests in total, split between:

- **Generic tests** (`unique`, `not_null`, `relationships`) declared in
  `_core.yml`, next to each model — on primary keys, foreign keys into every
  dimension, and the cross-fact relationship (`fct_order_items.order_id` →
  `fct_orders.order_id`).
- **1 singular test** (`tests/assert_fct_order_items_unique_grain.sql`) —
  `order_id` and `order_item_id` are each repeated by design in
  `fct_order_items`, so no generic test can check them individually. The
  singular test checks that the **combination** of the two is unique,
  matching the table's declared grain.

---

## Key modeling decisions

- **`customer_id` vs `customer_unique_id`** — kept `customer_id` as the
  dimension's grain (per the brief), with `customer_unique_id` carried as
  an attribute for repeat-customer analysis when needed.
- **Aggregate before joining** — both `fct_orders` aggregates (items,
  payments, reviews) happen in their own CTE, grouped by `order_id`, before
  any join — never join-then-aggregate, which would fan out the row count.
- **Nulls are not errors by default** — a cancelled order with no delivery
  date is a legitimate null, not a data quality issue. Nulls are preserved
  through staging and only resolved in CORE, deliberately, per business
  case (e.g. `COALESCE` for categories, explicit `NULL` for
  `is_late_delivery` when there's nothing to compare).

---

## Validation approach

Before committing staging or core models, RAW vs STAGING (and STAGING vs
CORE) were spot-checked for:

1. Renamed/typo-fixed columns appear correctly in the output.
2. `TRY_CAST` didn't silently null out values that were valid in the source
   (non-null counts compared before/after).
3. Expected nulls (delivery dates, review comments, category names) are
   still present in the same proportion as found during profiling.
4. Row counts match between RAW and STAGING for all tables except
   `geolocation` (which intentionally shrinks after deduplication).

---

## Part 3 — CORE → BI (served views & dashboard)

The BI layer is the last stop before the dashboard: friendly, pre-shaped
views that Tableau reads from — **never CORE or RAW directly**. BI models
read CORE via `{{ ref(...) }}`, and are materialized as **views** (cheap,
no heavy aggregation happening here, just final shaping) — set project-wide
for the `bi/` folder, same pattern as staging.

### `bi_orders` — the base view (3 KPIs)

One row per order, enriched with customer location and a truncated purchase
month, ready for Tableau to aggregate directly:

- **Revenue & avg ticket** — `SUM`/`AVG(order_value)`, filtered to
  `order_status = 'delivered'` in the dashboard (real revenue excludes
  cancelled orders).
- **% late deliveries** — rate of `is_late_delivery`, computed only over
  rows where it's not `NULL` (an order that was never delivered has no
  "on time / late" answer — it's excluded, not counted as either).
- **Avg review score** — straight average of `avg_review_score`.

All three KPIs come from this single view — no need for three separate
queries, since every column they need already lives together at the same
grain (one row per order).

### `bi_delivery_satisfaction` — custom KPI (business angle: satisfaction & reviews)

Pre-aggregated by delivery outcome (`late` / `on_time` / `not_delivered`),
with `avg_review_score` and `total_orders` per bucket. Built to test a
direct hypothesis: does a late or missing delivery actually hurt
satisfaction? The data says yes, clearly —

| delivery_status | total_orders | avg_review_score |
|---|---|---|
| on_time | 88,649 | 4.29 |
| late | 7,827 | 2.57 |
| not_delivered | 2,965 | 1.75 |

`total_orders` is included specifically so a thin slice (e.g. very few
`not_delivered` orders) doesn't get over-trusted — it's there as supporting
context, not the headline metric.

### `bi_reviews_by_state` — geographic KPI (heat map)

Average review score aggregated by `customer_state`, with `total_orders`
per state for the same reason as above. Feeds the Tableau heat map
directly: `customer_state` on the map shelf, `avg_review_score` on color.
Covers all 27 Brazilian states (26 states + the Distrito Federal), with no
orphaned "unknown state" bucket.

### Validation

`analyses/bi_validation_checks.sql` documents the checks run before
connecting Tableau — confirming `bi_orders` matches `fct_orders` row for
row (no fan-out from the enrichment join), that the three delivery-status
buckets sum back to the full order count, and that the 27-state total
matches as well. All numbers were validated in SQL first, then visualized.

### Dashboard

Built in Tableau Desktop, connected directly to the `BI` schema (not
`CORE`). Five KPIs across three building blocks: the three base KPIs as
metric cards, the delivery-satisfaction comparison as a bar chart, and the
state-level heat map. Formatting choices: currency in `R$` (Brazilian
Real, matching the dataset's market) with no decimals on the headline
revenue figure, one consistent card style (border + light background +
rounded corners) for all four top-line metrics, and a 3-color palette on
the delivery-status chart (green / amber / red) mapped to outcome — not a
default categorical palette — so the chart reads at a glance.

> **Note on version control.** The Tableau workbook (`.twb`/`.twbx`) is
> **not** committed to this repo. Git here tracks the code that produces
> the data Tableau reads (models, tests, config) — not the BI tool itself,
> which connects to Snowflake independently and isn't part of the dbt
> project. The dashboard is kept/shared separately (exported screenshot,
> packaged workbook, or Tableau Public link, depending on what's needed).

---

## Project status

All three parts are complete: a governed RAW → STAGING → CORE → BI
pipeline, tested and documented, with a working Tableau dashboard reading
exclusively from the served BI layer.
