
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_handle_doctor_dismissal()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_action_time TIMESTAMPTZ;
BEGIN
    IF OLD.employment_status IS DISTINCT FROM 'dismissed'
       AND NEW.employment_status = 'dismissed'
    THEN
        v_action_time := CURRENT_TIMESTAMP;

        UPDATE public.appointments a
        SET
            status = 'cancelled',
            cancelled_at = v_action_time,
            cancellation_reason = 'Отмена в связи с увольнением врача'
        FROM public.doctor_schedule ds
        WHERE ds.schedule_id = a.schedule_id
          AND ds.doctor_id = NEW.doctor_id
          AND a.status = 'scheduled'
          AND a.starts_at >= v_action_time;

        UPDATE public.doctor_schedule
        SET
            cancelled_at = v_action_time,
            cancellation_reason = 'Отмена в связи с увольнением врача'
        WHERE doctor_id = NEW.doctor_id
          AND starts_at >= v_action_time
          AND cancelled_at IS NULL;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_doctors_handle_dismissal
AFTER UPDATE OF employment_status
ON public.doctors
FOR EACH ROW
EXECUTE FUNCTION public.fn_handle_doctor_dismissal();

COMMIT;
