from __future__ import annotations
import shutil
import sys
from pathlib import Path

EXPECTED_FILES = [
    "olist_orders_dataset.csv",
    "olist_customers_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "olist_geolocation_dataset.csv",
    "product_category_name_translation.csv",
]

DATASET_SLUG = "olistbr/brazilian-ecommerce"
DOWNLOAD_DIR = Path("data") / "raw_csv"
SCRIPT_TOKEN_FILE = Path(__file__).with_name("token.json")


def has_expected_files(dest: Path) -> bool:
    return all((dest / file_name).exists() for file_name in EXPECTED_FILES)


def print_intro() -> None:
    print("Olist Part 1: download raw CSVs from Kaggle")
    print("--------------------------------------------")
    print(f"Target path: {DOWNLOAD_DIR.resolve()}")
    print(f"Dataset: {DATASET_SLUG}\n")


def verify_kaggle_config() -> None:
    home_config = Path.home() / ".kaggle" / "kaggle.json"
    if home_config.exists():
        return
    env_config = Path(shutil.which("kaggle") or "")
    if env_config is None:
        return
    # If the user explicitly set KAGGLE_CONFIG_DIR, we assume the Kaggle client will use it.


def main() -> int:
    print_intro()

    if SCRIPT_TOKEN_FILE.exists():
        print("WARNING: token.json is present in the repo root.")
        print("  This file should be moved to your home folder and kept out of version control.")
        print("  Move it to: C:\\Users\\<you>\\.kaggle\\kaggle.json")
        print("  Then remove it from the repo and do not commit it.")
        print()

    if has_expected_files(DOWNLOAD_DIR):
        print("All expected CSV files are already present. No download needed.")
        return 0

    try:
        from kaggle.api.kaggle_api_extended import KaggleApi
    except ImportError:
        print("ERROR: The Kaggle Python package is not installed.")
        print("Install it with: python -m pip install -r requirements.txt")
        return 1

    DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
    api = KaggleApi()
    try:
        api.authenticate()
    except Exception as exc:
        print("ERROR: Kaggle authentication failed.")
        print("Make sure your Kaggle token is stored at ~/.kaggle/kaggle.json or in KAGGLE_CONFIG_DIR.")
        print(f"Details: {exc}")
        return 1

    print("Downloading dataset from Kaggle...")
    api.dataset_download_files(DATASET_SLUG, path=str(DOWNLOAD_DIR), unzip=True, quiet=False)

    if not has_expected_files(DOWNLOAD_DIR):
        print("ERROR: The download completed but expected CSV files were not found.")
        print("Check the downloaded files in:", DOWNLOAD_DIR.resolve())
        return 1

    print("Download complete. The following files are now available:")
    for file_name in EXPECTED_FILES:
        print(f" - {DOWNLOAD_DIR / file_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
