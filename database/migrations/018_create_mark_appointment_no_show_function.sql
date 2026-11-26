CREATE OR REPLACE FUNCTION public.fn_mark_appointment_no_show(
    p_appointment_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_status TEXT;
    v_no_show_appointment_id BIGINT;
BEGIN
    IF p_appointment_id IS NULL THEN
        RAISE EXCEPTION
            USING ERRCODE = '22023',
                  MESSAGE = 'Идентификатор записи обязателен.';
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
                  MESSAGE = 'Отметить неявку можно только для записи со статусом scheduled.';
    END IF;

    UPDATE public.appointments AS a
    SET status = 'no_show'
    WHERE a.appointment_id = p_appointment_id
    RETURNING a.appointment_id
    INTO v_no_show_appointment_id;

    RETURN v_no_show_appointment_id;
END;
$$;