WITH params AS (
    SELECT
        DATE '2026-11-01'::TIMESTAMP AT TIME ZONE 'Europe/Moscow' AS period_start,
        DATE '2027-01-01'::TIMESTAMP AT TIME ZONE 'Europe/Moscow' AS period_end
),
schedule_load AS (
    SELECT
        ds.doctor_id,
        SUM(
            EXTRACT(
                EPOCH FROM (
                    LEAST(ds.ends_at, prm.period_end)
                    - GREATEST(ds.starts_at, prm.period_start)
                )
            ) / 60.0
        ) AS schedule_minutes
    FROM public.doctor_schedule ds
    CROSS JOIN params prm
    WHERE ds.cancelled_at IS NULL
      AND ds.starts_at < prm.period_end
      AND ds.ends_at > prm.period_start
    GROUP BY ds.doctor_id
),
appointment_load AS (
    SELECT
        ds.doctor_id,
        SUM(
            EXTRACT(
                EPOCH FROM (
                    LEAST(a.ends_at, prm.period_end)
                    - GREATEST(a.starts_at, prm.period_start)
                )
            ) / 60.0
        ) AS occupied_minutes
    FROM public.appointments a
    JOIN public.doctor_schedule ds
        ON ds.schedule_id = a.schedule_id
    CROSS JOIN params prm
    WHERE a.status <> 'cancelled'
      AND ds.cancelled_at IS NULL
      AND a.starts_at < prm.period_end
      AND a.ends_at > prm.period_start
    GROUP BY ds.doctor_id
)
SELECT
    d.doctor_id,
    d.last_name || ' ' || d.first_name AS doctor,
    ROUND(COALESCE(sl.schedule_minutes, 0), 1) AS schedule_minutes,
    ROUND(COALESCE(al.occupied_minutes, 0), 1) AS occupied_minutes,
    ROUND(
        100.0 * COALESCE(al.occupied_minutes, 0)
        / NULLIF(sl.schedule_minutes, 0),
        1
    ) AS utilization_pct
FROM public.doctors d
LEFT JOIN schedule_load sl
    ON sl.doctor_id = d.doctor_id
LEFT JOIN appointment_load al
    ON al.doctor_id = d.doctor_id
ORDER BY utilization_pct DESC NULLS LAST, doctor;