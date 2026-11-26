
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_validate_appointment_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Физическое удаление записей на приём запрещено.';
    END IF;

    IF NEW.appointment_id IS DISTINCT FROM OLD.appointment_id THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Идентификатор записи на приём нельзя изменять.';
    END IF;

    IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Дата создания записи не может быть изменена.';
    END IF;

    IF OLD.status <> 'scheduled' THEN

        IF NEW.schedule_id IS DISTINCT FROM OLD.schedule_id
           OR NEW.patient_id IS DISTINCT FROM OLD.patient_id
           OR NEW.starts_at IS DISTINCT FROM OLD.starts_at
           OR NEW.ends_at IS DISTINCT FROM OLD.ends_at
           OR NEW.status IS DISTINCT FROM OLD.status
           OR NEW.cancellation_reason IS DISTINCT FROM OLD.cancellation_reason
           OR NEW.cancelled_at IS DISTINCT FROM OLD.cancelled_at
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Завершённую, отменённую или пропущенную запись нельзя изменять.';
        END IF;

        RETURN NEW;
    END IF;

    IF NEW.status IS DISTINCT FROM OLD.status
       AND NEW.status NOT IN ('completed', 'cancelled', 'no_show')
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Недопустимый переход статуса записи на приём.';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_appointments_lifecycle_guard
BEFORE UPDATE OR DELETE
ON public.appointments
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_appointment_lifecycle();

COMMIT;
