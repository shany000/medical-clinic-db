
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_book_appointment(
    p_doctor_id BIGINT,
    p_patient_id BIGINT,
    p_starts_at TIMESTAMPTZ,
    p_service_ids BIGINT[]
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_schedule_id BIGINT;
    v_ends_at TIMESTAMPTZ;
    v_appointment_id BIGINT;
    v_inserted_count BIGINT;
BEGIN
    IF p_doctor_id IS NULL
       OR p_patient_id IS NULL
       OR p_starts_at IS NULL
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '22023',
                MESSAGE = 'Необходимо указать врача, пациента и начало приёма.';
    END IF;

    SELECT
        slots.schedule_id,
        slots.available_ends_at
    INTO
        v_schedule_id,
        v_ends_at
    FROM public.fn_get_available_appointment_slots(
        p_doctor_id,
        p_service_ids,
        (p_starts_at AT TIME ZONE 'Europe/Moscow')::DATE,
        p_patient_id
    ) AS slots
    WHERE slots.available_starts_at = p_starts_at
    ORDER BY slots.schedule_id
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Выбранное время недоступно для указанного врача, пациента и набора услуг.';
    END IF;

    INSERT INTO public.appointments (
        schedule_id,
        patient_id,
        starts_at,
        ends_at
    )
    VALUES (
        v_schedule_id,
        p_patient_id,
        p_starts_at,
        v_ends_at
    )
    RETURNING appointment_id
    INTO v_appointment_id;

    INSERT INTO public.appointment_services (
        appointment_id,
        service_id,
        duration_minutes_at_booking,
        price_at_booking
    )
    SELECT
        v_appointment_id,
        requested.service_id,
        s.duration_minutes,
        s.price
    FROM UNNEST(p_service_ids) AS requested(service_id)
    JOIN public.services s
        ON s.service_id = requested.service_id
    JOIN public.doctor_services ds
        ON ds.service_id = s.service_id
       AND ds.doctor_id = p_doctor_id
    WHERE s.is_active = TRUE
      AND ds.is_active = TRUE;

    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

    IF v_inserted_count <> CARDINALITY(p_service_ids) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Не удалось добавить все выбранные медицинские услуги.';
    END IF;

    RETURN v_appointment_id;
END;
$$;

COMMIT;
