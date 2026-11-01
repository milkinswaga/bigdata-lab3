BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL DateStyle TO 'ISO, YMD';

-- Изменяем текущее состояние в источнике 3NF.
-- Условие по статусу предотвращает повторное изменение
-- времени завершения при повторном запуске скрипта.
UPDATE nf3.step_progress p
SET status = 'done',
    score = 95,
    completed_at = CURRENT_TIMESTAMP,
    notes = 'Практические задания выполнены. Самопроверка: 95 баллов.'
FROM nf3.students s, nf3.exams e
WHERE s.student_id = p.student_id
  AND e.exam_id = p.exam_id
  AND s.student_number = 'ST-001'
  AND e.exam_code = 'DB-2026-01'
  AND p.step_no = 3
  AND p.status = 'in_progress';

-- Читаем текущие состояния шагов из источника.
WITH source_rows AS (
    SELECT dv.hk('student_step', s.student_number,
                 e.exam_code, p.step_no::TEXT) AS link_hk,
           dv.hk('sat_student_step', p.status, p.score::TEXT,
                 EXTRACT(EPOCH FROM p.completed_at)::TEXT,
                 p.notes) AS hashdiff,
           p.status, p.score, p.completed_at, p.notes
    FROM nf3.step_progress p
    JOIN nf3.students s ON s.student_id = p.student_id
    JOIN nf3.exams e ON e.exam_id = p.exam_id
)
-- Добавляем только новые или изменившиеся состояния.
-- Существующие версии Data Vault не обновляем и не удаляем.
INSERT INTO dv.sat_student_step (
    link_hk, record_source, hashdiff,
    status, score, completed_at, notes
)
SELECT src.link_hk, 'nf3', src.hashdiff,
       src.status, src.score, src.completed_at, src.notes
FROM source_rows src
LEFT JOIN LATERAL (
    SELECT sat.hashdiff
    FROM dv.sat_student_step sat
    WHERE sat.link_hk = src.link_hk
    ORDER BY sat.load_dts DESC
    LIMIT 1
) latest ON TRUE
WHERE latest.hashdiff IS DISTINCT FROM src.hashdiff;

COMMIT;

-- Показываем историю третьего шага.
SELECT s.student_number,
       st.step_no,
       to_char(
           sat.load_dts AT TIME ZONE 'Europe/Moscow',
           'YYYY-MM-DD HH24:MI:SS'
       ) AS loaded_msk,
       sat.status,
       sat.score,
       sat.record_source
FROM dv.lnk_student_step l
JOIN dv.hub_student s ON s.student_hk = l.student_hk
JOIN dv.hub_exam e ON e.exam_hk = l.exam_hk
JOIN dv.hub_step st ON st.step_hk = l.step_hk
JOIN dv.sat_student_step sat ON sat.link_hk = l.link_hk
WHERE s.student_number = 'ST-001'
  AND e.exam_code = 'DB-2026-01'
  AND st.step_no = 3
ORDER BY sat.load_dts;
