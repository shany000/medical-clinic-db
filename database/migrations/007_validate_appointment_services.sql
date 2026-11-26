
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_validate_appointment_service_line()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_appointment_id BIGINT;
    v_doctor_id BIGINT;
    v_employment_status VARCHAR(20);
    v_appointment_status VARCHAR(20);
    v_schedule_cancelled_at TIMESTAMPTZ;
    v_service_price NUMERIC(12, 2);
    v_service_duration INTEGER;
    v_doctor_service_active BOOLEAN;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_appointment_id := OLD.appointment_id;
    ELSE
        v_appointment_id := NEW.appointment_id;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF NEW.appointment_service_id IS DISTINCT FROM OLD.appointment_service_id
           OR NEW.appointment_id IS DISTINCT FROM OLD.appointment_id
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Нельзя изменять идентификатор строки услуги или переносить её в другую запись.';
        END IF;

        IF NEW.price_at_booking IS DISTINCT FROM OLD.price_at_booking
           OR NEW.duration_minutes_at_booking IS DISTINCT FROM OLD.duration_minutes_at_booking
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Нельзя напрямую изменять сохранённые стоимость и продолжительность услуги.';
        END IF;
    END IF;

    SELECT ds.doctor_id
    INTO v_doctor_id
    FROM public.appointments a
    JOIN public.doctor_schedule ds
        ON ds.schedule_id = a.schedule_id
    WHERE a.appointment_id = v_appointment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = 'Запись на приём не найдена.';
    END IF;

    SELECT employment_status
    INTO v_employment_status
    FROM public.doctors
    WHERE doctor_id = v_doctor_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = 'Врач записи не найден.';
    END IF;

    SELECT
        a.status,
        ds.cancelled_at
    INTO
        v_appointment_status,
        v_schedule_cancelled_at
    FROM public.appointments a
    JOIN public.doctor_schedule ds
        ON ds.schedule_id = a.schedule_id
    WHERE a.appointment_id = v_appointment_id
    FOR UPDATE OF a;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = 'Запись на приём не найдена.';
    END IF;

    IF v_appointment_status <> 'scheduled' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Изменять услуги можно только у записей со статусом scheduled.';
    END IF;

    IF v_schedule_cancelled_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Нельзя изменять услуги записи из отменённого рабочего интервала.';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    IF v_employment_status <> 'active' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Добавлять и изменять услуги можно только в записях к действующим врачам.';
    END IF;

    SELECT
        price,
        duration_minutes
    INTO
        v_service_price,
        v_service_duration
    FROM public.services
    WHERE service_id = NEW.service_id
      AND is_active = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Выбранная медицинская услуга отсутствует или неактивна.';
    END IF;

    SELECT is_active
    INTO v_doctor_service_active
    FROM public.doctor_services
    WHERE doctor_id = v_doctor_id
      AND service_id = NEW.service_id;

    IF NOT FOUND OR v_doctor_service_active IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Врач не оказывает выбранную медицинскую услугу.';
    END IF;

    IF TG_OP = 'UPDATE'
       AND NEW.service_id IS NOT DISTINCT FROM OLD.service_id
    THEN
        RETURN NEW;
    END IF;

    NEW.price_at_booking := v_service_price;
    NEW.duration_minutes_at_booking := v_service_duration;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_appointment_services_validate
BEFORE INSERT OR UPDATE OR DELETE
ON public.appointment_services
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_appointment_service_line();


CREATE OR REPLACE FUNCTION public.fn_assert_appointment_service_total(
    p_appointment_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_starts_at TIMESTAMPTZ;
    v_ends_at TIMESTAMPTZ;
    v_line_count BIGINT;
    v_total_duration BIGINT;
    v_appointment_seconds NUMERIC;
BEGIN
    SELECT
        starts_at,
        ends_at
    INTO
        v_starts_at,
        v_ends_at
    FROM public.appointments
    WHERE appointment_id = p_appointment_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT
        COUNT(*),
        COALESCE(SUM(duration_minutes_at_booking), 0)
    INTO
        v_line_count,
        v_total_duration
    FROM public.appointment_services
    WHERE appointment_id = p_appointment_id;

    IF v_line_count = 0 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Каждая запись на приём должна содержать хотя бы одну медицинскую услугу.';
    END IF;

    v_appointment_seconds :=
        EXTRACT(EPOCH FROM (v_ends_at - v_starts_at));

    IF v_total_duration * 60 <> v_appointment_seconds THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Суммарная продолжительность услуг должна совпадать с продолжительностью приёма.';
    END IF;
END;
$$;


CREATE OR REPLACE FUNCTION public.fn_check_appointment_service_total()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_appointment_id BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_appointment_id := OLD.appointment_id;
    ELSE
        v_appointment_id := NEW.appointment_id;
    END IF;

    PERFORM public.fn_assert_appointment_service_total(
        v_appointment_id
    );

    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_appointments_require_service_lines
AFTER INSERT OR UPDATE
ON public.appointments
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.fn_check_appointment_service_total();

CREATE CONSTRAINT TRIGGER trg_appointment_services_validate_total
AFTER INSERT OR UPDATE OR DELETE
ON public.appointment_services
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.fn_check_appointment_service_total();

COMMIT;
