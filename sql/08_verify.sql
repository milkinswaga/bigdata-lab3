BEGIN;

-- Текущее состояние подготовки в модели 3NF.
CREATE OR REPLACE VIEW nf3.v_step_progress_current AS
SELECT s.student_number,
       e.exam_code,
       st.step_no,
       st.step_title,
       p.status,
       p.score,
       p.completed_at,
       p.notes
FROM nf3.step_progress p
JOIN nf3.students s ON s.student_id = p.student_id
JOIN nf3.exams e ON e.exam_id = p.exam_id
JOIN nf3.preparation_steps st
  ON st.exam_id = p.exam_id AND st.step_no = p.step_no;

-- Текущее состояние в Data Vault собираем только из его таблиц.
-- Для каждого родителя выбираем последнюю версию сателлита.
CREATE OR REPLACE VIEW dv.v_step_progress_current AS
SELECT s.student_number,
       e.exam_code,
       st.step_no,
       descr.step_title,
       progress.status,
       progress.score,
       progress.completed_at,
       progress.notes
FROM dv.lnk_student_step l
JOIN dv.hub_student s ON s.student_hk = l.student_hk
JOIN dv.hub_exam e ON e.exam_hk = l.exam_hk
JOIN dv.hub_step st ON st.step_hk = l.step_hk
JOIN LATERAL (
    SELECT sat.*
    FROM dv.sat_student_step sat
    WHERE sat.link_hk = l.link_hk
    ORDER BY sat.load_dts DESC
    LIMIT 1
) progress ON TRUE
JOIN LATERAL (
    SELECT sat.step_title
    FROM dv.sat_step sat
    WHERE sat.step_hk = l.step_hk
    ORDER BY sat.load_dts DESC
    LIMIT 1
) descr ON TRUE;

COMMENT ON VIEW nf3.v_step_progress_current IS
    'Текущее состояние шагов подготовки в модели 3NF';
COMMENT ON VIEW dv.v_step_progress_current IS
    'Текущее состояние шагов по последним версиям Data Vault';

COMMIT;

-- Ожидаем 5 текущих записей в каждой модели и 6 версий в истории.
SELECT
    (SELECT COUNT(*) FROM nf3.v_step_progress_current) AS nf3_rows,
    (SELECT COUNT(*) FROM dv.v_step_progress_current) AS dv_current_rows,
    (SELECT COUNT(*) FROM dv.sat_student_step) AS dv_history_rows;

-- Двустороннее сравнение всех столбцов текущего состояния.
-- EXCEPT ALL учитывает также различия в количестве одинаковых строк.
WITH differences AS (
    (
        SELECT * FROM nf3.v_step_progress_current
        EXCEPT ALL
        SELECT * FROM dv.v_step_progress_current
    )
    UNION ALL
    (
        SELECT * FROM dv.v_step_progress_current
        EXCEPT ALL
        SELECT * FROM nf3.v_step_progress_current
    )
)
SELECT COUNT(*) AS differences_found
FROM differences;

SELECT step_no, step_title, status, score
FROM dv.v_step_progress_current
WHERE student_number = 'ST-001'
  AND exam_code = 'DB-2026-01'
ORDER BY step_no;
