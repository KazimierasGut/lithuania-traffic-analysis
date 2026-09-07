from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW_DATA_DIR = PROJECT_ROOT / "data" / "raw"
PROCESSED_DATA_DIR = PROJECT_ROOT / "data" / "processed"

OUTPUT_FILE = (
    PROCESSED_DATA_DIR
    / "dim_road_segment.csv"
)


def find_reference_file():
    """Find the EII_RNG reference CSV file."""

    for file_path in RAW_DATA_DIR.rglob("*.csv"):
        if file_path.name.lower() == "eii_rng.csv":
            return file_path

    return None


def clean_text_column(series):
    """Remove unnecessary spaces from text values."""

    return (
        series
        .astype("string")
        .str.strip()
        .replace("", pd.NA)
    )


def main():
    reference_file = find_reference_file()

    if reference_file is None:
        print("EII_RNG.csv was not found.")
        return

    PROCESSED_DATA_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    print(f"Reading: {reference_file}")

    roads = pd.read_csv(
        reference_file,
        encoding="utf-8-sig",
    )

    roads.columns = [
        column.strip().lower()
        for column in roads.columns
    ]

    column_mapping = {
        "rng_id": "road_segment_id",
        "kel_numeris": "road_number",
        "km": "kilometer",
        "rng_viesas_pavadinimas": "location_name",
        "rng_ilguma_etrs89": "longitude",
        "rng_platuma_etrs89": "latitude",
        "rng_ilguma_lks": "longitude_lks94",
        "rng_platuma_lks": "latitude_lks94",
        "rng_eismo_kryptis": "monitored_direction_code",
    }

    roads = roads.rename(
        columns=column_mapping
    )

    expected_columns = list(
        column_mapping.values()
    )

    missing_columns = [
        column
        for column in expected_columns
        if column not in roads.columns
    ]

    if missing_columns:
        raise ValueError(
            f"Missing columns: {missing_columns}"
        )

    roads = roads[expected_columns].copy()

    numeric_columns = [
        "road_segment_id",
        "kilometer",
        "longitude",
        "latitude",
        "longitude_lks94",
        "latitude_lks94",
    ]

    for column in numeric_columns:
        roads[column] = pd.to_numeric(
            roads[column],
            errors="coerce",
        )

    text_columns = [
        "road_number",
        "location_name",
        "monitored_direction_code",
    ]

    for column in text_columns:
        roads[column] = clean_text_column(
            roads[column]
        )

    roads["monitored_direction_code"] = (
        roads["monitored_direction_code"]
        .str.upper()
    )

    direction_mapping = {
        "PR": "Priekis",
        "AT": "Atgal",
        "AB": "Abi kryptys",
    }

    roads["monitored_direction_name"] = (
        roads["monitored_direction_code"]
        .map(direction_mapping)
        .fillna("Nežinoma")
    )

    roads["has_valid_coordinates"] = (
        roads["longitude"].between(20, 27)
        & roads["latitude"].between(53, 57)
    )

    missing_id_count = (
        roads["road_segment_id"]
        .isna()
        .sum()
    )

    duplicate_id_count = (
        roads["road_segment_id"]
        .duplicated()
        .sum()
    )

    roads = roads.dropna(
        subset=["road_segment_id"]
    )

    roads["road_segment_id"] = (
        roads["road_segment_id"]
        .astype("int64")
    )

    roads = roads.drop_duplicates(
        subset=["road_segment_id"],
        keep="first",
    )

    roads = roads.sort_values(
        by="road_segment_id"
    )

    roads.to_csv(
        OUTPUT_FILE,
        index=False,
        encoding="utf-8-sig",
    )

    print("\n" + "=" * 70)
    print("ROAD DIMENSION SUMMARY")
    print("=" * 70)
    print(f"Rows saved: {len(roads):,}")
    print(f"Missing IDs removed: {missing_id_count:,}")
    print(f"Duplicate IDs found: {duplicate_id_count:,}")
    print(
        "Rows with valid coordinates: "
        f"{roads['has_valid_coordinates'].sum():,}"
    )
    print(f"Saved file: {OUTPUT_FILE}")

    print("\nFirst 10 rows:")
    print(roads.head(10).to_string(index=False))


if __name__ == "__main__":
    main()