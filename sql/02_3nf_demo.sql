BEGIN;

-- Все данные примера являются учебными.
INSERT INTO nf3.students (student_number, full_name)
VALUES ('ST-001', 'Иванов Иван Иванович');

INSERT INTO nf3.subjects (subject_code, subject_name)
VALUES ('DB', 'Базы данных');

INSERT INTO nf3.exams (exam_code, subject_id, exam_date)
SELECT 'DB-2026-01', subject_id, DATE '2026-11-15'
FROM nf3.subjects
WHERE subject_code = 'DB';

-- Порядок действий для подготовки на отличную оценку.
INSERT INTO nf3.preparation_steps (
    exam_id, step_no, step_title,
    instructions, expected_result, planned_minutes
)
SELECT e.exam_id, v.*
FROM nf3.exams e
CROSS JOIN (VALUES
    (1, 'Изучить требования',
     'Получить список вопросов и критерии оценки.',
     'Составлен перечень тем и требований к оценке 5.', 30),
    (2, 'Повторить теорию',
     'Повторить ключи, нормальные формы и связи таблиц.',
     'Студент объясняет основные понятия без подсказок.', 120),
    (3, 'Выполнить практические задания',
     'Создать таблицы и написать запросы SELECT с JOIN.',
     'Запросы выполнены и дают ожидаемый результат.', 150),
    (4, 'Пройти пробный экзамен',
     'Ответить на вопросы и решить задачу за ограниченное время.',
     'Достигнут результат не ниже 90 баллов из 100.', 90),
    (5, 'Разобрать ошибки и повторить',
     'Исправить ошибки пробного экзамена и повторить слабые темы.',
     'Ошибочные задания решены повторно без ошибок.', 60)
) AS v(step_no, step_title, instructions, expected_result, planned_minutes)
WHERE e.exam_code = 'DB-2026-01';

-- Цель подготовки — оценка 5; фактический результат пока неизвестен.
INSERT INTO nf3.student_preparations (
    student_id, exam_id, started_on, target_grade
)
SELECT s.student_id, e.exam_id, DATE '2026-11-01', 5
FROM nf3.students s
CROSS JOIN nf3.exams e
WHERE s.student_number = 'ST-001'
  AND e.exam_code = 'DB-2026-01';

-- Первые два шага завершены, третий выполняется,
-- остальные запланированы.
INSERT INTO nf3.step_progress (
    student_id, exam_id, step_no, status, score, completed_at
)
SELECT p.student_id, p.exam_id, st.step_no,
       CASE
           WHEN st.step_no <= 2 THEN 'done'
           WHEN st.step_no = 3 THEN 'in_progress'
           ELSE 'planned'
       END,
       CASE WHEN st.step_no = 2 THEN 85 ELSE NULL END,
       CASE WHEN st.step_no <= 2
            THEN TIMESTAMPTZ '2026-11-01 12:00:00+03'
            ELSE NULL END
FROM nf3.student_preparations p
JOIN nf3.students s ON s.student_id = p.student_id
JOIN nf3.exams e ON e.exam_id = p.exam_id
JOIN nf3.preparation_steps st ON st.exam_id = p.exam_id
WHERE s.student_number = 'ST-001'
  AND e.exam_code = 'DB-2026-01';

COMMIT;
