BEGIN;

SET LOCAL search_path TO public;

CREATE EXTENSION IF NOT EXISTS btree_gist;


CREATE TABLE patients (
    patient_id BIGINT GENERATED ALWAYS AS IDENTITY,
    last_name VARCHAR(100) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    birth_date DATE NOT NULL,
    gender VARCHAR(10),
    snils VARCHAR(11),
    phone VARCHAR(30),
    email VARCHAR(254),
    address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_patients
        PRIMARY KEY (patient_id),

    CONSTRAINT uq_patients_snils
        UNIQUE (snils),

    CONSTRAINT ck_patients_last_name
        CHECK (BTRIM(last_name) <> ''),

    CONSTRAINT ck_patients_first_name
        CHECK (BTRIM(first_name) <> ''),

    CONSTRAINT ck_patients_gender
        CHECK (gender IS NULL OR gender IN ('male', 'female')),

    CONSTRAINT ck_patients_snils
        CHECK (snils IS NULL OR snils ~ '^[0-9]{11}$'),

    CONSTRAINT ck_patients_phone
        CHECK (phone IS NULL OR BTRIM(phone) <> ''),

    CONSTRAINT ck_patients_email
        CHECK (email IS NULL OR BTRIM(email) <> ''),

    CONSTRAINT ck_patients_contact
        CHECK (
            NULLIF(BTRIM(phone), '') IS NOT NULL
            OR NULLIF(BTRIM(email), '') IS NOT NULL
        )
);



CREATE TABLE specialties (
    specialty_id BIGINT GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_specialties
        PRIMARY KEY (specialty_id),

    CONSTRAINT uq_specialties_name
        UNIQUE (name),

    CONSTRAINT ck_specialties_name
        CHECK (BTRIM(name) <> '')
);



CREATE TABLE doctors (
    doctor_id BIGINT GENERATED ALWAYS AS IDENTITY,
    last_name VARCHAR(100) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    phone VARCHAR(30),
    email VARCHAR(254),
    hire_date DATE NOT NULL,
    employment_status VARCHAR(20) NOT NULL DEFAULT 'active',

    CONSTRAINT pk_doctors
        PRIMARY KEY (doctor_id),

    CONSTRAINT ck_doctors_last_name
        CHECK (BTRIM(last_name) <> ''),

    CONSTRAINT ck_doctors_first_name
        CHECK (BTRIM(first_name) <> ''),

    CONSTRAINT ck_doctors_phone
        CHECK (phone IS NULL OR BTRIM(phone) <> ''),

    CONSTRAINT ck_doctors_email
        CHECK (email IS NULL OR BTRIM(email) <> ''),

    CONSTRAINT ck_doctors_employment_status
        CHECK (
            employment_status IN (
                'active',
                'on_leave',
                'dismissed'
            )
        )
);


CREATE TABLE doctor_specialties (
    doctor_id BIGINT NOT NULL,
    specialty_id BIGINT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_doctor_specialties
        PRIMARY KEY (doctor_id, specialty_id),

    CONSTRAINT fk_doctor_specialties_doctor
        FOREIGN KEY (doctor_id)
        REFERENCES doctors (doctor_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_doctor_specialties_specialty
        FOREIGN KEY (specialty_id)
        REFERENCES specialties (specialty_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
);


CREATE TABLE services (
    service_id BIGINT GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price NUMERIC(12, 2) NOT NULL,
    duration_minutes INTEGER NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_services
        PRIMARY KEY (service_id),

    CONSTRAINT uq_services_name
        UNIQUE (name),

    CONSTRAINT ck_services_name
        CHECK (BTRIM(name) <> ''),

    CONSTRAINT ck_services_price
        CHECK (price > 0),

    CONSTRAINT ck_services_duration
        CHECK (duration_minutes > 0)
);



CREATE TABLE doctor_services (
    doctor_id BIGINT NOT NULL,
    service_id BIGINT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_doctor_services
        PRIMARY KEY (doctor_id, service_id),

    CONSTRAINT fk_doctor_services_doctor
        FOREIGN KEY (doctor_id)
        REFERENCES doctors (doctor_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_doctor_services_service
        FOREIGN KEY (service_id)
        REFERENCES services (service_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
);


CREATE TABLE doctor_schedule (
    schedule_id BIGINT GENERATED ALWAYS AS IDENTITY,
    doctor_id BIGINT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    note TEXT,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,

    CONSTRAINT pk_doctor_schedule
        PRIMARY KEY (schedule_id),

    CONSTRAINT fk_doctor_schedule_doctor
        FOREIGN KEY (doctor_id)
        REFERENCES doctors (doctor_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_doctor_schedule_interval
        CHECK (ends_at > starts_at),

    CONSTRAINT ck_doctor_schedule_cancellation
        CHECK (
            (
                cancelled_at IS NULL
                AND cancellation_reason IS NULL
            )
            OR
            (
                cancelled_at IS NOT NULL
                AND NULLIF(BTRIM(cancellation_reason), '') IS NOT NULL
            )
        ),

    -- Non-cancelled working intervals of the same doctor
    -- must not overlap. Adjacent intervals are allowed.
    CONSTRAINT ex_doctor_schedule_no_overlap
        EXCLUDE USING GIST (
            doctor_id WITH =,
            (tstzrange(starts_at, ends_at, '[)')) WITH &&
        )
        WHERE (cancelled_at IS NULL)
);


CREATE TABLE appointments (
    appointment_id BIGINT GENERATED ALWAYS AS IDENTITY,
    schedule_id BIGINT NOT NULL,
    patient_id BIGINT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cancellation_reason TEXT,
    cancelled_at TIMESTAMPTZ,

    CONSTRAINT pk_appointments
        PRIMARY KEY (appointment_id),

    CONSTRAINT fk_appointments_schedule
        FOREIGN KEY (schedule_id)
        REFERENCES doctor_schedule (schedule_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_appointments_patient
        FOREIGN KEY (patient_id)
        REFERENCES patients (patient_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_appointments_interval
        CHECK (ends_at > starts_at),

    CONSTRAINT ck_appointments_status
        CHECK (
            status IN (
                'scheduled',
                'completed',
                'cancelled',
                'no_show'
            )
        ),

    CONSTRAINT ck_appointments_cancellation
        CHECK (
            (
                status = 'cancelled'
                AND cancelled_at IS NOT NULL
                AND NULLIF(BTRIM(cancellation_reason), '') IS NOT NULL
            )
            OR
            (
                status <> 'cancelled'
                AND cancelled_at IS NULL
                AND cancellation_reason IS NULL
            )
        ),

    CONSTRAINT ex_appointments_patient_no_overlap
        EXCLUDE USING GIST (
            patient_id WITH =,
            (tstzrange(starts_at, ends_at, '[)')) WITH &&
        )
        WHERE (status <> 'cancelled')
);



CREATE TABLE appointment_services (
    appointment_service_id BIGINT GENERATED ALWAYS AS IDENTITY,
    appointment_id BIGINT NOT NULL,
    service_id BIGINT NOT NULL,
    duration_minutes_at_booking INTEGER NOT NULL,
    price_at_booking NUMERIC(12, 2) NOT NULL,

    CONSTRAINT pk_appointment_services
        PRIMARY KEY (appointment_service_id),

    CONSTRAINT fk_appointment_services_appointment
        FOREIGN KEY (appointment_id)
        REFERENCES appointments (appointment_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_appointment_services_service
        FOREIGN KEY (service_id)
        REFERENCES services (service_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_appointment_services_duration
        CHECK (duration_minutes_at_booking > 0),

    CONSTRAINT ck_appointment_services_price
        CHECK (price_at_booking > 0)
);


CREATE TABLE visits (
    visit_id BIGINT GENERATED ALWAYS AS IDENTITY,
    appointment_id BIGINT NOT NULL,
    complaints TEXT,
    anamnesis TEXT,
    examination_results TEXT,
    conclusion TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_visits
        PRIMARY KEY (visit_id),

    CONSTRAINT uq_visits_appointment
        UNIQUE (appointment_id),

    CONSTRAINT fk_visits_appointment
        FOREIGN KEY (appointment_id)
        REFERENCES appointments (appointment_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
);


CREATE TABLE diagnoses (
    diagnosis_id BIGINT GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_diagnoses
        PRIMARY KEY (diagnosis_id),

    CONSTRAINT uq_diagnoses_name
        UNIQUE (name),

    CONSTRAINT ck_diagnoses_name
        CHECK (BTRIM(name) <> '')
);


CREATE TABLE visit_diagnoses (
    visit_id BIGINT NOT NULL,
    diagnosis_id BIGINT NOT NULL,
    note TEXT,

    CONSTRAINT pk_visit_diagnoses
        PRIMARY KEY (visit_id, diagnosis_id),

    CONSTRAINT fk_visit_diagnoses_visit
        FOREIGN KEY (visit_id)
        REFERENCES visits (visit_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_visit_diagnoses_diagnosis
        FOREIGN KEY (diagnosis_id)
        REFERENCES diagnoses (diagnosis_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
);


CREATE TABLE prescriptions (
    prescription_id BIGINT GENERATED ALWAYS AS IDENTITY,
    visit_id BIGINT NOT NULL,
    medication_name VARCHAR(255) NOT NULL,
    dosage VARCHAR(100),
    frequency VARCHAR(255),
    duration VARCHAR(100),
    instructions TEXT,

    CONSTRAINT pk_prescriptions
        PRIMARY KEY (prescription_id),

    CONSTRAINT fk_prescriptions_visit
        FOREIGN KEY (visit_id)
        REFERENCES visits (visit_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_prescriptions_medication_name
        CHECK (BTRIM(medication_name) <> '')
);


CREATE TABLE invoices (
    invoice_id BIGINT GENERATED ALWAYS AS IDENTITY,
    visit_id BIGINT NOT NULL,
    invoice_number VARCHAR(50) NOT NULL,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    due_date DATE NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,

    CONSTRAINT pk_invoices
        PRIMARY KEY (invoice_id),

    CONSTRAINT uq_invoices_visit
        UNIQUE (visit_id),

    CONSTRAINT uq_invoices_number
        UNIQUE (invoice_number),

    CONSTRAINT fk_invoices_visit
        FOREIGN KEY (visit_id)
        REFERENCES visits (visit_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_invoices_number
        CHECK (BTRIM(invoice_number) <> ''),

    CONSTRAINT ck_invoices_total_amount
        CHECK (total_amount > 0)
);


CREATE TABLE payments (
    payment_id BIGINT GENERATED ALWAYS AS IDENTITY,
    invoice_id BIGINT NOT NULL,
    paid_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    amount NUMERIC(12, 2) NOT NULL,
    payment_method VARCHAR(30) NOT NULL,
    transaction_number VARCHAR(100),
    note TEXT,

    CONSTRAINT pk_payments
        PRIMARY KEY (payment_id),

    CONSTRAINT uq_payments_transaction_number
        UNIQUE (transaction_number),

    CONSTRAINT fk_payments_invoice
        FOREIGN KEY (invoice_id)
        REFERENCES invoices (invoice_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_payments_amount
        CHECK (amount > 0),

    CONSTRAINT ck_payments_method
        CHECK (
            payment_method IN (
                'cash',
                'bank_card',
                'bank_transfer',
                'online'
            )
        ),

    CONSTRAINT ck_payments_transaction_number
        CHECK (
            transaction_number IS NULL
            OR BTRIM(transaction_number) <> ''
        )
);


CREATE INDEX ix_doctor_specialties_specialty_id
    ON doctor_specialties (specialty_id);

CREATE INDEX ix_doctor_services_service_id
    ON doctor_services (service_id);

CREATE INDEX ix_doctor_schedule_doctor_starts_at
    ON doctor_schedule (doctor_id, starts_at);

CREATE INDEX ix_appointments_schedule_starts_at
    ON appointments (schedule_id, starts_at);

CREATE INDEX ix_appointments_patient_starts_at
    ON appointments (patient_id, starts_at);

CREATE INDEX ix_appointment_services_appointment_id
    ON appointment_services (appointment_id);

CREATE INDEX ix_appointment_services_service_id
    ON appointment_services (service_id);

CREATE INDEX ix_visit_diagnoses_diagnosis_id
    ON visit_diagnoses (diagnosis_id);

CREATE INDEX ix_prescriptions_visit_id
    ON prescriptions (visit_id);

CREATE INDEX ix_payments_invoice_id
    ON payments (invoice_id);


COMMENT ON COLUMN services.price
    IS 'Service price in RUB.';

COMMENT ON COLUMN appointment_services.price_at_booking
    IS 'Service price in RUB captured at appointment booking.';

COMMENT ON COLUMN invoices.total_amount
    IS 'Fixed invoice total in RUB at issue time.';

COMMENT ON COLUMN payments.amount
    IS 'Successful incoming payment amount in RUB.';


COMMIT;