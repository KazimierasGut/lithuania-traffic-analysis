USE lithuania_traffic;

TRUNCATE TABLE fact_traffic;

LOAD DATA LOCAL INFILE
'C:/Users/YOUR_USERNAME/lithuania-traffic-analysis/data/processed/fact_traffic.csv'
INTO TABLE fact_traffic
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    @date_key,
    @measurement_date,
    @road_segment_id,
    @vehicle_type,
    @vehicle_class,
    @traffic_lane,
    @travel_direction_code,
    @travel_direction_name,
    @registration_country,
    @vehicle_count,
    @average_speed_kmh,
    @speed_quality,
    @road_segment_exists,
    @source_year,
    @source_year_matches_date,
    @source_file
)
SET
    date_key = NULLIF(
        TRIM(@date_key),
        ''
    ),

    measurement_date = STR_TO_DATE(
        LEFT(TRIM(@measurement_date), 10),
        '%Y-%m-%d'
    ),

    road_segment_id = NULLIF(
        TRIM(@road_segment_id),
        ''
    ),

    vehicle_type = NULLIF(
        TRIM(@vehicle_type),
        ''
    ),

    vehicle_class = NULLIF(
        TRIM(@vehicle_class),
        ''
    ),
    
    

    traffic_lane = NULLIF(
        TRIM(@traffic_lane),
        ''
    ),

    travel_direction_code = NULLIF(
        TRIM(@travel_direction_code),
        ''
    ),

    travel_direction_name = NULLIF(
        TRIM(@travel_direction_name),
        ''
    ),

    registration_country = NULLIF(
        TRIM(@registration_country),
        ''
    ),

    vehicle_count = NULLIF(
        TRIM(@vehicle_count),
        ''
    ),

    average_speed_kmh = NULLIF(
        TRIM(@average_speed_kmh),
        ''
    ),

    speed_quality = NULLIF(
        TRIM(@speed_quality),
        ''
    ),

    road_segment_exists = CASE
        WHEN LOWER(TRIM(@road_segment_exists))
            IN ('true', '1')
        THEN 1
        ELSE 0
    END,

    source_year = NULLIF(
        TRIM(@source_year),
        ''
    ),

    source_year_matches_date = CASE
        WHEN LOWER(
            TRIM(@source_year_matches_date)
        ) IN ('true', '1')
        THEN 1
        ELSE 0
    END,

    source_file = NULLIF(
        REPLACE(
            TRIM(@source_file),
            '\r',
            ''
        ),
        ''
    );
    
    SHOW WARNINGS LIMIT 20;

SELECT COUNT(*) AS total_rows
FROM fact_traffic;

SELECT
    MIN(measurement_date) AS first_date,
    MAX(measurement_date) AS last_date
FROM fact_traffic;

SELECT
    source_year,
    COUNT(*) AS row_count,
    SUM(vehicle_count) AS total_vehicles,
    ROUND(AVG(average_speed_kmh), 2)
        AS average_speed_kmh
FROM fact_traffic
GROUP BY source_year
ORDER BY source_year;

SELECT *
FROM fact_traffic
LIMIT 10;