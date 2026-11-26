WITH params AS (
    SELECT
        d.doctor_id,
        p.patient_id,
        s.service_id,
        DATE '2026-12-03' AS work_date
    FROM public.doctors d
    CROSS JOIN public.patients p
    CROSS JOIN public.services s
    WHERE d.email = 'demo.doctor01@example.test'
      AND p.email = 'demo.patient01@example.test'
      AND s.name = 'Первичная консультация терапевта'
)
SELECT
    slots.schedule_id,
    slots.available_starts_at AT TIME ZONE 'Europe/Moscow' AS available_start,
    slots.available_ends_at AT TIME ZONE 'Europe/Moscow' AS available_end,
    slots.total_duration_minutes,
    slots.total_price
FROM params prm
CROSS JOIN LATERAL public.fn_get_available_appointment_slots(
    prm.doctor_id,
    ARRAY[prm.service_id]::BIGINT[],
    prm.work_date,
    prm.patient_id
) slots
ORDER BY slots.available_starts_at;