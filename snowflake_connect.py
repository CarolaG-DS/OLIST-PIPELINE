import os
import snowflake.connector


def get_env_or_fail(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise SystemExit(f"ERROR: environment variable {name} is required.")
    return value


def main() -> None:
    user = os.getenv('SNOWFLAKE_USER', 'CAROTIL')
    password = os.getenv('SNOWFLAKE_PASSWORD')
    if not password:
        raise SystemExit('ERROR: Set SNOWFLAKE_PASSWORD in your environment before running this script.')
    account = os.getenv('SNOWFLAKE_ACCOUNT', 'DJFXRWK-WF91374')
    warehouse = os.getenv('SNOWFLAKE_WAREHOUSE')
    if not warehouse:
        raise SystemExit('ERROR: Set SNOWFLAKE_WAREHOUSE in your environment before running this script.')
    role = os.getenv('SNOWFLAKE_ROLE', 'ACCOUNTADMIN')
    database = os.getenv('SNOWFLAKE_DATABASE', 'DATA_ACADEMY')
    schema = os.getenv('SNOWFLAKE_SCHEMA', 'RAW')

    print('Connecting to Snowflake...')
    conn = snowflake.connector.connect(
        user=user,
        password=password,
        account=account,
        warehouse=warehouse,
        role=role,
        database=database,
        schema=schema,
    )

    try:
        cur = conn.cursor()
        try:
            cur.execute('SELECT CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_ROLE(), CURRENT_VERSION()')
            row = cur.fetchone()
            print('Connected successfully!')
            print('DATABASE:', row[0])
            print('SCHEMA:', row[1])
            print('ROLE:', row[2])
            print('SNOWFLAKE VERSION:', row[3])
        finally:
            cur.close()
    finally:
        conn.close()


if __name__ == '__main__':
    main()
