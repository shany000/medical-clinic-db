CREATE OR REPLACE FUNCTION public.fn_cancel_appointment(
    p_appointment_id BIGINT,
    p_cancellation_reason TEXT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_status TEXT;
    v_cancelled_appointment_id BIGINT;
BEGIN
    IF p_appointment_id IS NULL THEN
        RAISE EXCEPTION
            USING ERRCODE = '22023',
                  MESSAGE = 'Идентификатор записи обязателен.';
    END IF;

    IF p_cancellation_reason IS NULL OR BTRIM(p_cancellation_reason) = '' THEN
        RAISE EXCEPTION
            USING ERRCODE = '22023',
                  MESSAGE = 'Причина отмены не может быть пустой.';
    END IF;

    SELECT a.status
    INTO v_status
    FROM public.appointments AS a
    WHERE a.appointment_id = p_appointment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING ERRCODE = 'P0002',
                  MESSAGE = 'Запись с указанным идентификатором не найдена.';
    END IF;

    IF v_status <> 'scheduled' THEN
        RAISE EXCEPTION
            USING ERRCODE = '23514',
                  MESSAGE = 'Отменить можно только запись со статусом scheduled.';
    END IF;

    UPDATE public.appointments AS a
    SET
        status = 'cancelled',
        cancellation_reason = BTRIM(p_cancellation_reason),
        cancelled_at = clock_timestamp()
    WHERE a.appointment_id = p_appointment_id
    RETURNING a.appointment_id
    INTO v_cancelled_appointment_id;

    RETURN v_cancelled_appointment_id;
END;
$$;