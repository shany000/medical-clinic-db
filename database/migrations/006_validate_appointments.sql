
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_validate_appointment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_doctor_id BIGINT;
    v_schedule_starts_at TIMESTAMPTZ;
    v_schedule_ends_at TIMESTAMPTZ;
    v_schedule_cancelled_at TIMESTAMPTZ;
    v_employment_status VARCHAR(20);
    v_patient_deleted_at TIMESTAMPTZ;
BEGIN
    IF TG_OP = 'UPDATE' THEN

        IF NEW.schedule_id IS DISTINCT FROM OLD.schedule_id
           OR NEW.patient_id IS DISTINCT FROM OLD.patient_id
           OR NEW.starts_at IS DISTINCT FROM OLD.starts_at
           OR NEW.ends_at IS DISTINCT FROM OLD.ends_at
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Нельзя изменять пациента и временной интервал созданной записи. Для переноса отмените старую запись и создайте новую.';
        END IF;

        IF OLD.status <> 'scheduled'
           AND NEW.status IS DISTINCT FROM OLD.status
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Нельзя изменять статус завершённой, отменённой или пропущенной записи.';
        END IF;

        RETURN NEW;
    END IF;

    IF NEW.status <> 'scheduled' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Новая запись должна создаваться со статусом scheduled.';
    END IF;

    SELECT
        doctor_id,
        starts_at,
        ends_at,
        cancelled_at
    INTO
        v_doctor_id,
        v_schedule_starts_at,
        v_schedule_ends_at,
        v_schedule_cancelled_at
    FROM public.doctor_schedule
    WHERE schedule_id = NEW.schedule_id
    FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = 'Указанный рабочий интервал не существует.';
    END IF;

    IF v_schedule_cancelled_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Нельзя создать запись в отменённом рабочем интервале.';
    END IF;

    IF NEW.starts_at < v_schedule_starts_at
       OR NEW.ends_at > v_schedule_ends_at
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Время приёма должно полностью находиться внутри рабочего интервала врача.';
    END IF;

    IF MOD(
        EXTRACT(EPOCH FROM (NEW.starts_at - v_schedule_starts_at)),
        900
    ) <> 0 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Начало приёма должно соответствовать 15-минутной сетке от начала рабочего интервала.';
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
                MESSAGE = 'Врач рабочего интервала не существует.';
    END IF;

    IF v_employment_status <> 'active' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Записывать пациентов можно только к действующим врачам.';
    END IF;

    SELECT deleted_at
    INTO v_patient_deleted_at
    FROM public.patients
    WHERE patient_id = NEW.patient_id
    FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = 'Указанный пациент не существует.';
    END IF;

    IF v_patient_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Нельзя создавать записи для логически удалённого пациента.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.appointments a
        JOIN public.doctor_schedule ds
            ON ds.schedule_id = a.schedule_id
        WHERE ds.doctor_id = v_doctor_id
          AND a.status <> 'cancelled'
          AND tstzrange(a.starts_at, a.ends_at, '[)')
              && tstzrange(NEW.starts_at, NEW.ends_at, '[)')
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23P01',
                MESSAGE = 'У врача уже существует другая запись на пересекающееся время.';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_appointments_validate
BEFORE INSERT OR UPDATE OF schedule_id, patient_id, starts_at, ends_at, status
ON public.appointments
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_appointment();

COMMIT;
