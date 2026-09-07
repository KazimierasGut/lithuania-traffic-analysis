import csv
import re
from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW_DATA_DIR = PROJECT_ROOT / "data" / "raw"
PROCESSED_DATA_DIR = PROJECT_ROOT / "data" / "processed"

OUTPUT_FILE = PROCESSED_DATA_DIR / "traffic_all_years.csv"
TEMP_OUTPUT_FILE = PROCESSED_DATA_DIR / "traffic_all_years_temp.csv"

CHUNK_SIZE = 250_000


def extract_year(file_path):
    """Extract a year between 2017 and 2024 from a file path."""

    match = re.search(
        r"20(?:17|18|19|20|21|22|23|24)",
        str(file_path),
    )

    if match:
        return int(match.group())

    return None


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
                errors="strict",
            ) as file:
                sample = file.read(10_000)

            dialect = csv.Sniffer().sniff(
                sample,
                delimiters=",;\t|",
            )

            return encoding, dialect.delimiter

        except (UnicodeDecodeError, csv.Error):
            continue

    raise ValueError(
        f"Could not detect encoding or delimiter: {file_path}"
    )


def clean_column_name(column_name):
    """Convert a column name into a database-friendly format."""

    cleaned_name = str(column_name).strip().lower()
    cleaned_name = re.sub(r"\s+", "_", cleaned_name)
    cleaned_name = re.sub(r"[^a-zA-Z0-9_]", "", cleaned_name)

    return cleaned_name


def get_clean_columns(file_path, encoding, delimiter):
    """Read and clean only the CSV header."""

    header = pd.read_csv(
        file_path,
        encoding=encoding,
        sep=delimiter,
        nrows=0,
    )

    cleaned_columns = [
        clean_column_name(column)
        for column in header.columns
    ]

    if len(cleaned_columns) != len(set(cleaned_columns)):
        raise ValueError(
            f"Duplicate column names after cleaning: {file_path.name}"
        )

    return cleaned_columns


def find_annual_files():
    """Find annual traffic CSV files."""

    all_csv_files = sorted(
        RAW_DATA_DIR.rglob("*.csv")
    )

    annual_files = []

    for file_path in all_csv_files:
        year = extract_year(file_path)

        if year is not None:
            annual_files.append(file_path)

    return all_csv_files, annual_files


def inspect_schemas(annual_files):
    """Inspect schemas and build a union of all columns."""

    file_formats = {}
    all_columns = []
    baseline_columns = None

    print("\nChecking file schemas...")

    for file_path in annual_files:
        encoding, delimiter = detect_file_format(file_path)

        columns = get_clean_columns(
            file_path,
            encoding,
            delimiter,
        )

        file_formats[file_path] = {
            "encoding": encoding,
            "delimiter": delimiter,
            "columns": columns,
        }

        if baseline_columns is None:
            baseline_columns = set(columns)

        current_columns = set(columns)

        missing_columns = baseline_columns - current_columns
        additional_columns = current_columns - baseline_columns

        print("\n" + "-" * 70)
        print(f"File: {file_path.name}")
        print(f"Year: {extract_year(file_path)}")
        print(f"Encoding: {encoding}")
        print(f"Delimiter: {repr(delimiter)}")
        print(f"Columns: {columns}")

        if missing_columns or additional_columns:
            print("Schema evolution detected.")
            print(f"Missing columns: {sorted(missing_columns)}")
            print(f"Additional columns: {sorted(additional_columns)}")

        for column in columns:
            if column not in all_columns:
                all_columns.append(column)

    return file_formats, all_columns


def combine_files(annual_files, file_formats, all_columns):
    """Combine annual files in chunks."""

    output_columns = all_columns + [
        "source_year",
        "source_file",
    ]

    total_rows = 0
    rows_by_year = {}
    first_chunk = True

    if TEMP_OUTPUT_FILE.exists():
        TEMP_OUTPUT_FILE.unlink()

    print("\n" + "=" * 70)
    print("COMBINING FILES")
    print("=" * 70)

    for file_path in annual_files:
        year = extract_year(file_path)
        file_format = file_formats[file_path]

        encoding = file_format["encoding"]
        delimiter = file_format["delimiter"]

        file_row_count = 0

        chunk_reader = pd.read_csv(
            file_path,
            encoding=encoding,
            sep=delimiter,
            chunksize=CHUNK_SIZE,
            low_memory=False,
        )

        for chunk in chunk_reader:
            chunk.columns = [
                clean_column_name(column)
                for column in chunk.columns
            ]

            chunk["source_year"] = year
            chunk["source_file"] = file_path.name

            chunk = chunk.reindex(
                columns=output_columns
            )

            write_mode = "w" if first_chunk else "a"

            chunk.to_csv(
                TEMP_OUTPUT_FILE,
                mode=write_mode,
                header=first_chunk,
                index=False,
                encoding="utf-8",
            )

            chunk_row_count = len(chunk)

            file_row_count += chunk_row_count
            total_rows += chunk_row_count

            first_chunk = False

            print(
                f"{file_path.name}: "
                f"{file_row_count:,} rows processed"
            )

        rows_by_year[year] = file_row_count

        print(
            f"Completed {year}: "
            f"{file_row_count:,} rows"
        )

    TEMP_OUTPUT_FILE.replace(OUTPUT_FILE)

    output_size_mb = (
        OUTPUT_FILE.stat().st_size / 1024**2
    )

    print("\n" + "=" * 70)
    print("COMBINED DATA SUMMARY")
    print("=" * 70)
    print(f"Total rows: {total_rows:,}")
    print(f"Total columns: {len(output_columns)}")
    print(f"Output size: {output_size_mb:.2f} MB")
    print(f"Saved file: {OUTPUT_FILE}")

    print("\nRows by year:")

    for year in sorted(rows_by_year):
        print(f"{year}: {rows_by_year[year]:,}")


def main():
    PROCESSED_DATA_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    all_csv_files, annual_files = find_annual_files()

    print(f"All CSV files found: {len(all_csv_files)}")
    print(
        f"Annual traffic files selected: "
        f"{len(annual_files)}"
    )

    if not annual_files:
        print("No annual traffic files were found.")
        return

    file_formats, all_columns = inspect_schemas(
        annual_files
    )

    print("\nFinal combined columns:")
    print(
        all_columns
        + ["source_year", "source_file"]
    )

    combine_files(
        annual_files,
        file_formats,
        all_columns,
    )


if __name__ == "__main__":
    main()