
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_validate_payment_record()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_invoice_total NUMERIC(12, 2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Физическое удаление платежей запрещено.';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF NEW.payment_id IS DISTINCT FROM OLD.payment_id
           OR NEW.invoice_id IS DISTINCT FROM OLD.invoice_id
           OR NEW.paid_at IS DISTINCT FROM OLD.paid_at
           OR NEW.amount IS DISTINCT FROM OLD.amount
           OR NEW.payment_method IS DISTINCT FROM OLD.payment_method
           OR NEW.transaction_number IS DISTINCT FROM OLD.transaction_number
        THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Финансовые данные зарегистрированного платежа нельзя изменять.';
        END IF;

        RETURN NEW;
    END IF;

    SELECT total_amount
    INTO v_invoice_total
    FROM public.invoices
    WHERE invoice_id = NEW.invoice_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = 'Счёт для регистрации платежа не найден.';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_payments_validate_record
BEFORE INSERT OR UPDATE OR DELETE
ON public.payments
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_payment_record();


CREATE OR REPLACE FUNCTION public.fn_assert_invoice_payment_limit(
    p_invoice_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_invoice_total NUMERIC(12, 2);
    v_paid_total NUMERIC(12, 2);
BEGIN
    SELECT total_amount
    INTO v_invoice_total
    FROM public.invoices
    WHERE invoice_id = p_invoice_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT COALESCE(SUM(amount), 0)
    INTO v_paid_total
    FROM public.payments
    WHERE invoice_id = p_invoice_id;

    IF v_paid_total > v_invoice_total THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Сумма платежей не может превышать сумму счёта.';
    END IF;
END;
$$;


CREATE OR REPLACE FUNCTION public.fn_check_invoice_payment_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM public.fn_assert_invoice_payment_limit(
        NEW.invoice_id
    );

    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_payments_enforce_invoice_limit
AFTER INSERT
ON public.payments
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.fn_check_invoice_payment_limit();

COMMIT;
