BEGIN;

-- Сателлиты хранят версии описательных атрибутов.
-- Ключ версии: ключ родителя + время загрузки.
-- hashdiff — хеш атрибутов для обнаружения изменений.
-- record_source — источник поступивших данных.

CREATE TABLE dv.sat_student (
    student_hk dv.hash32 NOT NULL
        REFERENCES dv.hub_student(student_hk),
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL,
    hashdiff dv.hash32 NOT NULL,
    full_name VARCHAR(200) NOT NULL,
    PRIMARY KEY (student_hk, load_dts)
);

CREATE TABLE dv.sat_subject (
    subject_hk dv.hash32 NOT NULL
        REFERENCES dv.hub_subject(subject_hk),
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL,
    hashdiff dv.hash32 NOT NULL,
    subject_name VARCHAR(200) NOT NULL,
    PRIMARY KEY (subject_hk, load_dts)
);

CREATE TABLE dv.sat_exam (
    exam_hk dv.hash32 NOT NULL
        REFERENCES dv.hub_exam(exam_hk),
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL,
    hashdiff dv.hash32 NOT NULL,
    exam_date DATE NOT NULL,
    PRIMARY KEY (exam_hk, load_dts)
);

CREATE TABLE dv.sat_step (
    step_hk dv.hash32 NOT NULL
        REFERENCES dv.hub_step(step_hk),
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL,
    hashdiff dv.hash32 NOT NULL,
    step_title VARCHAR(200) NOT NULL,
    instructions TEXT NOT NULL,
    expected_result TEXT NOT NULL,
    planned_minutes INTEGER NOT NULL,
    PRIMARY KEY (step_hk, load_dts)
);

-- Описательные атрибуты связи "студент — экзамен".
CREATE TABLE dv.sat_student_exam (
    link_hk dv.hash32 NOT NULL
        REFERENCES dv.lnk_student_exam(link_hk),
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL,
    hashdiff dv.hash32 NOT NULL,
    started_on DATE NOT NULL,
    target_grade SMALLINT NOT NULL,
    final_grade SMALLINT,
    PRIMARY KEY (link_hk, load_dts)
);

-- История выполнения шага конкретным студентом.
CREATE TABLE dv.sat_student_step (
    link_hk dv.hash32 NOT NULL
        REFERENCES dv.lnk_student_step(link_hk),
    load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    record_source TEXT NOT NULL,
    hashdiff dv.hash32 NOT NULL,
    status VARCHAR(20) NOT NULL,
    score SMALLINT,
    completed_at TIMESTAMPTZ,
    notes TEXT,
    PRIMARY KEY (link_hk, load_dts)
);

COMMENT ON TABLE dv.sat_student IS
    'История ФИО студента';
COMMENT ON TABLE dv.sat_subject IS
    'История названия дисциплины';
COMMENT ON TABLE dv.sat_exam IS
    'История даты экзамена';
COMMENT ON TABLE dv.sat_step IS
    'История описания шага и плановой трудоёмкости';
COMMENT ON TABLE dv.sat_student_exam IS
    'История параметров подготовки и итоговой оценки';
COMMENT ON TABLE dv.sat_student_step IS
    'История статуса, баллов и завершения шага';

COMMENT ON COLUMN dv.sat_student_step.load_dts IS
    'Время загрузки версии в хранилище';
COMMENT ON COLUMN dv.sat_student_step.completed_at IS
    'Время фактического завершения шага по данным источника';
COMMENT ON COLUMN dv.sat_student_step.hashdiff IS
    'SHA-256 описательных атрибутов для сравнения версий';

COMMIT;
