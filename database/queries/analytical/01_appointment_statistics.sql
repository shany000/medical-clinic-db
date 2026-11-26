WITH params AS (
    SELECT
        DATE '2026-11-01'::TIMESTAMP AT TIME ZONE 'Europe/Moscow' AS period_start,
        DATE '2027-01-01'::TIMESTAMP AT TIME ZONE 'Europe/Moscow' AS period_end
)
SELECT
    d.doctor_id,
    d.last_name || ' ' || d.first_name AS doctor,
    COUNT(a.appointment_id) AS total_appointments,
    COUNT(a.appointment_id) FILTER (
        WHERE a.status = 'completed'
    ) AS completed,
    COUNT(a.appointment_id) FILTER (
        WHERE a.status = 'scheduled'
    ) AS scheduled,
    COUNT(a.appointment_id) FILTER (
        WHERE a.status = 'cancelled'
    ) AS cancelled,
    COUNT(a.appointment_id) FILTER (
        WHERE a.status = 'no_show'
    ) AS no_show,
    ROUND(
        100.0 * COUNT(a.appointment_id) FILTER (
            WHERE a.status = 'completed'
        ) / NULLIF(
            COUNT(a.appointment_id) FILTER (
                WHERE a.status IN ('completed', 'no_show')
            ),
            0
        ),
        1
    ) AS completion_rate_pct
FROM public.doctors d
CROSS JOIN params prm
LEFT JOIN public.doctor_schedule ds
    ON ds.doctor_id = d.doctor_id
LEFT JOIN public.appointments a
    ON a.schedule_id = ds.schedule_id
   AND a.starts_at >= prm.period_start
   AND a.starts_at < prm.period_end
GROUP BY
    d.doctor_id,
    d.last_name,
    d.first_name
ORDER BY total_appointments DESC, doctor;