USE lithuania_traffic;

TRUNCATE TABLE dim_date;

SET SESSION cte_max_recursion_depth = 5000;

INSERT INTO dim_date (
    date_key,
    date_value,
    calendar_year,
    quarter_number,
    month_number,
    month_name,
    day_of_month,
    weekday_number,
    weekday_name,
    is_weekend
)
WITH RECURSIVE date_series AS (
    SELECT DATE('2017-01-01') AS date_value

    UNION ALL

    SELECT date_value + INTERVAL 1 DAY
    FROM date_series
    WHERE date_value < DATE('2024-12-31')
)
SELECT
    CAST(
        DATE_FORMAT(date_value, '%Y%m%d')
        AS UNSIGNED
    ),
    date_value,
    YEAR(date_value),
    QUARTER(date_value),
    MONTH(date_value),

    CASE MONTH(date_value)
        WHEN 1 THEN 'Sausis'
        WHEN 2 THEN 'Vasaris'
        WHEN 3 THEN 'Kovas'
        WHEN 4 THEN 'Balandis'
        WHEN 5 THEN 'Gegužė'
        WHEN 6 THEN 'Birželis'
        WHEN 7 THEN 'Liepa'
        WHEN 8 THEN 'Rugpjūtis'
        WHEN 9 THEN 'Rugsėjis'
        WHEN 10 THEN 'Spalis'
        WHEN 11 THEN 'Lapkritis'
        WHEN 12 THEN 'Gruodis'
    END,

    DAY(date_value),
    WEEKDAY(date_value) + 1,

    CASE WEEKDAY(date_value)
        WHEN 0 THEN 'Pirmadienis'
        WHEN 1 THEN 'Antradienis'
        WHEN 2 THEN 'Trečiadienis'
        WHEN 3 THEN 'Ketvirtadienis'
        WHEN 4 THEN 'Penktadienis'
        WHEN 5 THEN 'Šeštadienis'
        WHEN 6 THEN 'Sekmadienis'
    END,

    CASE
        WHEN WEEKDAY(date_value) IN (5, 6)
        THEN 1
        ELSE 0
    END

FROM date_series;

SELECT
    COUNT(*) AS date_count,
    MIN(date_value) AS first_date,
    MAX(date_value) AS last_date
FROM dim_date;