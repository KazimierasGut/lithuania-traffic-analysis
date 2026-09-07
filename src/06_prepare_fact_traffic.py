from pathlib import Path

import numpy as np
import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parent.parent
PROCESSED_DATA_DIR = PROJECT_ROOT / "data" / "processed"

INPUT_FILE = (
    PROCESSED_DATA_DIR
    / "traffic_all_years.csv"
)

ROAD_DIMENSION_FILE = (
    PROCESSED_DATA_DIR
    / "dim_road_segment.csv"
)

OUTPUT_FILE = (
    PROCESSED_DATA_DIR
    / "fact_traffic.csv"
)

TEMP_OUTPUT_FILE = (
    PROCESSED_DATA_DIR
    / "fact_traffic_temp.csv"
)

REJECTED_FILE = (
    PROCESSED_DATA_DIR
    / "rejected_traffic_rows.csv"
)

TEMP_REJECTED_FILE = (
    PROCESSED_DATA_DIR
    / "rejected_traffic_rows_temp.csv"
)

CHUNK_SIZE = 250_000


COLUMN_MAPPING = {
    "rng_id": "road_segment_id",
    "veh_type": "vehicle_type",
    "avg_speed": "average_speed_kmh",
    "veh_direction": "travel_direction_code",
    "veh_date": "measurement_date",
    "veh_front_cntr": "registration_country",
    "numberofvehicles": "vehicle_count",
    "klase": "vehicle_class",
    "veh_lane": "traffic_lane",
}


def clean_text(series):
    """Clean a text column and preserve missing values."""

    return (
        series
        .astype("string")
        .str.strip()
        .replace(
            {
                "": pd.NA,
                "nan": pd.NA,
                "None": pd.NA,
                "<NA>": pd.NA,
            }
        )
    )


def load_known_road_ids():
    """Load valid road segment IDs from the road dimension."""

    roads = pd.read_csv(
        ROAD_DIMENSION_FILE,
        usecols=["road_segment_id"],
    )

    return set(
        pd.to_numeric(
            roads["road_segment_id"],
            errors="coerce",
        )
        .dropna()
        .astype(int)
        .tolist()
    )


def prepare_chunk(chunk, known_road_ids):
    """Clean and validate one data chunk."""

    chunk = chunk.rename(
        columns=COLUMN_MAPPING
    )

    chunk["road_segment_id"] = pd.to_numeric(
        chunk["road_segment_id"],
        errors="coerce",
    )

    chunk["vehicle_count"] = pd.to_numeric(
        chunk["vehicle_count"],
        errors="coerce",
    )

    chunk["average_speed_kmh"] = pd.to_numeric(
        chunk["average_speed_kmh"],
        errors="coerce",
    )

    chunk["source_year"] = pd.to_numeric(
        chunk["source_year"],
        errors="coerce",
    )

    chunk["measurement_date"] = pd.to_datetime(
        chunk["measurement_date"],
        errors="coerce",
    )

    text_columns = [
        "vehicle_type",
        "travel_direction_code",
        "registration_country",
        "vehicle_class",
        "traffic_lane",
        "source_file",
    ]

    for column in text_columns:
        chunk[column] = clean_text(
            chunk[column]
        )

    chunk["travel_direction_code"] = (
        chunk["travel_direction_code"]
        .str.upper()
        .fillna("UNKNOWN")
    )

    chunk["registration_country"] = (
        chunk["registration_country"]
        .str.upper()
        .fillna("UNKNOWN")
    )

    chunk["vehicle_type"] = (
        chunk["vehicle_type"]
        .fillna("Unknown")
    )

    missing_road_id = (
        chunk["road_segment_id"].isna()
    )

    missing_date = (
        chunk["measurement_date"].isna()
    )

    invalid_vehicle_count = (
        chunk["vehicle_count"].isna()
        | (chunk["vehicle_count"] < 0)
        | (
            chunk["vehicle_count"] % 1
            != 0
        )
    )

    rejected_mask = (
        missing_road_id
        | missing_date
        | invalid_vehicle_count
    )

    rejection_reason = np.select(
        [
            missing_road_id,
            missing_date,
            invalid_vehicle_count,
        ],
        [
            "missing_road_segment_id",
            "invalid_measurement_date",
            "invalid_vehicle_count",
        ],
        default="",
    )

    chunk["rejection_reason"] = (
        rejection_reason
    )

    rejected_rows = chunk[
        rejected_mask
    ].copy()

    valid_rows = chunk[
        ~rejected_mask
    ].copy()

    valid_rows["road_segment_id"] = (
        valid_rows["road_segment_id"]
        .astype("int64")
    )

    valid_rows["vehicle_count"] = (
        valid_rows["vehicle_count"]
        .astype("int64")
    )

    valid_rows["source_year"] = (
        valid_rows["source_year"]
        .astype("Int64")
    )

    valid_rows["date_key"] = (
        valid_rows["measurement_date"]
        .dt.strftime("%Y%m%d")
        .astype("int64")
    )

    direction_mapping = {
        "T": "Kelio kryptimi",
        "N": "Prieš kelio kryptį",
    }

    valid_rows["travel_direction_name"] = (
        valid_rows["travel_direction_code"]
        .map(direction_mapping)
        .fillna("Nežinoma")
    )

    valid_rows["speed_quality"] = np.select(
        [
            valid_rows["average_speed_kmh"].isna(),
            valid_rows["average_speed_kmh"] < 0,
            valid_rows["average_speed_kmh"] > 200,
        ],
        [
            "MISSING",
            "INVALID",
            "OUTLIER",
        ],
        default="VALID",
    )

    negative_speed = (
        valid_rows["average_speed_kmh"] < 0
    )

    valid_rows.loc[
        negative_speed,
        "average_speed_kmh",
    ] = np.nan

    valid_rows["road_segment_exists"] = (
        valid_rows["road_segment_id"]
        .isin(known_road_ids)
    )

    valid_rows[
        "source_year_matches_date"
    ] = (
        valid_rows["source_year"]
        == valid_rows[
            "measurement_date"
        ].dt.year
    )

    output_columns = [
        "date_key",
        "measurement_date",
        "road_segment_id",
        "vehicle_type",
        "vehicle_class",
        "traffic_lane",
        "travel_direction_code",
        "travel_direction_name",
        "registration_country",
        "vehicle_count",
        "average_speed_kmh",
        "speed_quality",
        "road_segment_exists",
        "source_year",
        "source_year_matches_date",
        "source_file",
    ]

    valid_rows = valid_rows[
        output_columns
    ]

    return valid_rows, rejected_rows


def main():
    if not INPUT_FILE.exists():
        print(f"Input file not found: {INPUT_FILE}")
        return

    if not ROAD_DIMENSION_FILE.exists():
        print(
            "Road dimension file not found: "
            f"{ROAD_DIMENSION_FILE}"
        )
        return

    known_road_ids = load_known_road_ids()

    print(
        f"Known road segment IDs: "
        f"{len(known_road_ids):,}"
    )

    if TEMP_OUTPUT_FILE.exists():
        TEMP_OUTPUT_FILE.unlink()

    if TEMP_REJECTED_FILE.exists():
        TEMP_REJECTED_FILE.unlink()

    total_rows = 0
    valid_row_count = 0
    rejected_row_count = 0
    missing_road_reference_count = 0

    first_valid_chunk = True
    first_rejected_chunk = True

    chunk_reader = pd.read_csv(
        INPUT_FILE,
        chunksize=CHUNK_SIZE,
        low_memory=False,
    )

    for chunk_number, chunk in enumerate(
        chunk_reader,
        start=1,
    ):
        total_rows += len(chunk)

        valid_rows, rejected_rows = (
            prepare_chunk(
                chunk,
                known_road_ids,
            )
        )

        valid_row_count += len(valid_rows)
        rejected_row_count += len(
            rejected_rows
        )

        missing_road_reference_count += (
            (~valid_rows["road_segment_exists"])
            .sum()
        )

        valid_rows.to_csv(
            TEMP_OUTPUT_FILE,
            mode=(
                "w"
                if first_valid_chunk
                else "a"
            ),
            header=first_valid_chunk,
            index=False,
            encoding="utf-8",
        )

        first_valid_chunk = False

        if not rejected_rows.empty:
            rejected_rows.to_csv(
                TEMP_REJECTED_FILE,
                mode=(
                    "w"
                    if first_rejected_chunk
                    else "a"
                ),
                header=first_rejected_chunk,
                index=False,
                encoding="utf-8",
            )

            first_rejected_chunk = False

        print(
            f"Chunk {chunk_number}: "
            f"{total_rows:,} total rows processed"
        )

    TEMP_OUTPUT_FILE.replace(
        OUTPUT_FILE
    )

    if TEMP_REJECTED_FILE.exists():
        TEMP_REJECTED_FILE.replace(
            REJECTED_FILE
        )

    output_size_mb = (
        OUTPUT_FILE.stat().st_size
        / 1024**2
    )

    print("\n" + "=" * 70)
    print("FACT TABLE SUMMARY")
    print("=" * 70)
    print(f"Total source rows: {total_rows:,}")
    print(f"Valid rows saved: {valid_row_count:,}")
    print(
        f"Rejected rows: "
        f"{rejected_row_count:,}"
    )
    print(
        "Rows without road reference: "
        f"{missing_road_reference_count:,}"
    )
    print(
        f"Output size: "
        f"{output_size_mb:.2f} MB"
    )
    print(f"Saved file: {OUTPUT_FILE}")

    if rejected_row_count > 0:
        print(
            f"Rejected file: "
            f"{REJECTED_FILE}"
        )


if __name__ == "__main__":
    main()