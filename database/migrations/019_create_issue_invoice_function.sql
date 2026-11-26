CREATE OR REPLACE FUNCTION public.fn_issue_invoice(
    p_visit_id BIGINT,
    p_invoice_number VARCHAR(50),
    p_due_date DATE
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_issued_at TIMESTAMPTZ := clock_timestamp();
    v_invoice_id BIGINT;
BEGIN
    IF p_visit_id IS NULL THEN
        RAISE EXCEPTION
            USING ERRCODE = '22023',
                  MESSAGE = 'Идентификатор визита обязателен.';
    END IF;

    IF p_invoice_number IS NULL OR BTRIM(p_invoice_number) = '' THEN
        RAISE EXCEPTION
            USING ERRCODE = '22023',
                  MESSAGE = 'Номер счёта не может быть пустым.';
    END IF;

    IF p_due_date IS NULL THEN
        RAISE EXCEPTION
            USING ERRCODE = '22023',
                  MESSAGE = 'Дата оплаты обязательна.';
    END IF;

    SELECT a.status
    INTO v_status
    FROM public.visits AS v
    JOIN public.appointments AS a
        ON a.appointment_id = v.appointment_id
    WHERE v.visit_id = p_visit_id
    FOR UPDATE OF v, a;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING ERRCODE = 'P0002',
                  MESSAGE = 'Визит с указанным идентификатором не найден.';
    END IF;

    IF v_status <> 'completed' THEN
        RAISE EXCEPTION
            USING ERRCODE = '23514',
                  MESSAGE = 'Выставить счёт можно только за завершённый приём.';
    END IF;

    IF p_due_date < (v_issued_at AT TIME ZONE 'Europe/Moscow')::DATE THEN
        RAISE EXCEPTION
            USING ERRCODE = '23514',
                  MESSAGE = 'Дата оплаты не может быть раньше даты выставления счёта.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.invoices AS i
        WHERE i.visit_id = p_visit_id
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = '23505',
                  MESSAGE = 'Для этого визита уже существует счёт.';
    END IF;

    INSERT INTO public.invoices (
        visit_id,
        invoice_number,
        issued_at,
        due_date
    )
    VALUES (
        p_visit_id,
        BTRIM(p_invoice_number),
        v_issued_at,
        p_due_date
    )
    RETURNING invoice_id
    INTO v_invoice_id;

    RETURN v_invoice_id;
END;
$$;