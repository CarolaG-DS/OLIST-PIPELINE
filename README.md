# Olist Part 1 — Data Academy

This is the simple explanation of what we did in the repo.

## What we did

1. We created a safe project folder.
2. We wrote a `.gitignore` so secret keys and raw data cannot be committed.
3. We created `requirements.txt` with the Kaggle downloader dependency.
4. We built `download_data.py` so the dataset can be downloaded with one command.
5. We moved your Kaggle token from `token.json` into the secure folder `C:\Users\<you>\.kaggle\access_token`.
6. We installed the required Python package.
7. We fixed the download script so it uses the correct Kaggle dataset slug: `olistbr/brazilian-ecommerce`.
8. We ran the download and the 9 raw CSV files were downloaded and extracted into `data/raw_csv/`.

## What problems we encountered

- `git` was not available in the terminal, so we could not initialize a git repository from there.
- The Kaggle token file was in the wrong place and in the wrong format for the Kaggle client.
- The first dataset slug in the script was wrong (`olistbr/olist-dataset`), which caused a `403 Forbidden` error.
- After you gave the correct dataset URL, we updated the script and the download worked.

## Files you now have

- `.gitignore`
- `requirements.txt`
- `download_data.py`
- `README.md`
- `data/raw_csv/` with the 9 CSV files:
  - `olist_orders_dataset.csv`
  - `olist_customers_dataset.csv`
  - `olist_order_items_dataset.csv`
  - `olist_order_payments_dataset.csv`
  - `olist_order_reviews_dataset.csv`
  - `olist_products_dataset.csv`
  - `olist_sellers_dataset.csv`
  - `olist_geolocation_dataset.csv`
  - `product_category_name_translation.csv`

## What you can do next

1. Build the Snowflake database and schemas: `DATA_ACADEMY`, `RAW`, `STAGING`, `CORE`, `BI`.
2. Use the Snowflake upload script to load the CSV files into `RAW`.
3. Profile the raw tables in Snowflake to understand missing data, duplicates, wrong types, and bad joins.
4. Create dbt staging models for the 9 source tables.

## Load data into Snowflake RAW

1. Install dependencies:

```powershell
python -m pip install -r requirements.txt
```

2. Create a `.env` file in the repo root with your Snowflake connection values.

3. Copy `./.env.example` to `./.env` and fill in the values.

4. Run the loader:

```powershell
python load_raw.py
```

## .env format

Use the `.env.example` file as a template. Do not commit your `.env` file.

```text
SNOWFLAKE_USER=CAROTIL
SNOWFLAKE_PASSWORD=your_password_here
SNOWFLAKE_ACCOUNT=DJFXRWK-WF91374
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_ROLE=ACCOUNTADMIN
SNOWFLAKE_DATABASE=DATA_ACADEMY
SNOWFLAKE_SCHEMA=RAW
```

## Notes

- The loader script reads the environment from `.env` using `python-dotenv`.
- The raw files are loaded from `data/raw_csv/` into Snowflake `RAW` tables.
- The password remains local in `.env` and is never committed.
