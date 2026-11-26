
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_validate_doctor_schedule()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_employment_status VARCHAR(20);
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Физическое удаление рабочего интервала запрещено. Используйте логическую отмену.';
    END IF;

    IF TG_OP = 'INSERT' THEN
        SELECT employment_status
        INTO v_employment_status
        FROM public.doctors
        WHERE doctor_id = NEW.doctor_id
        FOR SHARE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE = 'Указанный врач не существует.';
        END IF;

        IF v_employment_status <> 'active' THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Создавать рабочие интервалы можно только для действующих врачей.';
        END IF;

        RETURN NEW;
    END IF;

    IF NEW.doctor_id IS DISTINCT FROM OLD.doctor_id THEN
        IF EXISTS (
            SELECT 1
            FROM public.appointments
            WHERE schedule_id = OLD.schedule_id
        ) THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Нельзя менять врача у рабочего интервала, к которому уже привязаны записи.';
        END IF;
    END IF;

    IF NEW.cancelled_at IS NULL
       AND (
            NEW.doctor_id IS DISTINCT FROM OLD.doctor_id
            OR NEW.starts_at IS DISTINCT FROM OLD.starts_at
            OR NEW.ends_at IS DISTINCT FROM OLD.ends_at
            OR OLD.cancelled_at IS NOT NULL
       )
    THEN
        SELECT employment_status
        INTO v_employment_status
        FROM public.doctors
        WHERE doctor_id = NEW.doctor_id
        FOR SHARE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE = 'Указанный врач не существует.';
        END IF;

        IF v_employment_status <> 'active' THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Создавать и изменять рабочие интервалы можно только для действующих врачей.';
        END IF;
    END IF;

    IF NEW.starts_at IS DISTINCT FROM OLD.starts_at
       OR NEW.ends_at IS DISTINCT FROM OLD.ends_at
    THEN
        IF EXISTS (
            SELECT 1
            FROM public.appointments a
            WHERE a.schedule_id = OLD.schedule_id
              AND (
                    a.starts_at < NEW.starts_at
                    OR a.ends_at > NEW.ends_at
              )
        ) THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Нельзя изменить рабочий интервал так, чтобы связанные записи оказались за его пределами.';
        END IF;
    END IF;

    IF OLD.cancelled_at IS NULL
       AND NEW.cancelled_at IS NOT NULL
    THEN
        IF EXISTS (
            SELECT 1
            FROM public.appointments a
            WHERE a.schedule_id = OLD.schedule_id
              AND a.status = 'scheduled'
        ) THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Перед отменой рабочего интервала необходимо отменить или перенести все записи со статусом scheduled.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_doctor_schedule_validate
BEFORE INSERT OR UPDATE OR DELETE
ON public.doctor_schedule
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_doctor_schedule();

COMMIT;
