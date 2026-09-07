from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_FILE = (
    PROJECT_ROOT
    / "data"
    / "processed"
    / "traffic_all_years.csv"
)

SAMPLE_SIZE = 100_000


def main():
    if not DATA_FILE.exists():
        print(f"File not found: {DATA_FILE}")
        return

    print(f"Reading first {SAMPLE_SIZE:,} rows...")

    data = pd.read_csv(
        DATA_FILE,
        nrows=SAMPLE_SIZE,
        low_memory=False,
    )

    print("\n" + "=" * 80)
    print("DATASET OVERVIEW")
    print("=" * 80)
    print(f"Sample rows: {len(data):,}")
    print(f"Columns: {len(data.columns)}")

    print("\nCOLUMN NAMES:")

    for number, column in enumerate(
        data.columns,
        start=1,
    ):
        print(f"{number}. {column}")

    print("\n" + "=" * 80)
    print("COLUMN PROFILE")
    print("=" * 80)

    for column in data.columns:
        missing_count = data[column].isna().sum()
        unique_count = data[column].nunique(
            dropna=True
        )

        example_values = (
            data[column]
            .dropna()
            .astype(str)
            .unique()[:5]
            .tolist()
        )

        print(f"\nColumn: {column}")
        print(f"Python type: {data[column].dtype}")
        print(f"Missing values: {missing_count:,}")
        print(f"Unique values: {unique_count:,}")
        print(f"Examples: {example_values}")

    print("\n" + "=" * 80)
    print("FIRST 5 ROWS")
    print("=" * 80)
    print(data.head().to_string(index=False))


if __name__ == "__main__":
    main()