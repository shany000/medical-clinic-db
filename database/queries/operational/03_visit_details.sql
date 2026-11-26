SELECT
    v.visit_id,
    a.appointment_id,
    p.last_name || ' ' || p.first_name AS patient,
    d.last_name || ' ' || d.first_name AS doctor,
    v.complaints,
    v.anamnesis,
    v.examination_results,
    v.conclusion,
    sv.services,
    dg.diagnoses,
    pr.prescriptions,
    v.created_at
FROM public.visits v
JOIN public.appointments a
    ON a.appointment_id = v.appointment_id
JOIN public.patients p
    ON p.patient_id = a.patient_id
JOIN public.doctor_schedule ds
    ON ds.schedule_id = a.schedule_id
JOIN public.doctors d
    ON d.doctor_id = ds.doctor_id
LEFT JOIN LATERAL (
    SELECT STRING_AGG(s.name, ', ' ORDER BY s.name) AS services
    FROM public.appointment_services aps
    JOIN public.services s
        ON s.service_id = aps.service_id
    WHERE aps.appointment_id = a.appointment_id
) sv ON TRUE
LEFT JOIN LATERAL (
    SELECT STRING_AGG(dg.name, ', ' ORDER BY dg.name) AS diagnoses
    FROM public.visit_diagnoses vd
    JOIN public.diagnoses dg
        ON dg.diagnosis_id = vd.diagnosis_id
    WHERE vd.visit_id = v.visit_id
) dg ON TRUE
LEFT JOIN LATERAL (
    SELECT STRING_AGG(
        CONCAT_WS(', ', pr.medication_name, pr.dosage, pr.frequency, pr.duration),
        '; ' ORDER BY pr.prescription_id
    ) AS prescriptions
    FROM public.prescriptions pr
    WHERE pr.visit_id = v.visit_id
) pr ON TRUE
WHERE p.email = 'demo.patient01@example.test'
ORDER BY v.created_at DESC;