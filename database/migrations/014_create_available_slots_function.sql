
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_get_available_appointment_slots(
    p_doctor_id BIGINT,
    p_service_ids BIGINT[],
    p_date DATE,
    p_patient_id BIGINT DEFAULT NULL
)
RETURNS TABLE (
    schedule_id BIGINT,
    available_starts_at TIMESTAMPTZ,
    available_ends_at TIMESTAMPTZ,
    total_duration_minutes BIGINT,
    total_price NUMERIC
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_employment_status VARCHAR(20);
    v_patient_deleted_at TIMESTAMPTZ;
    v_valid_service_count BIGINT;
    v_total_duration_minutes BIGINT;
    v_total_price NUMERIC;
    v_day_start TIMESTAMPTZ;
    v_day_end TIMESTAMPTZ;
    v_duration_interval INTERVAL;
BEGIN
    IF p_doctor_id IS NULL OR p_date IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '22023',
                MESSAGE = 'Необходимо указать врача и дату поиска.';
    END IF;

    IF p_service_ids IS NULL OR CARDINALITY(p_service_ids) = 0 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '22023',
                MESSAGE = 'Необходимо указать хотя бы одну медицинскую услугу.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM UNNEST(p_service_ids) AS requested(service_id)
        WHERE requested.service_id IS NULL
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '22023',
                MESSAGE = 'Массив медицинских услуг не должен содержать NULL.';
    END IF;

    SELECT employment_status
    INTO v_employment_status
    FROM public.doctors
    WHERE doctor_id = p_doctor_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = 'Указанный врач не существует.';
    END IF;

    IF v_employment_status <> 'active' THEN
        RETURN;
    END IF;

    IF p_patient_id IS NOT NULL THEN
        SELECT deleted_at
        INTO v_patient_deleted_at
        FROM public.patients
        WHERE patient_id = p_patient_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE = 'Указанный пациент не существует.';
        END IF;

        IF v_patient_deleted_at IS NOT NULL THEN
            RETURN;
        END IF;
    END IF;

    SELECT
        COUNT(*),
        COALESCE(SUM(s.duration_minutes), 0),
        COALESCE(SUM(s.price), 0)
    INTO
        v_valid_service_count,
        v_total_duration_minutes,
        v_total_price
    FROM UNNEST(p_service_ids) AS requested(service_id)
    JOIN public.services s
        ON s.service_id = requested.service_id
    JOIN public.doctor_services ds
        ON ds.service_id = s.service_id
       AND ds.doctor_id = p_doctor_id
    WHERE s.is_active = TRUE
      AND ds.is_active = TRUE;

    IF v_valid_service_count <> CARDINALITY(p_service_ids) THEN
        RETURN;
    END IF;

    IF v_total_duration_minutes > 2147483647 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '22003',
                MESSAGE = 'Суммарная продолжительность выбранных услуг превышает допустимое значение.';
    END IF;

    v_duration_interval :=
        MAKE_INTERVAL(mins => v_total_duration_minutes::INTEGER);

    v_day_start :=
        (p_date::TIMESTAMP) AT TIME ZONE 'Europe/Moscow';

    v_day_end :=
        ((p_date + 1)::TIMESTAMP) AT TIME ZONE 'Europe/Moscow';

    RETURN QUERY
    SELECT
        ds.schedule_id,
        slot.slot_start,
        slot.slot_start + v_duration_interval,
        v_total_duration_minutes,
        v_total_price
    FROM public.doctor_schedule ds
    CROSS JOIN LATERAL GENERATE_SERIES(
        ds.starts_at,
        ds.ends_at - v_duration_interval,
        INTERVAL '15 minutes'
    ) AS slot(slot_start)
    WHERE ds.doctor_id = p_doctor_id
      AND ds.cancelled_at IS NULL
      AND ds.starts_at < v_day_end
      AND ds.ends_at > v_day_start
      AND slot.slot_start >= v_day_start
      AND slot.slot_start < v_day_end
      AND slot.slot_start >= CURRENT_TIMESTAMP

      AND NOT EXISTS (
          SELECT 1
          FROM public.appointments a
          JOIN public.doctor_schedule occupied_schedule
              ON occupied_schedule.schedule_id = a.schedule_id
          WHERE occupied_schedule.doctor_id = p_doctor_id
            AND a.status <> 'cancelled'
            AND a.starts_at < slot.slot_start + v_duration_interval
            AND a.ends_at > slot.slot_start
      )

      AND (
          p_patient_id IS NULL
          OR NOT EXISTS (
              SELECT 1
              FROM public.appointments a
              WHERE a.patient_id = p_patient_id
                AND a.status <> 'cancelled'
                AND a.starts_at < slot.slot_start + v_duration_interval
                AND a.ends_at > slot.slot_start
          )
      )
    ORDER BY slot.slot_start, ds.schedule_id;
END;
$$;

COMMIT;
