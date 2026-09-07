USE lithuania_traffic;

SHOW INDEX
FROM fact_traffic;

ALTER TABLE fact_traffic
    ADD INDEX idx_fact_date_key (
        date_key
    ),
    ADD INDEX idx_fact_road_segment (
        road_segment_id
    ),
    ADD INDEX idx_fact_year_road (
        source_year,
        road_segment_id
    );


ANALYZE TABLE fact_traffic;


SELECT
    COUNT(*) AS missing_road_segments
FROM fact_traffic AS fact
LEFT JOIN dim_road_segment AS road
    ON fact.road_segment_id =
       road.road_segment_id
WHERE road.road_segment_id IS NULL;



SELECT
    COUNT(*) AS missing_dates
FROM fact_traffic AS fact
LEFT JOIN dim_date AS calendar
    ON fact.date_key =
       calendar.date_key
WHERE calendar.date_key IS NULL;



SELECT
    speed_quality,
    COUNT(*) AS row_count
FROM fact_traffic
GROUP BY speed_quality
ORDER BY row_count DESC;


SELECT
    source_year_matches_date,
    COUNT(*) AS row_count
FROM fact_traffic
GROUP BY source_year_matches_date;


SELECT
    road_segment_exists,
    COUNT(*) AS row_count
FROM fact_traffic
GROUP BY road_segment_exists;

SELECT
    fact.road_segment_id,
    fact.measurement_date,
    fact.vehicle_type,
    fact.vehicle_count,
    fact.source_file
FROM fact_traffic AS fact
LEFT JOIN dim_road_segment AS road
    ON fact.road_segment_id =
       road.road_segment_id
WHERE road.road_segment_id IS NULL;

INSERT INTO dim_road_segment (
    road_segment_id,
    road_number,
    kilometer,
    location_name,
    longitude,
    latitude,
    longitude_lks94,
    latitude_lks94,
    monitored_direction_code,
    monitored_direction_name,
    has_valid_coordinates
)
SELECT DISTINCT
    fact.road_segment_id,
    'UNKNOWN',
    NULL,
    'Nežinomas kelio ruožas',
    NULL,
    NULL,
    NULL,
    NULL,
    'UNK',
    'Nežinoma',
    0
FROM fact_traffic AS fact
LEFT JOIN dim_road_segment AS road
    ON fact.road_segment_id =
       road.road_segment_id
WHERE road.road_segment_id IS NULL;

SELECT
    COUNT(*) AS missing_road_segments
FROM fact_traffic AS fact
LEFT JOIN dim_road_segment AS road
    ON fact.road_segment_id =
       road.road_segment_id
WHERE road.road_segment_id IS NULL;

SELECT
    COUNT(*) AS missing_dates
FROM fact_traffic AS fact
LEFT JOIN dim_date AS calendar
    ON fact.date_key =
       calendar.date_key
WHERE calendar.date_key IS NULL;