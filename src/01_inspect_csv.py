from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW_DATA_DIR = PROJECT_ROOT / "data" / "raw"


def read_sample(file_path: Path) -> tuple[pd.DataFrame, str]:
    """Read a small CSV sample using a suitable encoding."""

    encodings = [
        "utf-8-sig",
        "utf-8",
        "cp1257",
        "windows-1257",
        "latin1",
    ]

    for encoding in encodings:
        try:
            data = pd.read_csv(
                file_path,
                sep=None,
                engine="python",
                encoding=encoding,
                nrows=5,
            )

            return data, encoding

        except Exception:
            continue

    raise ValueError(f"Could not read file: {file_path}")


def main() -> None:
    csv_files = sorted(RAW_DATA_DIR.rglob("*.csv"))

    print(f"CSV files found: {len(csv_files)}")

    for file_number, file_path in enumerate(csv_files, start=1):
        relative_path = file_path.relative_to(PROJECT_ROOT)
        file_size_mb = file_path.stat().st_size / 1024**2

        print("\n" + "=" * 80)
        print(f"FILE {file_number}: {relative_path}")
        print(f"SIZE: {file_size_mb:.2f} MB")

        try:
            sample, encoding = read_sample(file_path)

            print(f"ENCODING: {encoding}")
            print(f"COLUMN COUNT: {len(sample.columns)}")
            print("COLUMNS:")

            for column_number, column_name in enumerate(
                sample.columns,
                start=1,
            ):
                print(f"  {column_number}. {column_name}")

            print("\nFIRST 3 ROWS:")
            print(sample.head(3).to_string(index=False))

        except Exception as error:
            print(f"ERROR: {error}")


if __name__ == "__main__":
    main()