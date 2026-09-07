USE lithuania_traffic;

DROP TABLE IF EXISTS agg_daily_road_traffic;

CREATE TABLE agg_daily_road_traffic (
    date_key INT NOT NULL,
    road_segment_id INT NOT NULL,
    travel_direction_code VARCHAR(10) NOT NULL,
    travel_direction_name VARCHAR(50),

    total_vehicles BIGINT UNSIGNED NOT NULL,
    weighted_average_speed_kmh DECIMAL(8, 2),

    source_row_count BIGINT UNSIGNED NOT NULL,
    valid_speed_vehicle_count BIGINT UNSIGNED NOT NULL,
    missing_speed_row_count BIGINT UNSIGNED NOT NULL,
    outlier_speed_row_count BIGINT UNSIGNED NOT NULL,

    PRIMARY KEY (
        date_key,
        road_segment_id,
        travel_direction_code
    )
);

INSERT INTO agg_daily_road_traffic (
    date_key,
    road_segment_id,
    travel_direction_code,
    travel_direction_name,
    total_vehicles,
    weighted_average_speed_kmh,
    source_row_count,
    valid_speed_vehicle_count,
    missing_speed_row_count,
    outlier_speed_row_count
)
SELECT
    date_key,
    road_segment_id,
    travel_direction_code,
    MAX(travel_direction_name),

    SUM(vehicle_count) AS total_vehicles,

    ROUND(
        SUM(
            CASE
                WHEN speed_quality = 'VALID'
                THEN average_speed_kmh
                     * vehicle_count
                ELSE 0
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN speed_quality = 'VALID'
                    THEN vehicle_count
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS weighted_average_speed_kmh,

    COUNT(*) AS source_row_count,

    SUM(
        CASE
            WHEN speed_quality = 'VALID'
            THEN vehicle_count
            ELSE 0
        END
    ) AS valid_speed_vehicle_count,

    SUM(
        CASE
            WHEN speed_quality = 'MISSING'
            THEN 1
            ELSE 0
        END
    ) AS missing_speed_row_count,

    SUM(
        CASE
            WHEN speed_quality = 'OUTLIER'
            THEN 1
            ELSE 0
        END
    ) AS outlier_speed_row_count

FROM fact_traffic

GROUP BY
    date_key,
    road_segment_id,
    travel_direction_code;
    
    CREATE INDEX idx_agg_road_date
    ON agg_daily_road_traffic (
        road_segment_id,
        date_key
    );

ALTER TABLE agg_daily_road_traffic
    ADD CONSTRAINT fk_agg_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date (date_key),

    ADD CONSTRAINT fk_agg_road
        FOREIGN KEY (road_segment_id)
        REFERENCES dim_road_segment (
            road_segment_id
        );
        
        SELECT COUNT(*) AS aggregate_rows
FROM agg_daily_road_traffic;

SELECT
    MIN(calendar.date_value) AS first_date,
    MAX(calendar.date_value) AS last_date,
    SUM(traffic.total_vehicles)
        AS total_vehicles
FROM agg_daily_road_traffic AS traffic
INNER JOIN dim_date AS calendar
    ON traffic.date_key =
       calendar.date_key;
       
       SELECT
    calendar.date_value,
    road.road_number,
    road.location_name,
    traffic.travel_direction_name,
    traffic.total_vehicles,
    traffic.weighted_average_speed_kmh
FROM agg_daily_road_traffic AS traffic
INNER JOIN dim_date AS calendar
    ON traffic.date_key =
       calendar.date_key
INNER JOIN dim_road_segment AS road
    ON traffic.road_segment_id =
       road.road_segment_id
ORDER BY
    calendar.date_value,
    road.road_number
LIMIT 20;