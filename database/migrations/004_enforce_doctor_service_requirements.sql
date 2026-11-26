
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_assert_active_doctor_has_service(
    p_doctor_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_employment_status VARCHAR(20);
BEGIN
    SELECT employment_status
    INTO v_employment_status
    FROM public.doctors
    WHERE doctor_id = p_doctor_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF v_employment_status <> 'active' THEN
        RETURN;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.doctor_services ds
        JOIN public.services s
            ON s.service_id = ds.service_id
        WHERE ds.doctor_id = p_doctor_id
          AND ds.is_active = TRUE
          AND s.is_active = TRUE
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'У каждого действующего врача должна быть хотя бы одна активная услуга клиники.';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_validate_doctor_service_link()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_service_is_active BOOLEAN;
BEGIN
    IF NEW.is_active = TRUE THEN
        SELECT is_active
        INTO v_service_is_active
        FROM public.services
        WHERE service_id = NEW.service_id
        FOR SHARE;

        IF NOT FOUND OR v_service_is_active IS DISTINCT FROM TRUE THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Нельзя активировать связь врача с неактивной услугой.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_doctor_services_validate_active_link
BEFORE INSERT OR UPDATE
ON public.doctor_services
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_doctor_service_link();

CREATE OR REPLACE FUNCTION public.fn_check_active_doctor_service_requirement()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_doctor_id BIGINT;
BEGIN
    IF TG_TABLE_NAME = 'doctors' THEN

        PERFORM public.fn_assert_active_doctor_has_service(
            NEW.doctor_id
        );

    ELSIF TG_TABLE_NAME = 'doctor_services' THEN

        IF TG_OP IN ('UPDATE', 'DELETE') THEN
            PERFORM public.fn_assert_active_doctor_has_service(
                OLD.doctor_id
            );
        END IF;

        IF TG_OP IN ('INSERT', 'UPDATE') THEN
            PERFORM public.fn_assert_active_doctor_has_service(
                NEW.doctor_id
            );
        END IF;

    ELSIF TG_TABLE_NAME = 'services' THEN

        FOR v_doctor_id IN
            SELECT DISTINCT ds.doctor_id
            FROM public.doctor_services ds
            WHERE ds.service_id = NEW.service_id
              AND ds.is_active = TRUE
        LOOP
            PERFORM public.fn_assert_active_doctor_has_service(
                v_doctor_id
            );
        END LOOP;

    END IF;

    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_doctors_require_active_service
AFTER INSERT OR UPDATE
ON public.doctors
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.fn_check_active_doctor_service_requirement();

CREATE CONSTRAINT TRIGGER trg_doctor_services_require_active_service
AFTER INSERT OR UPDATE OR DELETE
ON public.doctor_services
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.fn_check_active_doctor_service_requirement();

CREATE CONSTRAINT TRIGGER trg_services_preserve_active_doctor_service
AFTER UPDATE
ON public.services
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active)
EXECUTE FUNCTION public.fn_check_active_doctor_service_requirement();

COMMIT;
