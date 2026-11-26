BEGIN;

CREATE OR REPLACE FUNCTION public.fn_validate_patient_birth_date()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.birth_date > CURRENT_DATE THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = 'Дата рождения пациента не может быть в будущем.';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_patients_validate_birth_date
BEFORE INSERT OR UPDATE OF birth_date
ON public.patients
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_patient_birth_date();

COMMIT;
