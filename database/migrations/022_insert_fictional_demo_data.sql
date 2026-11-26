BEGIN;

DO $$
DECLARE
    v_today DATE;
    v_d1_date DATE;
    v_d2_date DATE;
    v_d3_date DATE;
    v_d4_date DATE;
    v_future_date DATE;

    v_patient_1 BIGINT;
    v_patient_2 BIGINT;
    v_patient_3 BIGINT;
    v_patient_4 BIGINT;
    v_patient_5 BIGINT;
    v_patient_6 BIGINT;
    v_patient_7 BIGINT;
    v_patient_8 BIGINT;

    v_doctor_1 BIGINT;
    v_doctor_2 BIGINT;
    v_doctor_3 BIGINT;
    v_doctor_4 BIGINT;

    v_specialty_therapy BIGINT;
    v_specialty_cardiology BIGINT;
    v_specialty_neurology BIGINT;
    v_specialty_dermatology BIGINT;
    v_specialty_endocrinology BIGINT;
    v_specialty_ophthalmology BIGINT;
    v_specialty_pediatrics BIGINT;

    v_service_primary BIGINT;
    v_service_repeat BIGINT;
    v_service_cardiology BIGINT;
    v_service_ecg BIGINT;
    v_service_pressure BIGINT;
    v_service_neurology BIGINT;
    v_service_dermatology BIGINT;
    v_service_endocrinology BIGINT;
    v_service_ophthalmology BIGINT;
    v_service_pediatrics BIGINT;
    v_service_glucose BIGINT;

    v_diagnosis_hypertension BIGINT;
    v_diagnosis_ischemic BIGINT;
    v_diagnosis_arrhythmia BIGINT;
    v_diagnosis_migraine BIGINT;
    v_diagnosis_dermatitis BIGINT;
    v_diagnosis_myopia BIGINT;
    v_diagnosis_arvi BIGINT;

    v_d1_schedule_start TIMESTAMPTZ;
    v_d1_schedule_end TIMESTAMPTZ;
    v_d2_schedule_start TIMESTAMPTZ;
    v_d2_schedule_end TIMESTAMPTZ;
    v_d3_schedule_start TIMESTAMPTZ;
    v_d3_schedule_end TIMESTAMPTZ;
    v_d4_schedule_start TIMESTAMPTZ;
    v_d4_schedule_end TIMESTAMPTZ;
    v_future_schedule_start TIMESTAMPTZ;
    v_future_schedule_end TIMESTAMPTZ;

    v_d1_schedule_id BIGINT;
    v_d2_schedule_id BIGINT;
    v_d3_schedule_id BIGINT;
    v_d4_schedule_id BIGINT;
    v_future_schedule_id BIGINT;

    v_appointment_1 BIGINT;
    v_appointment_2 BIGINT;
    v_appointment_3 BIGINT;
    v_appointment_4 BIGINT;
    v_appointment_5 BIGINT;
    v_appointment_6 BIGINT;
    v_appointment_7 BIGINT;
    v_appointment_8 BIGINT;

    v_future_appointment_1 BIGINT;
    v_future_appointment_2 BIGINT;
    v_future_appointment_3 BIGINT;
    v_future_appointment_4 BIGINT;

    v_visit_1 BIGINT;
    v_visit_2 BIGINT;
    v_visit_3 BIGINT;
    v_visit_4 BIGINT;
    v_visit_5 BIGINT;
    v_visit_6 BIGINT;
    v_visit_7 BIGINT;

    v_invoice_paid BIGINT;
    v_invoice_partial BIGINT;
    v_invoice_unpaid BIGINT;
    v_invoice_overdue BIGINT;
BEGIN
    v_today := (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Moscow')::DATE;
    v_d1_date := v_today - 10;
    v_d2_date := v_today - 9;
    v_d3_date := v_today - 8;
    v_d4_date := v_today - 7;
    v_future_date := v_today + 7;

    SELECT specialty_id INTO v_specialty_therapy
    FROM public.specialties
    WHERE name = 'Терапия' AND deleted_at IS NULL;

    SELECT specialty_id INTO v_specialty_cardiology
    FROM public.specialties
    WHERE name = 'Кардиология' AND deleted_at IS NULL;

    SELECT specialty_id INTO v_specialty_neurology
    FROM public.specialties
    WHERE name = 'Неврология' AND deleted_at IS NULL;

    SELECT specialty_id INTO v_specialty_dermatology
    FROM public.specialties
    WHERE name = 'Дерматология' AND deleted_at IS NULL;

    SELECT specialty_id INTO v_specialty_endocrinology
    FROM public.specialties
    WHERE name = 'Эндокринология' AND deleted_at IS NULL;

    SELECT specialty_id INTO v_specialty_ophthalmology
    FROM public.specialties
    WHERE name = 'Офтальмология' AND deleted_at IS NULL;

    SELECT specialty_id INTO v_specialty_pediatrics
    FROM public.specialties
    WHERE name = 'Педиатрия' AND deleted_at IS NULL;

    SELECT service_id INTO v_service_primary
    FROM public.services
    WHERE name = 'Первичная консультация терапевта' AND is_active;

    SELECT service_id INTO v_service_repeat
    FROM public.services
    WHERE name = 'Повторная консультация терапевта' AND is_active;

    SELECT service_id INTO v_service_cardiology
    FROM public.services
    WHERE name = 'Консультация кардиолога' AND is_active;

    SELECT service_id INTO v_service_ecg
    FROM public.services
    WHERE name = 'Электрокардиография (ЭКГ)' AND is_active;

    SELECT service_id INTO v_service_pressure
    FROM public.services
    WHERE name = 'Измерение артериального давления' AND is_active;

    SELECT service_id INTO v_service_neurology
    FROM public.services
    WHERE name = 'Консультация невролога' AND is_active;

    SELECT service_id INTO v_service_dermatology
    FROM public.services
    WHERE name = 'Консультация дерматолога' AND is_active;

    SELECT service_id INTO v_service_endocrinology
    FROM public.services
    WHERE name = 'Консультация эндокринолога' AND is_active;

    SELECT service_id INTO v_service_ophthalmology
    FROM public.services
    WHERE name = 'Консультация офтальмолога' AND is_active;

    SELECT service_id INTO v_service_pediatrics
    FROM public.services
    WHERE name = 'Консультация педиатра' AND is_active;

    SELECT service_id INTO v_service_glucose
    FROM public.services
    WHERE name = 'Измерение уровня глюкозы крови' AND is_active;

    SELECT diagnosis_id INTO v_diagnosis_hypertension
    FROM public.diagnoses
    WHERE name = 'Артериальная гипертензия' AND deleted_at IS NULL;

    SELECT diagnosis_id INTO v_diagnosis_ischemic
    FROM public.diagnoses
    WHERE name = 'Ишемическая болезнь сердца' AND deleted_at IS NULL;

    SELECT diagnosis_id INTO v_diagnosis_arrhythmia
    FROM public.diagnoses
    WHERE name = 'Нарушение сердечного ритма' AND deleted_at IS NULL;

    SELECT diagnosis_id INTO v_diagnosis_migraine
    FROM public.diagnoses
    WHERE name = 'Мигрень' AND deleted_at IS NULL;

    SELECT diagnosis_id INTO v_diagnosis_dermatitis
    FROM public.diagnoses
    WHERE name = 'Атопический дерматит' AND deleted_at IS NULL;

    SELECT diagnosis_id INTO v_diagnosis_myopia
    FROM public.diagnoses
    WHERE name = 'Миопия' AND deleted_at IS NULL;

    SELECT diagnosis_id INTO v_diagnosis_arvi
    FROM public.diagnoses
    WHERE name = 'Острая респираторная вирусная инфекция' AND deleted_at IS NULL;

    IF v_specialty_therapy IS NULL
       OR v_specialty_cardiology IS NULL
       OR v_specialty_neurology IS NULL
       OR v_specialty_dermatology IS NULL
       OR v_specialty_endocrinology IS NULL
       OR v_specialty_ophthalmology IS NULL
       OR v_specialty_pediatrics IS NULL
       OR v_service_primary IS NULL
       OR v_service_repeat IS NULL
       OR v_service_cardiology IS NULL
       OR v_service_ecg IS NULL
       OR v_service_pressure IS NULL
       OR v_service_neurology IS NULL
       OR v_service_dermatology IS NULL
       OR v_service_endocrinology IS NULL
       OR v_service_ophthalmology IS NULL
       OR v_service_pediatrics IS NULL
       OR v_service_glucose IS NULL
       OR v_diagnosis_hypertension IS NULL
       OR v_diagnosis_ischemic IS NULL
       OR v_diagnosis_arrhythmia IS NULL
       OR v_diagnosis_migraine IS NULL
       OR v_diagnosis_dermatitis IS NULL
       OR v_diagnosis_myopia IS NULL
       OR v_diagnosis_arvi IS NULL THEN
        RAISE EXCEPTION 'Не найдены необходимые активные справочные записи для демонстрационных данных.';
    END IF;

    INSERT INTO public.patients (
        last_name,
        first_name,
        middle_name,
        birth_date,
        gender,
        phone,
        email,
        address
    )
    VALUES (
        'Иванова', 'Мария', 'Андреевна', DATE '1988-03-14', 'female', '79991110001', 'demo.patient01@example.test', 'г. Москва'
    )
    RETURNING patient_id INTO v_patient_1;

    INSERT INTO public.patients (
        last_name,
        first_name,
        middle_name,
        birth_date,
        gender,
        phone,
        email,
        address
    )
    VALUES (
        'Петров', 'Сергей', 'Иванович', DATE '1975-07-22', 'male', '79991110002', 'demo.patient02@example.test', 'г. Москва'
    )
    RETURNING patient_id INTO v_patient_2;

    INSERT INTO public.patients (
        last_name,
        first_name,
        middle_name,
        birth_date,
        gender,
        phone,
        email,
        address
    )
    VALUES (
        'Сидорова', 'Анна', 'Павловна', DATE '1994-11-03', 'female', '79991110003', 'demo.patient03@example.test', 'г. Москва'
    )
    RETURNING patient_id INTO v_patient_3;

    INSERT INTO public.patients (
        last_name,
        first_name,
        middle_name,
        birth_date,
        gender,
        phone,
        email,
        address
    )
    VALUES (
        'Кузнецов', 'Дмитрий', 'Олегович', DATE '1968-01-17', 'male', '79991110004', 'demo.patient04@example.test', 'г. Москва'
    )
    RETURNING patient_id INTO v_patient_4;

    INSERT INTO public.patients (
        last_name,
        first_name,
        middle_name,
        birth_date,
        gender,
        phone,
        email,
        address
    )
    VALUES (
        'Волкова', 'Елена', 'Сергеевна', DATE '2001-09-28', 'female', '79991110005', 'demo.patient05@example.test', 'г. Москва'
    )
    RETURNING patient_id INTO v_patient_5;

    INSERT INTO public.patients (
        last_name,
        first_name,
        middle_name,
        birth_date,
        gender,
        phone,
        email,
        address
    )
    VALUES (
        'Орлов', 'Михаил', 'Андреевич', DATE '1980-06-11', 'male', '79991110006', 'demo.patient06@example.test', 'г. Москва'
    )
    RETURNING patient_id INTO v_patient_6;

    INSERT INTO public.patients (
        last_name,
        first_name,
        middle_name,
        birth_date,
        gender,
        phone,
        email,
        address
    )
    VALUES (
        'Морозова', 'Алина', 'Игоревна', DATE '2012-05-14', 'female', '79991110007', 'demo.patient07@example.test', 'г. Москва'
    )
    RETURNING patient_id INTO v_patient_7;

    INSERT INTO public.patients (
        last_name,
        first_name,
        middle_name,
        birth_date,
        gender,
        phone,
        email,
        address
    )
    VALUES (
        'Фёдоров', 'Павел', 'Николаевич', DATE '1990-12-09', 'male', '79991110008', 'demo.patient08@example.test', 'г. Москва'
    )
    RETURNING patient_id INTO v_patient_8;

    INSERT INTO public.doctors (
        last_name,
        first_name,
        middle_name,
        phone,
        email,
        hire_date,
        employment_status
    )
    VALUES (
        'Иванов', 'Алексей', 'Андреевич', '79992220001', 'demo.doctor01@example.test', v_today - 1200, 'on_leave'
    )
    RETURNING doctor_id INTO v_doctor_1;

    INSERT INTO public.doctors (
        last_name,
        first_name,
        middle_name,
        phone,
        email,
        hire_date,
        employment_status
    )
    VALUES (
        'Петрова', 'Елена', 'Сергеевна', '79992220002', 'demo.doctor02@example.test', v_today - 900, 'on_leave'
    )
    RETURNING doctor_id INTO v_doctor_2;

    INSERT INTO public.doctors (
        last_name,
        first_name,
        middle_name,
        phone,
        email,
        hire_date,
        employment_status
    )
    VALUES (
        'Смирнова', 'Ольга', 'Викторовна', '79992220003', 'demo.doctor03@example.test', v_today - 800, 'on_leave'
    )
    RETURNING doctor_id INTO v_doctor_3;

    INSERT INTO public.doctors (
        last_name,
        first_name,
        middle_name,
        phone,
        email,
        hire_date,
        employment_status
    )
    VALUES (
        'Соколов', 'Дмитрий', 'Павлович', '79992220004', 'demo.doctor04@example.test', v_today - 700, 'on_leave'
    )
    RETURNING doctor_id INTO v_doctor_4;

    INSERT INTO public.doctor_specialties (doctor_id, specialty_id, is_active)
    VALUES
        (v_doctor_1, v_specialty_therapy, TRUE),
        (v_doctor_1, v_specialty_cardiology, TRUE),
        (v_doctor_2, v_specialty_neurology, TRUE),
        (v_doctor_3, v_specialty_dermatology, TRUE),
        (v_doctor_3, v_specialty_endocrinology, TRUE),
        (v_doctor_4, v_specialty_ophthalmology, TRUE),
        (v_doctor_4, v_specialty_pediatrics, TRUE);

    INSERT INTO public.doctor_services (doctor_id, service_id, is_active)
    VALUES
        (v_doctor_1, v_service_primary, TRUE),
        (v_doctor_1, v_service_repeat, TRUE),
        (v_doctor_1, v_service_cardiology, TRUE),
        (v_doctor_1, v_service_ecg, TRUE),
        (v_doctor_1, v_service_pressure, TRUE),
        (v_doctor_2, v_service_neurology, TRUE),
        (v_doctor_3, v_service_dermatology, TRUE),
        (v_doctor_3, v_service_endocrinology, TRUE),
        (v_doctor_3, v_service_glucose, TRUE),
        (v_doctor_4, v_service_ophthalmology, TRUE),
        (v_doctor_4, v_service_pediatrics, TRUE);

    UPDATE public.doctors
    SET employment_status = 'active'
    WHERE doctor_id IN (
        v_doctor_1,
        v_doctor_2,
        v_doctor_3,
        v_doctor_4
    );

    v_d1_schedule_start := (v_d1_date + TIME '09:00') AT TIME ZONE 'Europe/Moscow';
    v_d1_schedule_end := v_d1_schedule_start + INTERVAL '4 hours';
    v_d2_schedule_start := (v_d2_date + TIME '09:00') AT TIME ZONE 'Europe/Moscow';
    v_d2_schedule_end := v_d2_schedule_start + INTERVAL '3 hours';
    v_d3_schedule_start := (v_d3_date + TIME '09:00') AT TIME ZONE 'Europe/Moscow';
    v_d3_schedule_end := v_d3_schedule_start + INTERVAL '3 hours';
    v_d4_schedule_start := (v_d4_date + TIME '09:00') AT TIME ZONE 'Europe/Moscow';
    v_d4_schedule_end := v_d4_schedule_start + INTERVAL '3 hours';
    v_future_schedule_start := (v_future_date + TIME '09:00') AT TIME ZONE 'Europe/Moscow';
    v_future_schedule_end := v_future_schedule_start + INTERVAL '4 hours';

    INSERT INTO public.doctor_schedule (doctor_id, starts_at, ends_at, note)
    VALUES (v_doctor_1, v_d1_schedule_start, v_d1_schedule_end, 'Демонстрационный исторический график терапевта и кардиолога')
    RETURNING schedule_id INTO v_d1_schedule_id;

    INSERT INTO public.doctor_schedule (doctor_id, starts_at, ends_at, note)
    VALUES (v_doctor_2, v_d2_schedule_start, v_d2_schedule_end, 'Демонстрационный исторический график невролога')
    RETURNING schedule_id INTO v_d2_schedule_id;

    INSERT INTO public.doctor_schedule (doctor_id, starts_at, ends_at, note)
    VALUES (v_doctor_3, v_d3_schedule_start, v_d3_schedule_end, 'Демонстрационный исторический график дерматолога и эндокринолога')
    RETURNING schedule_id INTO v_d3_schedule_id;

    INSERT INTO public.doctor_schedule (doctor_id, starts_at, ends_at, note)
    VALUES (v_doctor_4, v_d4_schedule_start, v_d4_schedule_end, 'Демонстрационный исторический график офтальмолога и педиатра')
    RETURNING schedule_id INTO v_d4_schedule_id;

    INSERT INTO public.doctor_schedule (doctor_id, starts_at, ends_at, note)
    VALUES (v_doctor_1, v_future_schedule_start, v_future_schedule_end, 'Демонстрационный будущий график')
    RETURNING schedule_id INTO v_future_schedule_id;

    INSERT INTO public.appointments (schedule_id, patient_id, starts_at, ends_at)
    VALUES (v_d1_schedule_id, v_patient_1, v_d1_schedule_start, v_d1_schedule_start + INTERVAL '30 minutes')
    RETURNING appointment_id INTO v_appointment_1;

    INSERT INTO public.appointments (schedule_id, patient_id, starts_at, ends_at)
    VALUES (v_d1_schedule_id, v_patient_2, v_d1_schedule_start + INTERVAL '45 minutes', v_d1_schedule_start + INTERVAL '75 minutes')
    RETURNING appointment_id INTO v_appointment_2;

    INSERT INTO public.appointments (schedule_id, patient_id, starts_at, ends_at)
    VALUES (v_d1_schedule_id, v_patient_6, v_d1_schedule_start + INTERVAL '2 hours', v_d1_schedule_start + INTERVAL '2 hours 25 minutes')
    RETURNING appointment_id INTO v_appointment_3;

    INSERT INTO public.appointments (schedule_id, patient_id, starts_at, ends_at)
    VALUES (v_d2_schedule_id, v_patient_3, v_d2_schedule_start, v_d2_schedule_start + INTERVAL '30 minutes')
    RETURNING appointment_id INTO v_appointment_4;

    INSERT INTO public.appointments (schedule_id, patient_id, starts_at, ends_at)
    VALUES (v_d3_schedule_id, v_patient_4, v_d3_schedule_start, v_d3_schedule_start + INTERVAL '30 minutes')
    RETURNING appointment_id INTO v_appointment_5;

    INSERT INTO public.appointments (schedule_id, patient_id, starts_at, ends_at)
    VALUES (v_d4_schedule_id, v_patient_5, v_d4_schedule_start, v_d4_schedule_start + INTERVAL '30 minutes')
    RETURNING appointment_id INTO v_appointment_6;

    INSERT INTO public.appointments (schedule_id, patient_id, starts_at, ends_at)
    VALUES (v_d4_schedule_id, v_patient_7, v_d4_schedule_start + INTERVAL '1 hour', v_d4_schedule_start + INTERVAL '1 hour 30 minutes')
    RETURNING appointment_id INTO v_appointment_7;

    INSERT INTO public.appointments (schedule_id, patient_id, starts_at, ends_at)
    VALUES (v_d1_schedule_id, v_patient_8, v_d1_schedule_start + INTERVAL '3 hours', v_d1_schedule_start + INTERVAL '3 hours 30 minutes')
    RETURNING appointment_id INTO v_appointment_8;

    INSERT INTO public.appointment_services (
        appointment_id,
        service_id,
        duration_minutes_at_booking,
        price_at_booking
    )
    SELECT v_appointment_1, s.service_id, s.duration_minutes, s.price
    FROM public.services AS s
    WHERE s.service_id = v_service_primary;

    INSERT INTO public.appointment_services (
        appointment_id,
        service_id,
        duration_minutes_at_booking,
        price_at_booking
    )
    SELECT v_appointment_2, s.service_id, s.duration_minutes, s.price
    FROM public.services AS s
    WHERE s.service_id = v_service_cardiology;

    INSERT INTO public.appointment_services (
        appointment_id,
        service_id,
        duration_minutes_at_booking,
        price_at_booking
    )
    SELECT v_appointment_3, s.service_id, s.duration_minutes, s.price
    FROM public.services AS s
    WHERE s.service_id IN (v_service_ecg, v_service_pressure);

    INSERT INTO public.appointment_services (
        appointment_id,
        service_id,
        duration_minutes_at_booking,
        price_at_booking
    )
    SELECT v_appointment_4, s.service_id, s.duration_minutes, s.price
    FROM public.services AS s
    WHERE s.service_id = v_service_neurology;

    INSERT INTO public.appointment_services (
        appointment_id,
        service_id,
        duration_minutes_at_booking,
        price_at_booking
    )
    SELECT v_appointment_5, s.service_id, s.duration_minutes, s.price
    FROM public.services AS s
    WHERE s.service_id = v_service_dermatology;

    INSERT INTO public.appointment_services (
        appointment_id,
        service_id,
        duration_minutes_at_booking,
        price_at_booking
    )
    SELECT v_appointment_6, s.service_id, s.duration_minutes, s.price
    FROM public.services AS s
    WHERE s.service_id = v_service_ophthalmology;

    INSERT INTO public.appointment_services (
        appointment_id,
        service_id,
        duration_minutes_at_booking,
        price_at_booking
    )
    SELECT v_appointment_7, s.service_id, s.duration_minutes, s.price
    FROM public.services AS s
    WHERE s.service_id = v_service_pediatrics;

    INSERT INTO public.appointment_services (
        appointment_id,
        service_id,
        duration_minutes_at_booking,
        price_at_booking
    )
    SELECT v_appointment_8, s.service_id, s.duration_minutes, s.price
    FROM public.services AS s
    WHERE s.service_id = v_service_primary;

    v_visit_1 := public.fn_complete_appointment(
        v_appointment_1,
        'Периодическое повышение артериального давления.',
        'Обращение в рамках планового наблюдения.',
        'Выполнен общий осмотр, показатели внесены в карту.',
        'Рекомендовано дальнейшее наблюдение.'
    );

    v_visit_2 := public.fn_complete_appointment(
        v_appointment_2,
        'Жалобы на периодическое ощущение перебоев в работе сердца.',
        'Симптомы отмечаются в течение нескольких недель.',
        'Проведён осмотр кардиолога.',
        'Назначено дальнейшее обследование.'
    );

    v_visit_3 := public.fn_complete_appointment(
        v_appointment_3,
        'Плановый контроль показателей.',
        'Повторное посещение клиники.',
        'Выполнены ЭКГ и измерение артериального давления.',
        'Результаты сохранены в медицинской карте.'
    );

    v_visit_4 := public.fn_complete_appointment(
        v_appointment_4,
        'Повторяющиеся приступы головной боли.',
        'Жалобы возникают периодически.',
        'Проведён неврологический осмотр.',
        'Рекомендовано наблюдение у специалиста.'
    );

    v_visit_5 := public.fn_complete_appointment(
        v_appointment_5,
        'Жалобы на сухость и раздражение кожи.',
        'Симптомы имеют периодический характер.',
        'Проведён осмотр кожных покровов.',
        'Результаты осмотра зафиксированы.'
    );

    v_visit_6 := public.fn_complete_appointment(
        v_appointment_6,
        'Жалобы на снижение чёткости зрения вдаль.',
        'Плановое обращение.',
        'Проведена проверка остроты зрения.',
        'Рекомендовано дальнейшее наблюдение.'
    );

    v_visit_7 := public.fn_complete_appointment(
        v_appointment_7,
        'Жалобы на повышение температуры и насморк.',
        'Симптомы появились незадолго до обращения.',
        'Проведён осмотр педиатра.',
        'Данные осмотра внесены в карту.'
    );

    PERFORM public.fn_mark_appointment_no_show(v_appointment_8);

    INSERT INTO public.visit_diagnoses (visit_id, diagnosis_id, note)
    VALUES
        (v_visit_1, v_diagnosis_hypertension, 'Демонстрационная запись диагноза.'),
        (v_visit_2, v_diagnosis_ischemic, 'Демонстрационная запись диагноза.'),
        (v_visit_2, v_diagnosis_arrhythmia, 'Дополнительная демонстрационная запись диагноза.'),
        (v_visit_4, v_diagnosis_migraine, 'Демонстрационная запись диагноза.'),
        (v_visit_5, v_diagnosis_dermatitis, 'Демонстрационная запись диагноза.'),
        (v_visit_6, v_diagnosis_myopia, 'Демонстрационная запись диагноза.'),
        (v_visit_7, v_diagnosis_arvi, 'Демонстрационная запись диагноза.');

    INSERT INTO public.prescriptions (
        visit_id,
        medication_name,
        dosage,
        frequency,
        duration,
        instructions
    )
    VALUES
        (
            v_visit_1,
            'Демонстрационный препарат А',
            '1 условная единица',
            'По демонстрационной схеме',
            '5 дней',
            'Вымышленные данные для проверки структуры БД; не являются назначением.'
        ),
        (
            v_visit_2,
            'Демонстрационный препарат Б',
            '1 условная единица',
            'По демонстрационной схеме',
            '7 дней',
            'Вымышленные данные для проверки структуры БД; не являются назначением.'
        ),
        (
            v_visit_4,
            'Демонстрационный препарат В',
            '1 условная единица',
            'По демонстрационной схеме',
            '3 дня',
            'Вымышленные данные для проверки структуры БД; не являются назначением.'
        );

    v_invoice_paid := public.fn_issue_invoice(
        v_visit_1,
        'DEMO-2026-001',
        v_today + 30
    );

    v_invoice_partial := public.fn_issue_invoice(
        v_visit_2,
        'DEMO-2026-002',
        v_today + 30
    );

    v_invoice_unpaid := public.fn_issue_invoice(
        v_visit_4,
        'DEMO-2026-003',
        v_today + 30
    );

    INSERT INTO public.invoices (
        visit_id,
        invoice_number,
        issued_at,
        due_date
    )
    VALUES (
        v_visit_3,
        'DEMO-2026-004',
        v_d1_schedule_start + INTERVAL '1 day',
        v_today - 1
    )
    RETURNING invoice_id INTO v_invoice_overdue;

    PERFORM public.fn_register_payment(
        v_invoice_paid,
        1800.00,
        'bank_card',
        'DEMO-TXN-2026-001',
        'Полная демонстрационная оплата.'
    );

    PERFORM public.fn_register_payment(
        v_invoice_partial,
        1000.00,
        'cash',
        'DEMO-TXN-2026-002',
        'Частичная демонстрационная оплата.'
    );

    v_future_appointment_1 := public.fn_book_appointment(
        v_doctor_1,
        v_patient_1,
        v_future_schedule_start,
        ARRAY[v_service_primary]
    );

    v_future_appointment_2 := public.fn_book_appointment(
        v_doctor_1,
        v_patient_8,
        v_future_schedule_start + INTERVAL '45 minutes',
        ARRAY[v_service_repeat]
    );

    v_future_appointment_3 := public.fn_book_appointment(
        v_doctor_1,
        v_patient_2,
        v_future_schedule_start + INTERVAL '75 minutes',
        ARRAY[v_service_cardiology]
    );

    v_future_appointment_4 := public.fn_book_appointment(
        v_doctor_1,
        v_patient_6,
        v_future_schedule_start + INTERVAL '2 hours',
        ARRAY[v_service_ecg, v_service_pressure]
    );

    PERFORM public.fn_cancel_appointment(
        v_future_appointment_2,
        'Пациент заранее отменил запись.'
    );

    RAISE NOTICE 'Демонстрационный набор создан: 8 пациентов, 4 врача, 5 интервалов расписания.';
    RAISE NOTICE 'Исторические записи: 7 completed, 1 no_show; будущие: 3 scheduled, 1 cancelled.';
    RAISE NOTICE 'Создано 7 визитов, 7 связей с диагнозами и 3 демонстрационных назначения.';
    RAISE NOTICE 'Создано 4 счёта и 2 платежа; представлены все 4 статуса счёта.';
END;
$$;

SET CONSTRAINTS ALL IMMEDIATE;

COMMIT;