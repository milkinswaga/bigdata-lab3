BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL DateStyle TO 'ISO, YMD';

-- Первичная загрузка выполняется один раз.
-- Проверка защищает от повторного добавления тех же версий.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM dv.hub_student) THEN
        RAISE EXCEPTION 'Первичная загрузка уже выполнена';
    END IF;
END;
$$;

-- 1. ХАБЫ.
-- Ключи вычисляются из бизнес-ключей, без идентификаторов 3NF.

INSERT INTO dv.hub_student (
    student_hk, student_number, record_source
)
SELECT dv.hk('student', student_number), student_number, 'nf3'
FROM nf3.students;

INSERT INTO dv.hub_subject (
    subject_hk, subject_code, record_source
)
SELECT dv.hk('subject', subject_code), subject_code, 'nf3'
FROM nf3.subjects;

INSERT INTO dv.hub_exam (exam_hk, exam_code, record_source)
SELECT dv.hk('exam', exam_code), exam_code, 'nf3'
FROM nf3.exams;

INSERT INTO dv.hub_step (
    step_hk, exam_code, step_no, record_source
)
SELECT dv.hk('step', e.exam_code, st.step_no::TEXT),
       e.exam_code, st.step_no, 'nf3'
FROM nf3.preparation_steps st
JOIN nf3.exams e ON e.exam_id = st.exam_id;

-- 2. СВЯЗИ.

INSERT INTO dv.lnk_exam_subject (
    link_hk, exam_hk, subject_hk, record_source
)
SELECT dv.hk('exam_subject', e.exam_code, s.subject_code),
       dv.hk('exam', e.exam_code),
       dv.hk('subject', s.subject_code), 'nf3'
FROM nf3.exams e
JOIN nf3.subjects s ON s.subject_id = e.subject_id;

INSERT INTO dv.lnk_exam_step (
    link_hk, exam_hk, step_hk, record_source
)
SELECT dv.hk('exam_step', e.exam_code, st.step_no::TEXT),
       dv.hk('exam', e.exam_code),
       dv.hk('step', e.exam_code, st.step_no::TEXT), 'nf3'
FROM nf3.preparation_steps st
JOIN nf3.exams e ON e.exam_id = st.exam_id;

INSERT INTO dv.lnk_student_exam (
    link_hk, student_hk, exam_hk, record_source
)
SELECT dv.hk('student_exam', s.student_number, e.exam_code),
       dv.hk('student', s.student_number),
       dv.hk('exam', e.exam_code), 'nf3'
FROM nf3.student_preparations p
JOIN nf3.students s ON s.student_id = p.student_id
JOIN nf3.exams e ON e.exam_id = p.exam_id;

INSERT INTO dv.lnk_student_step (
    link_hk, student_hk, exam_hk, step_hk, record_source
)
SELECT dv.hk('student_step', s.student_number,
             e.exam_code, p.step_no::TEXT),
       dv.hk('student', s.student_number),
       dv.hk('exam', e.exam_code),
       dv.hk('step', e.exam_code, p.step_no::TEXT), 'nf3'
FROM nf3.step_progress p
JOIN nf3.students s ON s.student_id = p.student_id
JOIN nf3.exams e ON e.exam_id = p.exam_id;

-- 3. САТЕЛЛИТЫ.
-- Время загрузки заполняется автоматически.
-- hashdiff рассчитывается по описательным атрибутам.

INSERT INTO dv.sat_student (
    student_hk, record_source, hashdiff, full_name
)
SELECT dv.hk('student', student_number), 'nf3',
       dv.hk('sat_student', full_name), full_name
FROM nf3.students;

INSERT INTO dv.sat_subject (
    subject_hk, record_source, hashdiff, subject_name
)
SELECT dv.hk('subject', subject_code), 'nf3',
       dv.hk('sat_subject', subject_name), subject_name
FROM nf3.subjects;

INSERT INTO dv.sat_exam (
    exam_hk, record_source, hashdiff, exam_date
)
SELECT dv.hk('exam', exam_code), 'nf3',
       dv.hk('sat_exam', exam_date::TEXT), exam_date
FROM nf3.exams;

INSERT INTO dv.sat_step (
    step_hk, record_source, hashdiff,
    step_title, instructions, expected_result, planned_minutes
)
SELECT dv.hk('step', e.exam_code, st.step_no::TEXT), 'nf3',
       dv.hk('sat_step', st.step_title, st.instructions,
             st.expected_result, st.planned_minutes::TEXT),
       st.step_title, st.instructions,
       st.expected_result, st.planned_minutes
FROM nf3.preparation_steps st
JOIN nf3.exams e ON e.exam_id = st.exam_id;

INSERT INTO dv.sat_student_exam (
    link_hk, record_source, hashdiff,
    started_on, target_grade, final_grade
)
SELECT dv.hk('student_exam', s.student_number, e.exam_code), 'nf3',
       dv.hk('sat_student_exam', p.started_on::TEXT,
             p.target_grade::TEXT, p.final_grade::TEXT),
       p.started_on, p.target_grade, p.final_grade
FROM nf3.student_preparations p
JOIN nf3.students s ON s.student_id = p.student_id
JOIN nf3.exams e ON e.exam_id = p.exam_id;

-- Время завершения при вычислении хеша представлено
-- числом секунд от начала эпохи, независимо от часового пояса.
INSERT INTO dv.sat_student_step (
    link_hk, record_source, hashdiff,
    status, score, completed_at, notes
)
SELECT dv.hk('student_step', s.student_number,
             e.exam_code, p.step_no::TEXT), 'nf3',
       dv.hk('sat_student_step', p.status, p.score::TEXT,
             EXTRACT(EPOCH FROM p.completed_at)::TEXT, p.notes),
       p.status, p.score, p.completed_at, p.notes
FROM nf3.step_progress p
JOIN nf3.students s ON s.student_id = p.student_id
JOIN nf3.exams e ON e.exam_id = p.exam_id;

COMMIT;

-- Контроль количества загруженных записей.
SELECT 'hub_student' AS table_name, COUNT(*) AS rows_loaded
FROM dv.hub_student
UNION ALL SELECT 'hub_subject', COUNT(*) FROM dv.hub_subject
UNION ALL SELECT 'hub_exam', COUNT(*) FROM dv.hub_exam
UNION ALL SELECT 'hub_step', COUNT(*) FROM dv.hub_step
UNION ALL SELECT 'lnk_exam_subject', COUNT(*) FROM dv.lnk_exam_subject
UNION ALL SELECT 'lnk_exam_step', COUNT(*) FROM dv.lnk_exam_step
UNION ALL SELECT 'lnk_student_exam', COUNT(*) FROM dv.lnk_student_exam
UNION ALL SELECT 'lnk_student_step', COUNT(*) FROM dv.lnk_student_step
UNION ALL SELECT 'sat_student', COUNT(*) FROM dv.sat_student
UNION ALL SELECT 'sat_subject', COUNT(*) FROM dv.sat_subject
UNION ALL SELECT 'sat_exam', COUNT(*) FROM dv.sat_exam
UNION ALL SELECT 'sat_step', COUNT(*) FROM dv.sat_step
UNION ALL SELECT 'sat_student_exam', COUNT(*) FROM dv.sat_student_exam
UNION ALL SELECT 'sat_student_step', COUNT(*) FROM dv.sat_student_step
ORDER BY table_name;
