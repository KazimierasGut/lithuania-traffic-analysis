USE lithuania_traffic;

-- =========================================================
-- ANALITINIS KLAUSIMAS 1
-- Kaip 2018–2023 m. keitėsi bendras užfiksuotas transporto
-- kiekis, aktyvių ruožų skaičius ir vidutinis greitis?
-- =========================================================

WITH yearly_traffic AS (
    SELECT
        d.calendar_year,
        SUM(a.total_vehicles) AS total_vehicles,
        COUNT(DISTINCT a.road_segment_id) AS active_road_segments,
        SUM(
            a.weighted_average_speed_kmh
            * a.valid_speed_vehicle_count
        ) / NULLIF(
            SUM(a.valid_speed_vehicle_count),
            0
        ) AS weighted_average_speed_kmh
    FROM agg_daily_road_traffic AS a
    INNER JOIN dim_date AS d
        ON d.date_key = a.date_key
    WHERE d.calendar_year BETWEEN 2018 AND 2023
    GROUP BY d.calendar_year
)
SELECT
    calendar_year,
    total_vehicles,
    active_road_segments,
    ROUND(weighted_average_speed_kmh, 2)
        AS weighted_average_speed_kmh,
    ROUND(
        (
            total_vehicles
            - LAG(total_vehicles) OVER (ORDER BY calendar_year)
        ) / NULLIF(
            LAG(total_vehicles) OVER (ORDER BY calendar_year),
            0
        ) * 100,
        2
    ) AS recorded_volume_yoy_pct
FROM yearly_traffic
ORDER BY calendar_year;


-- =========================================================
-- ANALITINIS KLAUSIMAS 2
-- Ar kiekvienais metais kelių skaitikliai turėjo panašiai
-- pilnus duomenis?
-- =========================================================

WITH yearly_coverage AS (
    SELECT
        d.calendar_year,
        MIN(d.date_value) AS first_recorded_date,
        MAX(d.date_value) AS last_recorded_date,
        COUNT(DISTINCT a.date_key) AS dates_with_data,
        COUNT(DISTINCT a.road_segment_id) AS active_road_segments,
        COUNT(
            DISTINCT CONCAT(a.date_key, '-', a.road_segment_id)
        ) AS active_segment_days,
        SUM(a.total_vehicles) AS total_vehicles
    FROM agg_daily_road_traffic AS a
    INNER JOIN dim_date AS d
        ON d.date_key = a.date_key
    WHERE d.calendar_year BETWEEN 2018 AND 2023
    GROUP BY d.calendar_year
),
coverage_metrics AS (
    SELECT
        calendar_year,
        first_recorded_date,
        last_recorded_date,
        dates_with_data,
        active_road_segments,
        active_segment_days,
        total_vehicles,
        total_vehicles / NULLIF(active_segment_days, 0)
            AS vehicles_per_active_segment_day,
        active_segment_days / NULLIF(
            active_road_segments
            * (DATEDIFF(last_recorded_date, first_recorded_date) + 1),
            0
        ) * 100 AS estimated_coverage_pct
    FROM yearly_coverage
)
SELECT
    calendar_year,
    first_recorded_date,
    last_recorded_date,
    dates_with_data,
    active_road_segments,
    active_segment_days,
    total_vehicles,
    ROUND(vehicles_per_active_segment_day, 2)
        AS vehicles_per_active_segment_day,
    ROUND(estimated_coverage_pct, 2)
        AS estimated_coverage_pct,
    ROUND(
        (
            vehicles_per_active_segment_day
            - LAG(vehicles_per_active_segment_day)
                OVER (ORDER BY calendar_year)
        ) / NULLIF(
            LAG(vehicles_per_active_segment_day)
                OVER (ORDER BY calendar_year),
            0
        ) * 100,
        2
    ) AS normalized_intensity_yoy_pct
FROM coverage_metrics
ORDER BY calendar_year;


-- =========================================================
-- ANALITINIS KLAUSIMAS 3
-- Kuriuose kelių ruožuose 2023 m. vidutiniškai per dieną
-- pravažiavo daugiausia transporto priemonių?
-- Analizuojami tik ruožai, turintys bent 300 dienų duomenų.
-- =========================================================

SELECT
    a.road_segment_id,
    r.road_number,
    r.location_name,
    r.kilometer,
    COUNT(DISTINCT a.date_key) AS recorded_days,
    SUM(a.total_vehicles) AS total_vehicles,
    ROUND(
        SUM(a.total_vehicles)
        / NULLIF(COUNT(DISTINCT a.date_key), 0),
        2
    ) AS average_daily_vehicles,
    ROUND(
        SUM(
            a.weighted_average_speed_kmh
            * a.valid_speed_vehicle_count
        ) / NULLIF(SUM(a.valid_speed_vehicle_count), 0),
        2
    ) AS weighted_average_speed_kmh
FROM agg_daily_road_traffic AS a
INNER JOIN dim_date AS d
    ON d.date_key = a.date_key
INNER JOIN dim_road_segment AS r
    ON r.road_segment_id = a.road_segment_id
WHERE d.calendar_year = 2023
GROUP BY
    a.road_segment_id,
    r.road_number,
    r.location_name,
    r.kilometer
HAVING COUNT(DISTINCT a.date_key) >= 300
ORDER BY average_daily_vehicles DESC
LIMIT 10;


-- =========================================================
-- ANALITINIS KLAUSIMAS 4
-- Kuriuose intensyviuose kelių ruožuose 2023 m. vidutinis
-- greitis buvo mažiausias?
-- Lyginami 50 intensyviausių ruožų, turinčių bent 300 dienų.
-- Mažesnis greitis savaime neįrodo spūsčių.
-- =========================================================

WITH segment_metrics AS (
    SELECT
        a.road_segment_id,
        r.road_number,
        r.location_name,
        r.kilometer,
        COUNT(DISTINCT a.date_key) AS recorded_days,
        SUM(a.total_vehicles)
            / NULLIF(COUNT(DISTINCT a.date_key), 0)
            AS average_daily_vehicles,
        SUM(
            a.weighted_average_speed_kmh
            * a.valid_speed_vehicle_count
        ) / NULLIF(
            SUM(a.valid_speed_vehicle_count),
            0
        ) AS weighted_average_speed_kmh
    FROM agg_daily_road_traffic AS a
    INNER JOIN dim_date AS d
        ON d.date_key = a.date_key
    INNER JOIN dim_road_segment AS r
        ON r.road_segment_id = a.road_segment_id
    WHERE d.calendar_year = 2023
    GROUP BY
        a.road_segment_id,
        r.road_number,
        r.location_name,
        r.kilometer
    HAVING COUNT(DISTINCT a.date_key) >= 300
),
ranked_segments AS (
    SELECT
        segment_metrics.*,
        ROW_NUMBER() OVER (
            ORDER BY average_daily_vehicles DESC
        ) AS traffic_rank
    FROM segment_metrics
)
SELECT
    traffic_rank,
    road_segment_id,
    road_number,
    location_name,
    kilometer,
    recorded_days,
    ROUND(average_daily_vehicles, 2)
        AS average_daily_vehicles,
    ROUND(weighted_average_speed_kmh, 2)
        AS weighted_average_speed_kmh
FROM ranked_segments
WHERE traffic_rank <= 50
  AND weighted_average_speed_kmh IS NOT NULL
ORDER BY weighted_average_speed_kmh ASC
LIMIT 10;


-- =========================================================
-- ANALITINIS KLAUSIMAS 5
-- Ar daugiau transporto priemonių buvo užfiksuota kelio
-- kryptimi (T), ar priešinga kryptimi (N)?
-- Šiam klausimui naudojami trys patikrinimai, nes pradinės
-- proporcijos parodė galimą šaltinio duomenų disbalansą.
-- =========================================================

-- 5A. Užfiksuoto transporto kiekio dalis pagal kryptį.

WITH direction_totals AS (
    SELECT
        d.calendar_year,
        a.travel_direction_code,
        a.travel_direction_name,
        SUM(a.total_vehicles) AS total_vehicles
    FROM agg_daily_road_traffic AS a
    INNER JOIN dim_date AS d
        ON d.date_key = a.date_key
    WHERE d.calendar_year BETWEEN 2019 AND 2023
    GROUP BY
        d.calendar_year,
        a.travel_direction_code,
        a.travel_direction_name
)
SELECT
    calendar_year,
    travel_direction_code,
    travel_direction_name,
    total_vehicles,
    ROUND(
        total_vehicles / NULLIF(
            SUM(total_vehicles) OVER (PARTITION BY calendar_year),
            0
        ) * 100,
        2
    ) AS direction_share_pct
FROM direction_totals
ORDER BY calendar_year, total_vehicles DESC;


-- 5B. Skaitiklių ir stebėjimo dienų aprėptis pagal kryptį.

WITH direction_coverage AS (
    SELECT
        d.calendar_year,
        a.travel_direction_code,
        a.travel_direction_name,
        COUNT(DISTINCT a.road_segment_id) AS active_road_segments,
        COUNT(
            DISTINCT CONCAT(a.date_key, '-', a.road_segment_id)
        ) AS active_segment_days,
        SUM(a.total_vehicles) AS total_vehicles
    FROM agg_daily_road_traffic AS a
    INNER JOIN dim_date AS d
        ON d.date_key = a.date_key
    WHERE d.calendar_year BETWEEN 2019 AND 2023
    GROUP BY
        d.calendar_year,
        a.travel_direction_code,
        a.travel_direction_name
)
SELECT
    calendar_year,
    travel_direction_code,
    travel_direction_name,
    active_road_segments,
    active_segment_days,
    total_vehicles,
    ROUND(
        total_vehicles / NULLIF(active_segment_days, 0),
        2
    ) AS vehicles_per_active_segment_day,
    ROUND(
        active_segment_days / NULLIF(
            SUM(active_segment_days)
                OVER (PARTITION BY calendar_year),
            0
        ) * 100,
        2
    ) AS segment_day_share_pct
FROM direction_coverage
ORDER BY calendar_year, travel_direction_code;


-- 5C. Pradinių eilučių struktūra ir kokybė pagal kryptį.

SELECT
    d.calendar_year,
    a.travel_direction_code,
    a.travel_direction_name,
    SUM(a.source_row_count) AS source_rows,
    SUM(a.total_vehicles) AS total_vehicles,
    ROUND(
        SUM(a.total_vehicles)
        / NULLIF(SUM(a.source_row_count), 0),
        2
    ) AS vehicles_per_source_row,
    SUM(a.valid_speed_vehicle_count) AS valid_speed_vehicle_count,
    SUM(a.missing_speed_row_count) AS missing_speed_rows,
    SUM(a.outlier_speed_row_count) AS outlier_speed_rows
FROM agg_daily_road_traffic AS a
INNER JOIN dim_date AS d
    ON d.date_key = a.date_key
WHERE d.calendar_year BETWEEN 2019 AND 2023
GROUP BY
    d.calendar_year,
    a.travel_direction_code,
    a.travel_direction_name
ORDER BY calendar_year, travel_direction_code;


-- =========================================================
-- ANALITINIS KLAUSIMAS 6
-- Kiek greičio duomenų kiekvienais metais trūko arba buvo
-- pažymėti kaip neįprasti?
-- =========================================================

WITH yearly_quality AS (
    SELECT
        d.calendar_year,
        SUM(a.source_row_count) AS source_rows,
        SUM(a.missing_speed_row_count) AS missing_speed_rows,
        SUM(a.outlier_speed_row_count) AS outlier_speed_rows
    FROM agg_daily_road_traffic AS a
    INNER JOIN dim_date AS d
        ON d.date_key = a.date_key
    WHERE d.calendar_year BETWEEN 2018 AND 2023
    GROUP BY d.calendar_year
)
SELECT
    calendar_year,
    source_rows,
    missing_speed_rows,
    outlier_speed_rows,
    ROUND(
        missing_speed_rows / NULLIF(source_rows, 0) * 100,
        4
    ) AS missing_speed_pct,
    ROUND(
        outlier_speed_rows / NULLIF(source_rows, 0) * 100,
        4
    ) AS outlier_speed_pct,
    ROUND(
        (missing_speed_rows + outlier_speed_rows)
        / NULLIF(source_rows, 0) * 100,
        4
    ) AS speed_problem_pct
FROM yearly_quality
ORDER BY calendar_year;


-- =========================================================
-- ANALITINIS KLAUSIMAS 7
-- Kuriuose kelių ruožuose 2023 m. dienos srautas labiausiai
-- pasikeitė, palyginti su 2022 m.?
-- Lyginami ruožai, turintys bent 300 dienų ir bent 1 000
-- transporto priemonių vidutinį dienos srautą abiem metais.
-- =========================================================

WITH segment_year_metrics AS (
    SELECT
        d.calendar_year,
        a.road_segment_id,
        COUNT(DISTINCT a.date_key) AS recorded_days,
        SUM(a.total_vehicles)
            / NULLIF(COUNT(DISTINCT a.date_key), 0)
            AS average_daily_vehicles
    FROM agg_daily_road_traffic AS a
    INNER JOIN dim_date AS d
        ON d.date_key = a.date_key
    WHERE d.calendar_year IN (2022, 2023)
    GROUP BY
        d.calendar_year,
        a.road_segment_id
    HAVING COUNT(DISTINCT a.date_key) >= 300
),
segment_comparison AS (
    SELECT
        road_segment_id,
        MAX(
            CASE
                WHEN calendar_year = 2022
                THEN average_daily_vehicles
            END
        ) AS average_daily_vehicles_2022,
        MAX(
            CASE
                WHEN calendar_year = 2023
                THEN average_daily_vehicles
            END
        ) AS average_daily_vehicles_2023
    FROM segment_year_metrics
    GROUP BY road_segment_id
),
complete_comparison AS (
    SELECT
        road_segment_id,
        average_daily_vehicles_2022,
        average_daily_vehicles_2023,
        (
            average_daily_vehicles_2023
            - average_daily_vehicles_2022
        ) / NULLIF(average_daily_vehicles_2022, 0) * 100
            AS change_pct
    FROM segment_comparison
    WHERE average_daily_vehicles_2022 >= 1000
      AND average_daily_vehicles_2023 >= 1000
)
SELECT
    c.road_segment_id,
    r.road_number,
    r.location_name,
    r.kilometer,
    ROUND(c.average_daily_vehicles_2022, 2)
        AS average_daily_vehicles_2022,
    ROUND(c.average_daily_vehicles_2023, 2)
        AS average_daily_vehicles_2023,
    ROUND(c.change_pct, 2) AS change_pct
FROM complete_comparison AS c
INNER JOIN dim_road_segment AS r
    ON r.road_segment_id = c.road_segment_id
ORDER BY ABS(c.change_pct) DESC
LIMIT 10;
