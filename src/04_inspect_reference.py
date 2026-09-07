import csv
from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW_DATA_DIR = PROJECT_ROOT / "data" / "raw"


def contains_year(file_path):
    """Check whether the file path contains an annual data year."""

    path_text = str(file_path)

    for year in range(2017, 2025):
        if str(year) in path_text:
            return True

    return False


def detect_file_format(file_path):
    """Detect CSV encoding and delimiter."""

    encodings = [
        "utf-8-sig",
        "utf-8",
        "cp1257",
        "windows-1257",
        "latin1",
    ]

    for encoding in encodings:
        try:
            with file_path.open(
                mode="r",
                encoding=encoding,
            ) as file:
                sample = file.read(10_000)

            delimiter = csv.Sniffer().sniff(
                sample,
                delimiters=",;\t|",
            ).delimiter

            return encoding, delimiter

        except (UnicodeDecodeError, csv.Error):
            continue

    raise ValueError(
        f"Could not detect file format: {file_path}"
    )


def main():
    all_csv_files = sorted(
        RAW_DATA_DIR.rglob("*.csv")
    )

    reference_files = [
        file_path
        for file_path in all_csv_files
        if not contains_year(file_path)
    ]

    print(
        f"Reference CSV files found: "
        f"{len(reference_files)}"
    )

    for file_path in reference_files:
        encoding, delimiter = detect_file_format(
            file_path
        )

        data = pd.read_csv(
            file_path,
            encoding=encoding,
            sep=delimiter,
            nrows=10,
        )

        print("\n" + "=" * 80)
        print(f"FILE: {file_path.name}")
        print(f"ENCODING: {encoding}")
        print(f"DELIMITER: {repr(delimiter)}")
        print(f"COLUMNS: {data.columns.tolist()}")

        print("\nFIRST 10 ROWS:")
        print(data.to_string(index=False))


if __name__ == "__main__":
    main()