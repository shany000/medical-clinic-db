
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_validate_invoice()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_appointment_id BIGINT;
    v_appointment_status VARCHAR(20);
    v_service_count BIGINT;
    v_calculated_total NUMERIC(12, 2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Физическое удаление счетов запрещено.';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF NEW.invoice_id IS DISTINCT FROM OLD.invoice_id
           OR NEW.visit_id IS DISTINCT FROM OLD.visit_id
           OR NEW.invoice_number IS DISTINCT FROM OLD.invoice_number
           OR NEW.issued_at IS DISTINCT FROM OLD.issued_at
           OR NEW.total_amount IS DISTINCT FROM OLD.total_amount
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Нельзя изменять номер, посещение, дату выставления и сумму существующего счёта.';
        END IF;

        IF NEW.due_date IS NULL
           OR NEW.due_date < NEW.issued_at::date
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Срок оплаты не может быть раньше даты выставления счёта.';
        END IF;

        RETURN NEW;
    END IF;

    IF NEW.issued_at IS NULL OR NEW.due_date IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Дата выставления и срок оплаты счёта обязательны.';
    END IF;

    IF NEW.due_date < NEW.issued_at::date THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Срок оплаты не может быть раньше даты выставления счёта.';
    END IF;

    SELECT
        v.appointment_id,
        a.status
    INTO
        v_appointment_id,
        v_appointment_status
    FROM public.visits v
    JOIN public.appointments a
        ON a.appointment_id = v.appointment_id
    WHERE v.visit_id = NEW.visit_id
    FOR SHARE OF v, a;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = 'Посещение для выставления счёта не найдено.';
    END IF;

    IF v_appointment_status <> 'completed' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Выставить счёт можно только за завершённое посещение.';
    END IF;

    SELECT
        COUNT(*),
        COALESCE(SUM(price_at_booking), 0)
    INTO
        v_service_count,
        v_calculated_total
    FROM public.appointment_services
    WHERE appointment_id = v_appointment_id;

    IF v_service_count = 0 OR v_calculated_total <= 0 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Нельзя выставить счёт без медицинских услуг.';
    END IF;

    NEW.total_amount := v_calculated_total;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_invoices_validate
BEFORE INSERT OR UPDATE OR DELETE
ON public.invoices
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_invoice();

COMMIT;
