from __future__ import annotations
import csv
import os
import re
from pathlib import Path

from dotenv import load_dotenv
import snowflake.connector

load_dotenv()

RAW_DIR = Path("data") / "raw_csv"
FILE_TO_TABLE = {
    "olist_orders_dataset.csv": "ORDERS",
    "olist_customers_dataset.csv": "CUSTOMERS",
    "olist_order_items_dataset.csv": "ORDER_ITEMS",
    "olist_order_payments_dataset.csv": "ORDER_PAYMENTS",
    "olist_order_reviews_dataset.csv": "ORDER_REVIEWS",
    "olist_products_dataset.csv": "PRODUCTS",
    "olist_sellers_dataset.csv": "SELLERS",
    "olist_geolocation_dataset.csv": "GEOLOCATION",
    "product_category_name_translation.csv": "PRODUCT_CATEGORY_NAME_TRANSLATION",
}

CSV_OPTIONS = {
    "TYPE": "CSV",
    "SKIP_HEADER": 1,
    "FIELD_OPTIONALLY_ENCLOSED_BY": '"',
    "TRIM_SPACE": True,
    "NULL_IF": ["", "NULL"],
}

FILE_FORMAT_NAME = "FF_CSV"


def get_env(name: str) -> str:
    value = os.getenv(name)
    if value is None or value.strip() == "":
        raise SystemExit(f"ERROR: {name} is required in .env or environment variables.")
    return value.strip()


def sanitize_column_name(name: str) -> str:
    name = name.strip().upper()
    name = re.sub(r"[^A-Z0-9_]+", "_", name)
    if re.match(r"^[0-9]", name):
        name = f"C_{name}"
    return name


def connect() -> snowflake.connector.SnowflakeConnection:
    user = get_env("SNOWFLAKE_USER")
    password = get_env("SNOWFLAKE_PASSWORD")
    account = get_env("SNOWFLAKE_ACCOUNT")
    warehouse = get_env("SNOWFLAKE_WAREHOUSE")
    role = get_env("SNOWFLAKE_ROLE")
    database = get_env("SNOWFLAKE_DATABASE")
    schema = get_env("SNOWFLAKE_SCHEMA")

    print("Connecting to Snowflake with:")
    print(f"  account={account}")
    print(f"  user={user}")
    print(f"  warehouse={warehouse}")
    print(f"  role={role}")
    print(f"  database={database}")
    print(f"  schema={schema}\n")

    return snowflake.connector.connect(
        user=user,
        password=password,
        account=account,
        warehouse=warehouse,
        role=role,
        database=database,
        schema=schema,
    )


def read_header(csv_path: Path) -> list[str]:
    with csv_path.open(newline="", encoding="utf-8") as csvfile:
        reader = csv.reader(csvfile)
        header = next(reader, None)
        if header is None:
            raise SystemExit(f"ERROR: file is empty: {csv_path}")
        return [sanitize_column_name(column) for column in header]


def build_file_format() -> str:
    parts = []
    for key, value in CSV_OPTIONS.items():
        if isinstance(value, bool):
            part = f"{key} = {'TRUE' if value else 'FALSE'}"
        elif isinstance(value, (int, float)):
            part = f"{key} = {value}"
        elif isinstance(value, list):
            values = ", ".join(f"'{item}'" for item in value)
            part = f"{key} = ({values})"
        else:
            part = f"{key} = '{value}'"
        parts.append(part)
    return ", ".join(parts)


def create_raw_table(cursor: snowflake.connector.cursor.SnowflakeCursor, table_name: str, columns: list[str]) -> None:
    cols_sql = ",\n        ".join(f"{col} VARCHAR" for col in columns)
    ddl = f"CREATE OR REPLACE TABLE RAW.{table_name} (\n        {cols_sql},\n        _loaded_at TIMESTAMP_LTZ,\n        _source_file VARCHAR\n    )"
    cursor.execute(ddl)
    cursor.execute(f"TRUNCATE TABLE RAW.{table_name}")
    print(f"Created and truncated RAW.{table_name}")


def upload_file(cursor: snowflake.connector.cursor.SnowflakeCursor, csv_path: Path, table_name: str) -> None:
    stage = f"@%{table_name}"
    abs_path = csv_path.resolve()
    uri = f"file:///{abs_path.as_posix()}"
    cursor.execute(f"PUT '{uri}' {stage} OVERWRITE=TRUE")
    print(f"Uploaded {csv_path.name} to internal stage for RAW.{table_name}")


def copy_into_raw(cursor: snowflake.connector.cursor.SnowflakeCursor, table_name: str, columns: list[str]) -> None:
    file_cols = ", ".join(f"${i}" for i in range(1, len(columns) + 1))
    target_cols = ", ".join(columns + ["_loaded_at", "_source_file"])
    sql = f"""
COPY INTO RAW.{table_name} ({target_cols})
FROM (
    SELECT {file_cols}, CURRENT_TIMESTAMP(), METADATA$FILENAME
    FROM @%{table_name}
)
FILE_FORMAT = (FORMAT_NAME = '{FILE_FORMAT_NAME}')
ON_ERROR = 'ABORT_STATEMENT'
"""
    cursor.execute(sql)
    print(f"Loaded data into RAW.{table_name} ({len(columns)} source columns)")


def main() -> None:
    if not RAW_DIR.exists():
        raise SystemExit(f"ERROR: raw CSV folder not found: {RAW_DIR}")

    conn = connect()
    try:
        cur = conn.cursor()
        try:
            for filename, table_name in FILE_TO_TABLE.items():
                csv_path = RAW_DIR / filename
                if not csv_path.exists():
                    raise SystemExit(f"ERROR: missing CSV file: {csv_path}")

                columns = read_header(csv_path)
                create_raw_table(cur, table_name, columns)
                upload_file(cur, csv_path, table_name)
                copy_into_raw(cur, table_name, columns)

            print("\nAll files loaded into RAW successfully.")
        finally:
            cur.close()
    finally:
        conn.close()


if __name__ == "__main__":
    main()
