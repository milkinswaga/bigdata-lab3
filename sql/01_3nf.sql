BEGIN;

-- Отдельная схема для модели третьей нормальной формы.
CREATE SCHEMA nf3;

-- Студент: номер студенческого билета является бизнес-ключом.
CREATE TABLE nf3.students (
    student_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_number VARCHAR(30) NOT NULL UNIQUE,
    full_name VARCHAR(200) NOT NULL
);

-- Дисциплина хранится независимо от экзаменов.
CREATE TABLE nf3.subjects (
    subject_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subject_code VARCHAR(30) NOT NULL UNIQUE,
    subject_name VARCHAR(200) NOT NULL
);

-- Экзамен относится к одной дисциплине.
CREATE TABLE nf3.exams (
    exam_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    exam_code VARCHAR(50) NOT NULL UNIQUE,
    subject_id BIGINT NOT NULL REFERENCES nf3.subjects(subject_id),
    exam_date DATE NOT NULL
);

-- Порядок подготовки задаётся номерами шагов внутри экзамена.
CREATE TABLE nf3.preparation_steps (
    exam_id BIGINT NOT NULL REFERENCES nf3.exams(exam_id),
    step_no INTEGER NOT NULL CHECK (step_no > 0),
    step_title VARCHAR(200) NOT NULL,
    instructions TEXT NOT NULL,
    expected_result TEXT NOT NULL,
    planned_minutes INTEGER NOT NULL CHECK (planned_minutes > 0),
    PRIMARY KEY (exam_id, step_no)
);

-- Одна запись на пару "студент — экзамен".
-- Итоговая оценка остаётся NULL до получения результата.
CREATE TABLE nf3.student_preparations (
    student_id BIGINT NOT NULL REFERENCES nf3.students(student_id),
    exam_id BIGINT NOT NULL REFERENCES nf3.exams(exam_id),
    started_on DATE NOT NULL,
    target_grade SMALLINT NOT NULL DEFAULT 5
        CHECK (target_grade BETWEEN 2 AND 5),
    final_grade SMALLINT CHECK (final_grade BETWEEN 2 AND 5),
    PRIMARY KEY (student_id, exam_id)
);

-- Индивидуальное выполнение шага.
-- Составные внешние ключи исключают шаг от чужого экзамена
-- и прогресс студента, не зарегистрированного на подготовку.
CREATE TABLE nf3.step_progress (
    student_id BIGINT NOT NULL,
    exam_id BIGINT NOT NULL,
    step_no INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'planned'
        CHECK (status IN ('planned', 'in_progress', 'done')),
    score SMALLINT CHECK (score BETWEEN 0 AND 100),
    completed_at TIMESTAMPTZ,
    notes TEXT,
    PRIMARY KEY (student_id, exam_id, step_no),
    FOREIGN KEY (student_id, exam_id)
        REFERENCES nf3.student_preparations(student_id, exam_id),
    FOREIGN KEY (exam_id, step_no)
        REFERENCES nf3.preparation_steps(exam_id, step_no),
    CONSTRAINT completion_matches_status CHECK (
        (status = 'done' AND completed_at IS NOT NULL)
        OR
        (status <> 'done' AND completed_at IS NULL)
    )
);

-- Документация сохраняется непосредственно в PostgreSQL.
COMMENT ON SCHEMA nf3 IS
    'ЛР2. Подготовка к экзамену. Модель 3NF';

COMMENT ON TABLE nf3.students IS
    'Студенты и уникальные номера студенческих билетов';
COMMENT ON TABLE nf3.subjects IS
    'Учебные дисциплины';
COMMENT ON TABLE nf3.exams IS
    'Экзамены по учебным дисциплинам';
COMMENT ON TABLE nf3.preparation_steps IS
    'Упорядоченный перечень шагов подготовки к каждому экзамену';
COMMENT ON TABLE nf3.student_preparations IS
    'Подготовка студента к экзамену, целевая и итоговая оценки';
COMMENT ON TABLE nf3.step_progress IS
    'Текущее состояние выполнения шагов студентом';

COMMENT ON COLUMN nf3.preparation_steps.step_no IS
    'Порядковый номер шага в пределах конкретного экзамена';
COMMENT ON COLUMN nf3.step_progress.score IS
    'Результат самопроверки от 0 до 100; NULL, если не оценивался';
COMMENT ON COLUMN nf3.step_progress.status IS
    'planned — запланирован; in_progress — выполняется; done — завершён';

COMMIT;
