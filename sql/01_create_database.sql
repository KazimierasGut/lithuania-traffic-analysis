CREATE DATABASE IF NOT EXISTS lithuania_traffic
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE lithuania_traffic;


DROP TABLE IF EXISTS fact_traffic;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_road_segment;


CREATE TABLE dim_road_segment (
    road_segment_id INT NOT NULL,
    road_number VARCHAR(20),
    kilometer DECIMAL(10, 2),
    location_name VARCHAR(150),
    longitude DECIMAL(10, 6),
    latitude DECIMAL(10, 6),
    longitude_lks94 DECIMAL(12, 2),
    latitude_lks94 DECIMAL(12, 2),
    monitored_direction_code VARCHAR(5),
    monitored_direction_name VARCHAR(30),
    has_valid_coordinates BOOLEAN NOT NULL,

    PRIMARY KEY (road_segment_id)
);


CREATE TABLE dim_date (
    date_key INT NOT NULL,
    date_value DATE NOT NULL,
    calendar_year SMALLINT NOT NULL,
    quarter_number TINYINT NOT NULL,
    month_number TINYINT NOT NULL,
    month_name VARCHAR(15) NOT NULL,
    day_of_month TINYINT NOT NULL,
    weekday_number TINYINT NOT NULL,
    weekday_name VARCHAR(15) NOT NULL,
    is_weekend BOOLEAN NOT NULL,

    PRIMARY KEY (date_key),
    UNIQUE KEY uq_dim_date_value (date_value)
);


CREATE TABLE fact_traffic (
    date_key INT NOT NULL,
    measurement_date DATE NOT NULL,
    road_segment_id INT NOT NULL,
    vehicle_type VARCHAR(200),
    vehicle_class VARCHAR(100),
    traffic_lane VARCHAR(50),
    travel_direction_code VARCHAR(10),
    travel_direction_name VARCHAR(50),
    registration_country VARCHAR(100),
    vehicle_count INT UNSIGNED NOT NULL,
    average_speed_kmh DECIMAL(8, 2),
    speed_quality VARCHAR(20),
    road_segment_exists BOOLEAN NOT NULL,
    source_year SMALLINT,
    source_year_matches_date BOOLEAN NOT NULL,
    source_file VARCHAR(150)
);