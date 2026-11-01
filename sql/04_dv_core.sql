BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;
CREATE SCHEMA dv;

-- SHA-256 занимает 32 байта.
CREATE DOMAIN dv.hash32 AS BYTEA
    CHECK (octet_length(VALUE) = 32);

-- Единый способ вычисления ключей.
-- JSON-массив сохраняет границы компонентов составного ключа.
-- Первый компонент при вызове обозначает тип сущности или связи.
CREATE FUNCTION dv.hk(VARIADIC parts TEXT[])
RETURNS dv.hash32
LANGUAGE SQL IMMUTABLE STRICT
AS $$
    SELECT public.digest(
        convert_to(array_to_json(parts)::TEXT, 'UTF8'),
        'sha256'
    )::dv.hash32;
$$;

-- ХАБЫ: бизнес-ключи и сведения о первом появлении в хранилище.

CREATE TABLE dv.hub_student (
    student_hk dv.hash32 PRIMARY KEY,
    student_number VARCHAR(30) NOT NULL UNIQUE,
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL
);

CREATE TABLE dv.hub_subject (
    subject_hk dv.hash32 PRIMARY KEY,
    subject_code VARCHAR(30) NOT NULL UNIQUE,
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL
);

CREATE TABLE dv.hub_exam (
    exam_hk dv.hash32 PRIMARY KEY,
    exam_code VARCHAR(50) NOT NULL UNIQUE,
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL
);

-- В учебной модели шаг идентифицируется кодом экзамена и номером.
-- Номер считаем постоянным идентификатором шага внутри экзамена.
-- exam_code здесь — часть бизнес-ключа, а не внешний ключ.
CREATE TABLE dv.hub_step (
    step_hk dv.hash32 PRIMARY KEY,
    exam_code VARCHAR(50) NOT NULL,
    step_no INTEGER NOT NULL CHECK (step_no > 0),
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL,
    UNIQUE (exam_code, step_no)
);

-- СВЯЗИ: отношения между бизнес-сущностями.
-- Хабы напрямую друг на друга не ссылаются.

-- Принадлежность экзамена дисциплине.
CREATE TABLE dv.lnk_exam_subject (
    link_hk dv.hash32 PRIMARY KEY,
    exam_hk dv.hash32 NOT NULL REFERENCES dv.hub_exam(exam_hk),
    subject_hk dv.hash32 NOT NULL REFERENCES dv.hub_subject(subject_hk),
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL,
    UNIQUE (exam_hk, subject_hk)
);

-- Включение шага в подготовку к экзамену.
CREATE TABLE dv.lnk_exam_step (
    link_hk dv.hash32 PRIMARY KEY,
    exam_hk dv.hash32 NOT NULL REFERENCES dv.hub_exam(exam_hk),
    step_hk dv.hash32 NOT NULL REFERENCES dv.hub_step(step_hk),
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL,
    UNIQUE (exam_hk, step_hk)
);

-- Подготовка студента к экзамену.
CREATE TABLE dv.lnk_student_exam (
    link_hk dv.hash32 PRIMARY KEY,
    student_hk dv.hash32 NOT NULL REFERENCES dv.hub_student(student_hk),
    exam_hk dv.hash32 NOT NULL REFERENCES dv.hub_exam(exam_hk),
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL,
    UNIQUE (student_hk, exam_hk)
);

-- Выполнение конкретного шага студентом в рамках экзамена.
CREATE TABLE dv.lnk_student_step (
    link_hk dv.hash32 PRIMARY KEY,
    student_hk dv.hash32 NOT NULL REFERENCES dv.hub_student(student_hk),
    exam_hk dv.hash32 NOT NULL REFERENCES dv.hub_exam(exam_hk),
    step_hk dv.hash32 NOT NULL REFERENCES dv.hub_step(step_hk),
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL,
    UNIQUE (student_hk, exam_hk, step_hk)
);

COMMENT ON SCHEMA dv IS
    'ЛР2. Подготовка к экзамену. Модель Data Vault';

COMMENT ON TABLE dv.hub_student IS
    'Хаб студентов; бизнес-ключ — номер студенческого билета';
COMMENT ON TABLE dv.hub_subject IS
    'Хаб дисциплин; бизнес-ключ — код дисциплины';
COMMENT ON TABLE dv.hub_exam IS
    'Хаб экзаменов; бизнес-ключ — код экзамена';
COMMENT ON TABLE dv.hub_step IS
    'Хаб шагов; бизнес-ключ — код экзамена и постоянный номер шага';

COMMENT ON TABLE dv.lnk_exam_subject IS
    'Связь экзамена с дисциплиной';
COMMENT ON TABLE dv.lnk_exam_step IS
    'Связь экзамена с шагом подготовки';
COMMENT ON TABLE dv.lnk_student_exam IS
    'Связь студента с экзаменом';
COMMENT ON TABLE dv.lnk_student_step IS
    'Связь студента, экзамена и выполняемого шага';

COMMENT ON FUNCTION dv.hk(TEXT[]) IS
    'SHA-256 от JSON-массива компонентов, кодированного в UTF-8';

COMMIT;
