CREATE OR REPLACE FUNCTION public.fn_register_payment(
    p_invoice_id BIGINT,
    p_amount NUMERIC(12,2),
    p_payment_method VARCHAR(30),
    p_transaction_number VARCHAR(100) DEFAULT NULL,
    p_note TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_invoice_total NUMERIC(12,2);
    v_paid_amount NUMERIC(12,2);
    v_remaining_amount NUMERIC(12,2);

    v_payment_method VARCHAR(30);
    v_transaction_number VARCHAR(100);

    v_payment_id BIGINT;
BEGIN
    IF p_invoice_id IS NULL THEN
        RAISE EXCEPTION
            USING ERRCODE = '22023',
                  MESSAGE = 'Идентификатор счёта обязателен.';
    END IF;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION
            USING ERRCODE = '22023',
                  MESSAGE = 'Сумма платежа должна быть положительной.';
    END IF;

    v_payment_method := BTRIM(p_payment_method);

    IF v_payment_method IS NULL
       OR v_payment_method NOT IN (
           'cash',
           'bank_card',
           'bank_transfer',
           'online'
       ) THEN
        RAISE EXCEPTION
            USING ERRCODE = '22023',
                  MESSAGE = 'Указан недопустимый способ оплаты.';
    END IF;

    v_transaction_number := NULLIF(BTRIM(p_transaction_number), '');

    SELECT i.total_amount
    INTO v_invoice_total
    FROM public.invoices AS i
    WHERE i.invoice_id = p_invoice_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING ERRCODE = 'P0002',
                  MESSAGE = 'Счёт с указанным идентификатором не найден.';
    END IF;

    SELECT COALESCE(SUM(p.amount), 0)::NUMERIC(12,2)
    INTO v_paid_amount
    FROM public.payments AS p
    WHERE p.invoice_id = p_invoice_id;

    v_remaining_amount := v_invoice_total - v_paid_amount;

    IF v_remaining_amount <= 0 THEN
        RAISE EXCEPTION
            USING ERRCODE = '23514',
                  MESSAGE = 'Счёт уже полностью оплачен.';
    END IF;

    IF p_amount > v_remaining_amount THEN
        RAISE EXCEPTION
            USING ERRCODE = '23514',
                  MESSAGE = 'Сумма платежа превышает остаток по счёту.';
    END IF;

    INSERT INTO public.payments (
        invoice_id,
        amount,
        payment_method,
        transaction_number,
        note
    )
    VALUES (
        p_invoice_id,
        p_amount,
        v_payment_method,
        v_transaction_number,
        p_note
    )
    RETURNING payment_id
    INTO v_payment_id;

    RETURN v_payment_id;
END;
$$;