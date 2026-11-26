WITH params AS (
    SELECT
        'demo.doctor01@example.test'::VARCHAR AS doctor_email,
        DATE '2026-12-03' AS work_date
)
SELECT
    d.last_name || ' ' || d.first_name AS doctor,
    sp.specialties,
    ds.schedule_id,
    ds.starts_at AT TIME ZONE 'Europe/Moscow' AS schedule_start,
    ds.ends_at AT TIME ZONE 'Europe/Moscow' AS schedule_end,
    a.appointment_id,
    p.last_name || ' ' || p.first_name AS patient,
    a.starts_at AT TIME ZONE 'Europe/Moscow' AS appointment_start,
    a.ends_at AT TIME ZONE 'Europe/Moscow' AS appointment_end,
    a.status,
    COALESCE(sv.services, 'Свободный интервал') AS services,
    a.cancellation_reason
FROM params prm
JOIN public.doctors d
    ON d.email = prm.doctor_email
JOIN public.doctor_schedule ds
    ON ds.doctor_id = d.doctor_id
LEFT JOIN public.appointments a
    ON a.schedule_id = ds.schedule_id
LEFT JOIN public.patients p
    ON p.patient_id = a.patient_id
LEFT JOIN LATERAL (
    SELECT STRING_AGG(s.name, ', ' ORDER BY s.name) AS services
    FROM public.appointment_services aps
    JOIN public.services s
        ON s.service_id = aps.service_id
    WHERE aps.appointment_id = a.appointment_id
) sv ON TRUE
LEFT JOIN LATERAL (
    SELECT STRING_AGG(s.name, ', ' ORDER BY s.name) AS specialties
    FROM public.doctor_specialties dsp
    JOIN public.specialties s
        ON s.specialty_id = dsp.specialty_id
    WHERE dsp.doctor_id = d.doctor_id
      AND dsp.is_active = TRUE
      AND s.deleted_at IS NULL
) sp ON TRUE
WHERE ds.cancelled_at IS NULL
  AND ds.starts_at < ((prm.work_date + 1)::TIMESTAMP AT TIME ZONE 'Europe/Moscow')
  AND ds.ends_at > (prm.work_date::TIMESTAMP AT TIME ZONE 'Europe/Moscow')
ORDER BY a.starts_at NULLS FIRST;