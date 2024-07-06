-- 2 July 2024 
/* Question 2 

You're working for a large healthcare tech company that manages patient data across multiple hospitals. The company also has a research division that analyzes anonymized patient data. You're tasked with creating a query to support a new research initiative on chronic disease management.
You have the following tables:

patients (patient_id, birth_date, gender, zip_code)
visits (visit_id, patient_id, visit_date, hospital_id)
diagnoses (diagnosis_id, visit_id, icd_code, diagnosis_date)
medications (medication_id, patient_id, medication_code, start_date, end_date)
hospitals (hospital_id, hospital_name, state)

Write a SQL query that does the following:

Identifies patients who have been diagnosed 
with diabetes (ICD-10 code starting with 'E11') and hypertension (ICD-10 code starting with 'I10') in the same year.
For these patients, calculate the average time between their diabetes and hypertension diagnoses.
List the top 5 medications prescribed to these patients within 30 days after their hypertension diagnosis.
Include the count of visits these patients had in the following year, grouped by hospital state.
Only include patients who have had at least 3 visits in total.
Optimize the query for performance, considering that the database contains millions of records.

Your query should return the following columns:

Patient age group (0-18, 19-40, 41-60, 61+)
Gender
Average time between diabetes and hypertension diagnoses (in days)
Top 5 medications (medication_code)
Number of prescriptions for each of these medications
Total visits in the year following hypertension diagnosis
Hospital state

*/

-------------------------- First Attempt ----------------------------------------------------------------------------------
-- Questions when claude comes up, is the visit date same as diagnoses date? -- assuming different
-- What is the purpose of diagnosis id other than just denoting a unique id -- discarded diagnosis id 
-- when you say the same year is it calendar year or one year anytime after diagnois ? -- assumed 365 days 
-- make sure the user knows that the age_group represents current age_group not historically 
-- How far back does this database go if it's million records ? this is something to optimize for by filtering
-- what if hypertensian diagnosed first and diabetes later, is it still considered?
--- assuming that each patient gets diagnosed only once for the disease ?
-- visits from the following year of hyper diagnosis or diabetes diagnoses ? -- assuming hyper tension

WITH diag_diab AS  -- Diabetes patients
(
SELECT DISTINCT  v.patient_id, d.diagnosis_date--, 'diabetes' as disease
FROM VISITS v --ON p.patient_id = v.patient_id
JOIN diagnoses d ON d.visit_id = v.visit_id AND d.icd_code LIKE 'E11%' 
),
diag_hyper AS  -- Hypertension patients 
(
SELECT DISTINCT v.patient_id, d.diagnosis_date --, 'hypetension' as disease
FROM VISITS v --ON p.patient_id = v.patient_id
JOIN diagnoses d ON d.visit_id = v.visit_id AND  d.icd_code LIKE 'I10%'
),
diag_pat_filter -- identfy patients with diab hyper within one year 
(
SELECT DISTINCT dbt.patient_id, -- we can take the first instance of both being diagnosed incase diagnosis is repeated
       dbt.diagnosis_date as diabdt,
       hyp.diagnosis_date as hypdate
FROM diag_diab dbt
JOIN diag_hyper hyp ON dbt.patient_id = hyp.patient_id 
                    AND ABS( DATEDIFF('months',dbt.diagnosis_date,hyp.diagnosis_date)) <= 12
),
medication_raw_rank -- top 5 medications per patient 
(
SELECT patient_id, 
       CASE WHEN med_rank = 1 then medication_code ELSE NULL END AS top_choice_1
       CASE WHEN med_rank = 2 then medication_code ELSE NULL END AS top_choice_2
       CASE WHEN med_rank = 3 then medication_code ELSE NULL END AS top_choice_3
       CASE WHEN med_rank = 4 then medication_code ELSE NULL END AS top_choice_4
       CASE WHEN med_rank = 5 then medication_code ELSE NULL END AS top_choice_5 
       CASE WHEN med_rank = 1 then count_prescription ELSE NULL END AS top_choice_1_count
       CASE WHEN med_rank = 2 then count_prescription ELSE NULL END AS top_choice_2_count
       CASE WHEN med_rank = 3 then count_prescription ELSE NULL END AS top_choice_3_count
       CASE WHEN med_rank = 4 then count_prescription ELSE NULL END AS top_choice_4_count
       CASE WHEN med_rank = 5 then count_prescription ELSE NULL END AS top_choice_5_count
    FROM (
        SELECT pat.patient_id,medication_code,count(medication_id) as count_prescription,
        -- Cant use RANK() here unless i have a tie breaking logic, this will be made to columns
        ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY count(medication_id) DESC ) AS med_rank,
        FROM medications med
        JOIN diag_pat_filter pat on pat.patient_id = med.patient_id
        WHERE start_date BETWEEN pat.hypdate and DATEADD(pat.hypdate,30,'days')
        GROUP BY medication_code,med.patient_id
    ) medi
    WHERE med_rank <= 5 
    ORDER BY patient_id,med_rank
),
med_ranked AS 
(
SELECT patient_id, 
       MAX(top_choice_1) as top_choice_1,
       MAX(top_choice_1_count) as top_choice_1_count
       MAX(top_choice_2) as top_choice_2,
       MAX(top_choice_2_count) as top_choice_2_count,
       MAX(top_choice_3) as top_choice_3,
       MAX(top_choice_3_count) as top_choice_3_count,
       MAX(top_choice_4) as top_choice_4,
       MAX(top_choice_4_count) as top_choice_4_count,
       MAX(top_choice_5) as top_choice_5,
       MAX(top_choice_5_count) as top_choice_5_count
)
,
patient_info AS  ---- All relevant fields for patient 
(
patient_id,
gender,
CASE WHEN YEAR(NOW())- YEAR(birth_date) BETWEEN 0 and 18 THEN '0-18'
     WHEN YEAR(NOW())- YEAR(birth_date) BETWEEN 19 and 40 THEN '19-40'
     WHEN YEAR(NOW())- YEAR(birth_date) BETWEEN 41 and 60 THEN '41-60'
     WHEN YEAR(NOW())- YEAR(birth_date) >60  THEN '61+'
END AS "Current_Age_Group"
)
, 
visits_info AS 
(
SELECT visi.patient_id, COUNT(DISTINCT visit_id) as visit_count
FROM visits visi
JOIN (Select distinct patient_id,hypdate from diag_pat_filter) as pati
ON visi.patient_id = pati.patient_id and visi.visit_date BETWEEN pati.hypdate and DATEADD(pat.hypdate,1,'year')
GROUP BY visi.patient_id
HAVING count(visi.patient_id)>3 
)
