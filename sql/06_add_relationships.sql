USE lithuania_traffic;

ALTER TABLE fact_traffic
    ADD CONSTRAINT fk_fact_road_segment
        FOREIGN KEY (road_segment_id)
        REFERENCES dim_road_segment (
            road_segment_id
        )
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    ADD CONSTRAINT fk_fact_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date (
            date_key
        )
        ON UPDATE RESTRICT
        ON DELETE RESTRICT;
        
        SELECT
    constraint_name,
    table_name,
    referenced_table_name
FROM information_schema.referential_constraints
WHERE constraint_schema = 'lithuania_traffic';

SELECT
    fact.measurement_date,
    road.road_number,
    road.location_name,
    fact.vehicle_type,
    fact.travel_direction_name,
    fact.vehicle_count,
    fact.average_speed_kmh,
    calendar.month_name,
    calendar.weekday_name
FROM fact_traffic AS fact
INNER JOIN dim_road_segment AS road
    ON fact.road_segment_id =
       road.road_segment_id
INNER JOIN dim_date AS calendar
    ON fact.date_key =
       calendar.date_key
LIMIT 20;