USE readmission;

-- ============================================================
-- Q1: Overall 30-day readmission rate 
-- ============================================================
SELECT COUNT(1) AS total_encounters,
       SUM(CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END) AS readmitted_30d,
       ROUND(AVG(CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END) * 100, 2) AS readmit_rate
FROM inpatient_encounters;

-- ============================================================
-- Q2: Readmission rate by discharge disposition
-- Purpose: justify excluding death/hospice discharges
--          (codes 11, 13, 14, 19, 20, 21)
-- ============================================================
SELECT i.discharge_disposition_id, 
       d.description,
       COUNT(1) AS n,
       ROUND(AVG(i.readmitted = '<30') * 100, 2) AS readmit_rate
FROM inpatient_encounters i
JOIN discharge_disposition d
  ON i.discharge_disposition_id = d.discharge_disposition_id
GROUP BY i.discharge_disposition_id, d.description
ORDER BY n DESC;

-- ============================================================
-- Q3: Row counts before and after cleaning    
-- Step 1: keep only the first encounter per patient
-- Step 2: exclude death/hospice discharges
-- ============================================================
WITH ranked AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY patient_nbr ORDER BY encounter_id) AS rn
  FROM inpatient_encounters
)
SELECT
  (SELECT COUNT(1) FROM inpatient_encounters) AS raw_rows,
  COUNT(1) AS step1_first_encounter_only,
  SUM(discharge_disposition_id IN (11,13,14,19,20,21)) AS step2_excluded_death_hospice,
  SUM(discharge_disposition_id NOT IN (11,13,14,19,20,21)) AS step2_final_rows
FROM ranked
WHERE rn = 1;


-- ============================================================
-- Analysis table: one row per patient, death/hospice excluded
-- All later analysis uses this table
-- ============================================================
CREATE TABLE analysis_base AS
WITH ranked AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY patient_nbr ORDER BY encounter_id) AS rn
  FROM inpatient_encounters
)
SELECT *
FROM ranked
WHERE rn = 1
  AND discharge_disposition_id NOT IN (11,13,14,19,20,21);


-- ============================================================
-- Q4: Overall 30-day readmission rate after cleaning
-- ============================================================
SELECT COUNT(*) AS total_encounters,
       SUM(readmitted = '<30') AS readmitted_30d,
       ROUND(AVG(readmitted = '<30') * 100, 2) AS readmit_rate
FROM analysis_base;  