USE readmission;

-- Q1: Overall 30-day readmission rate 
SELECT COUNT(1) AS total_encounters,
       SUM(CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END) AS readmitted_30d,
       ROUND(AVG(CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END) * 100, 2) AS readmit_rate
FROM inpatient_encounters;

-- Q2: Readmission rate by discharge disposition
SELECT i.discharge_disposition_id, 
       d.description,
       COUNT(1) AS n,
       ROUND(AVG(i.readmitted = '<30') * 100, 2) AS readmit_rate
FROM inpatient_encounters i
JOIN discharge_disposition d
  ON i.discharge_disposition_id = d.discharge_disposition_id
GROUP BY i.discharge_disposition_id, d.description
ORDER BY n DESC;