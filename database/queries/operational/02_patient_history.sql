SELECT
    a.appointment_id,
    d.last_name || ' ' || d.first_name AS doctor,
    a.starts_at AT TIME ZONE 'Europe/Moscow' AS appointment_start,
    a.ends_at AT TIME ZONE 'Europe/Moscow' AS appointment_end,
    a.status,
    COALESCE(sv.services, 'Нет услуг') AS services,
    a.cancellation_reason,
    COALESCE(ivs.status, 'not_issued') AS invoice_status
FROM public.appointments a
JOIN public.patients p
    ON p.patient_id = a.patient_id
JOIN public.doctor_schedule ds
    ON ds.schedule_id = a.schedule_id
JOIN public.doctors d
    ON d.doctor_id = ds.doctor_id
LEFT JOIN public.visits v
    ON v.appointment_id = a.appointment_id
LEFT JOIN public.v_invoice_status ivs
    ON ivs.visit_id = v.visit_id
LEFT JOIN LATERAL (
    SELECT STRING_AGG(s.name, ', ' ORDER BY s.name) AS services
    FROM public.appointment_services aps
    JOIN public.services s
        ON s.service_id = aps.service_id
    WHERE aps.appointment_id = a.appointment_id
) sv ON TRUE
WHERE p.email = 'demo.patient01@example.test'
ORDER BY a.starts_at DESC;