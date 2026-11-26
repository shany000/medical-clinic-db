WITH params AS (
    SELECT
        DATE '2026-11-01'::TIMESTAMP AT TIME ZONE 'Europe/Moscow' AS period_start,
        DATE '2027-01-01'::TIMESTAMP AT TIME ZONE 'Europe/Moscow' AS period_end
),
service_usage AS (
    SELECT
        aps.service_id,
        COUNT(DISTINCT a.appointment_id) AS completed_appointments,
        COUNT(aps.appointment_service_id) AS service_lines,
        SUM(aps.price_at_booking) AS completed_service_value
    FROM public.appointment_services aps
    JOIN public.appointments a
        ON a.appointment_id = aps.appointment_id
    CROSS JOIN params prm
    WHERE a.status = 'completed'
      AND a.starts_at >= prm.period_start
      AND a.starts_at < prm.period_end
    GROUP BY aps.service_id
)
SELECT
    s.service_id,
    s.name AS service,
    s.price AS current_catalog_price,
    s.is_active,
    COALESCE(su.completed_appointments, 0) AS completed_appointments,
    COALESCE(su.service_lines, 0) AS service_lines,
    ROUND(COALESCE(su.completed_service_value, 0), 2) AS completed_service_value
FROM public.services s
LEFT JOIN service_usage su
    ON su.service_id = s.service_id
ORDER BY completed_service_value DESC, service;