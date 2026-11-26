CREATE OR REPLACE FUNCTION public.fn_complete_appointment(
    p_appointment_id BIGINT,
    p_complaints TEXT DEFAULT NULL,
    p_anamnesis TEXT DEFAULT NULL,
    p_examination_results TEXT DEFAULT NULL,
    p_conclusion TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_status TEXT;
    v_visit_id BIGINT;
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
                  MESSAGE = 'Завершить можно только запись со статусом scheduled.';
    END IF;

    INSERT INTO public.visits (
        appointment_id,
        complaints,
        anamnesis,
        examination_results,
        conclusion
    )
    VALUES (
        p_appointment_id,
        p_complaints,
        p_anamnesis,
        p_examination_results,
        p_conclusion
    )
    RETURNING visit_id
    INTO v_visit_id;

    UPDATE public.appointments
    SET status = 'completed'
    WHERE appointment_id = p_appointment_id;

    RETURN v_visit_id;
END;
$$;