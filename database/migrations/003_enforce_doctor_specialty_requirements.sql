
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_assert_active_doctor_has_specialty(
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
        FROM public.doctor_specialties ds
        JOIN public.specialties s
            ON s.specialty_id = ds.specialty_id
        WHERE ds.doctor_id = p_doctor_id
          AND ds.is_active = TRUE
          AND s.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'У каждого действующего врача должна быть хотя бы одна активная специальность.';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_validate_doctor_specialty_link()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_active = TRUE THEN
        PERFORM 1
        FROM public.specialties
        WHERE specialty_id = NEW.specialty_id
          AND deleted_at IS NULL;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = 'Нельзя активировать связь с удалённой специальностью.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_doctor_specialties_validate_active_link
BEFORE INSERT OR UPDATE
ON public.doctor_specialties
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_doctor_specialty_link();

CREATE OR REPLACE FUNCTION public.fn_check_active_doctor_specialty_requirement()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_doctor_id BIGINT;
BEGIN
    IF TG_TABLE_NAME = 'doctors' THEN

        PERFORM public.fn_assert_active_doctor_has_specialty(
            NEW.doctor_id
        );

    ELSIF TG_TABLE_NAME = 'doctor_specialties' THEN

        IF TG_OP IN ('UPDATE', 'DELETE') THEN
            PERFORM public.fn_assert_active_doctor_has_specialty(
                OLD.doctor_id
            );
        END IF;

        IF TG_OP IN ('INSERT', 'UPDATE') THEN
            PERFORM public.fn_assert_active_doctor_has_specialty(
                NEW.doctor_id
            );
        END IF;

    ELSIF TG_TABLE_NAME = 'specialties' THEN

        FOR v_doctor_id IN
            SELECT DISTINCT ds.doctor_id
            FROM public.doctor_specialties ds
            WHERE ds.specialty_id = NEW.specialty_id
        LOOP
            PERFORM public.fn_assert_active_doctor_has_specialty(
                v_doctor_id
            );
        END LOOP;

    END IF;

    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_doctors_require_active_specialty
AFTER INSERT OR UPDATE
ON public.doctors
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.fn_check_active_doctor_specialty_requirement();

CREATE CONSTRAINT TRIGGER trg_doctor_specialties_require_active_specialty
AFTER INSERT OR UPDATE OR DELETE
ON public.doctor_specialties
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.fn_check_active_doctor_specialty_requirement();

CREATE CONSTRAINT TRIGGER trg_specialties_preserve_active_doctor_specialty
AFTER UPDATE
ON public.specialties
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
WHEN (OLD.deleted_at IS DISTINCT FROM NEW.deleted_at)
EXECUTE FUNCTION public.fn_check_active_doctor_specialty_requirement();

COMMIT;
