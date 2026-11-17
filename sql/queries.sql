USE readmission;

-- ============================================================
-- Q1: Overall 30-day readmission rate (before cleaning)
-- ============================================================
SELECT COUNT(1) AS total_encounters,
       SUM(CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END) AS readmitted_30d,
       ROUND(AVG(CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END) * 100, 2) AS readmit_rate
FROM inpatient_encounters;

-- ============================================================
-- Q2: Check how many encounters belong to repeat patients
-- ============================================================
SELECT COUNT(*) AS total_encounters,
       COUNT(DISTINCT patient_nbr) AS unique_patients
FROM inpatient_encounters;

-- ============================================================
-- Q3: Readmission rate by discharge disposition
-- Purpose: verify whether death/hospice discharges behave differently
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
-- Q4: Row counts before and after cleaning    
-- Step 1: keep only the first encounter per patient
-- Step 2: exclude death/hospice discharges
-- Purpose: check that cleaning matches the paper (final n = 69,984 in Strack et al.)
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
-- Q5: Overall 30-day readmission rate after cleaning
-- Reference: the original paper reports about 9.2% (6,459 / 69,984)
-- ============================================================
SELECT COUNT(*) AS total_encounters,
       SUM(readmitted = '<30') AS readmitted_30d,
       ROUND(AVG(readmitted = '<30') * 100, 2) AS readmit_rate
FROM analysis_base;  

-- ============================================================
-- Q6: Readmission by discharge type (home vs other), following the paper's Table 3
-- Reference: the original paper reports about 7.2% vs 12.8% 
-- ============================================================
SELECT CASE WHEN discharge_disposition_id = 1 THEN 'Home' ELSE 'Other' END AS discharge_group,
       COUNT(*) AS n,
       ROUND(AVG(readmitted = '<30') * 100, 1) AS readmit_rate
FROM analysis_base
GROUP BY discharge_group;

-- ============================================================
-- Q7: Readmission by age group (<30, 30-60, 60+), following the paper
-- Reference: the original paper reports about 6.2% / 7.4% / 10.2%
-- ============================================================
SELECT CASE WHEN age IN ('[0-10)','[10-20)','[20-30)') THEN '1 - under 30'
            WHEN age IN ('[30-40)','[40-50)','[50-60)') THEN '2 - 30 to 60'
            ELSE '3 - 60 plus' END AS age_group,
       COUNT(*) AS n,
       ROUND(AVG(readmitted = '<30') * 100, 1) AS readmit_rate
FROM analysis_base
GROUP BY age_group
ORDER BY age_group;

-- ============================================================
-- Q8: Readmission by primary diagnosis (ICD-9 groups from the Table 2)
-- Note: only diabetes codes (250.xx) contain decimals, so BETWEEN is safe.
--       V/E codes convert to 0 and fall into 'Other', as in the paper.
-- ============================================================
WITH d AS (
  SELECT readmitted, FLOOR(CAST(diag_1 AS DECIMAL(6,2))) AS dx
  FROM analysis_base
)
SELECT CASE WHEN dx = 250 THEN 'Diabetes'
            WHEN dx BETWEEN 140 AND 239 THEN 'Neoplasms'
            WHEN dx BETWEEN 390 AND 459 OR dx = 785 THEN 'Circulatory'
            WHEN dx BETWEEN 460 AND 519 OR dx = 786 THEN 'Respiratory'
            WHEN dx BETWEEN 520 AND 579 OR dx = 787 THEN 'Digestive'
			      WHEN dx BETWEEN 580 AND 629 OR dx = 788 THEN 'Genitourinary'
            WHEN dx BETWEEN 710 AND 739 THEN 'Musculoskeletal'
            WHEN dx BETWEEN 800 AND 999 THEN 'Injury'
            ELSE 'Other' 
		  END AS diag_group,
      COUNT(*) AS n,
      ROUND(AVG(readmitted = '<30') * 100, 1) AS readmit_rate
FROM d
GROUP BY diag_group
ORDER BY n DESC;

-- ============================================================
-- Q9: Readmission by HbA1c testing 
-- 'Normal' = A1Cresult 'Norm' or '>7' (i.e., below 8%); 
-- ============================================================
SELECT CASE WHEN A1Cresult = 'Untested'  THEN '1_No test'
            WHEN A1Cresult = '>8' AND `change` = 'Ch'  THEN '2_High, med changed'
            WHEN A1Cresult = '>8' AND `change` = 'No'  THEN '3_High, med not changed'
            ELSE '4_Normal (Norm or >7)'
       END AS hba1c_group,
       COUNT(*) AS n,
       ROUND(AVG(readmitted = '<30') * 100, 1) AS readmit_rate
FROM analysis_base
GROUP BY hba1c_group
ORDER BY hba1c_group;

-- ============================================================
-- Q10: Readmission by gender (paper: Female 9.3%, Male 9.2%
-- ============================================================
SELECT gender, COUNT(*) AS n,
       ROUND(AVG(readmitted = '<30') * 100, 1) AS readmit_rate
FROM analysis_base
GROUP BY gender;

-- ============================================================
-- Q11: Readmission by race 
-- Asian, Hispanic, Other are combined into 'Other' to match the paper's grouping
-- ============================================================
SELECT CASE WHEN race = 'AfricanAmerican' THEN 'African American'
            WHEN race = 'Caucasian'       THEN 'Caucasian'
            WHEN race = 'Unknown'         THEN 'Missing'
            ELSE 'Other' 
       END AS race_group,
       COUNT(*) AS n,
       ROUND(AVG(readmitted = '<30') * 100, 1) AS readmit_rate_pct
FROM analysis_base
GROUP BY race_group;

-- ============================================================
-- Q12: Readmission by admission source 
-- Assumption: referral = codes 1, 2, 3 (checked against the paper's n=22,800)
-- ============================================================
SELECT CASE WHEN admission_source_id = 7 THEN 'Emergency room'
            WHEN admission_source_id IN (1,2,3) THEN 'Physician/clinic referral'
            ELSE 'Otherwise' 
       END AS admission_group,
       COUNT(*) AS n,
       ROUND(AVG(readmitted = '<30') * 100, 1) AS readmit_rate_pct
FROM analysis_base
GROUP BY admission_group;

