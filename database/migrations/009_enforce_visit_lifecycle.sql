
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_validate_visit_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_appointment_status VARCHAR(20);
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Физическое удаление посещений запрещено.';
    END IF;

    IF TG_OP = 'INSERT' THEN
        SELECT status
        INTO v_appointment_status
        FROM public.appointments
        WHERE appointment_id = NEW.appointment_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE = 'Запись на приём для посещения не найдена.';
        END IF;

        IF v_appointment_status <> 'scheduled' THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Создать посещение можно только для записи со статусом scheduled.';
        END IF;

        RETURN NEW;
    END IF;

    IF NEW.visit_id IS DISTINCT FROM OLD.visit_id
       OR NEW.appointment_id IS DISTINCT FROM OLD.appointment_id
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Идентификаторы и дата создания посещения не могут быть изменены.';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_visits_lifecycle_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.visits
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_visit_lifecycle();


CREATE OR REPLACE FUNCTION public.fn_assert_appointment_visit_consistency(
    p_appointment_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_visit_count BIGINT;
BEGIN
    SELECT status
    INTO v_status
    FROM public.appointments
    WHERE appointment_id = p_appointment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT COUNT(*)
    INTO v_visit_count
    FROM public.visits
    WHERE appointment_id = p_appointment_id;

    IF v_status = 'completed' AND v_visit_count <> 1 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Завершённая запись должна иметь ровно одно посещение.';
    END IF;

    IF v_status <> 'completed' AND v_visit_count <> 0 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Запись, не имеющая статус completed, не может содержать посещение.';
    END IF;
END;
$$;


CREATE OR REPLACE FUNCTION public.fn_check_appointment_visit_consistency()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM public.fn_assert_appointment_visit_consistency(
        NEW.appointment_id
    );

    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_appointments_visit_consistency
AFTER INSERT OR UPDATE OF status
ON public.appointments
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.fn_check_appointment_visit_consistency();

CREATE CONSTRAINT TRIGGER trg_visits_appointment_consistency
AFTER INSERT OR UPDATE
ON public.visits
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.fn_check_appointment_visit_consistency();

COMMIT;
