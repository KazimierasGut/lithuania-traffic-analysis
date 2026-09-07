USE lithuania_traffic;

TRUNCATE TABLE dim_road_segment;

LOAD DATA LOCAL INFILE
'C:/Users/YOUR_USERNAME/lithuania-traffic-analysis/data/processed/dim_road_segment.csv'
INTO TABLE dim_road_segment
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    @road_segment_id,
    @road_number,
    @kilometer,
    @location_name,
    @longitude,
    @latitude,
    @longitude_lks94,
    @latitude_lks94,
    @monitored_direction_code,
    @monitored_direction_name,
    @has_valid_coordinates
)
SET
    road_segment_id = NULLIF(
        TRIM(@road_segment_id),
        ''
    ),
    road_number = NULLIF(
        TRIM(@road_number),
        ''
    ),
    kilometer = NULLIF(
        TRIM(@kilometer),
        ''
    ),
    location_name = NULLIF(
        TRIM(@location_name),
        ''
    ),
    longitude = NULLIF(
        TRIM(@longitude),
        ''
    ),
    latitude = NULLIF(
        TRIM(@latitude),
        ''
    ),
    longitude_lks94 = NULLIF(
        TRIM(@longitude_lks94),
        ''
    ),
    latitude_lks94 = NULLIF(
        TRIM(@latitude_lks94),
        ''
    ),
    monitored_direction_code = NULLIF(
        TRIM(@monitored_direction_code),
        ''
    ),
    monitored_direction_name = NULLIF(
        TRIM(@monitored_direction_name),
        ''
    ),
    has_valid_coordinates = CASE
        WHEN LOWER(
            REPLACE(
                TRIM(@has_valid_coordinates),
                '\r',
                ''
            )
        ) IN ('true', '1')
        THEN 1
        ELSE 0
    END;
    
    SELECT COUNT(*) AS road_segment_count
FROM dim_road_segment;

SELECT
    road_segment_id,
    road_number,
    kilometer,
    location_name,
    longitude,
    latitude
FROM dim_road_segment
ORDER BY road_segment_id
LIMIT 10;