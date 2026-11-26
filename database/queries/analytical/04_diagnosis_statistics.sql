WITH params AS (
    SELECT
        DATE '2026-11-01'::TIMESTAMP AT TIME ZONE 'Europe/Moscow' AS period_start,
        DATE '2027-01-01'::TIMESTAMP AT TIME ZONE 'Europe/Moscow' AS period_end
),
visit_data AS (
    SELECT
        v.visit_id,
        a.patient_id
    FROM public.visits v
    JOIN public.appointments a
        ON a.appointment_id = v.appointment_id
    CROSS JOIN params prm
    WHERE a.starts_at >= prm.period_start
      AND a.starts_at < prm.period_end
),
diagnosis_usage AS (
    SELECT
        vd.diagnosis_id,
        COUNT(DISTINCT vd.visit_id) AS visits_count,
        COUNT(DISTINCT vd_data.patient_id) AS patients_count
    FROM public.visit_diagnoses vd
    JOIN visit_data vd_data
        ON vd_data.visit_id = vd.visit_id
    GROUP BY vd.diagnosis_id
)
SELECT
    d.diagnosis_id,
    d.name AS diagnosis,
    CASE
        WHEN d.deleted_at IS NULL THEN 'active'
        ELSE 'deleted'
    END AS catalog_status,
    COALESCE(du.visits_count, 0) AS visits_count,
    COALESCE(du.patients_count, 0) AS patients_count
FROM public.diagnoses d
LEFT JOIN diagnosis_usage du
    ON du.diagnosis_id = d.diagnosis_id
ORDER BY visits_count DESC, diagnosis;