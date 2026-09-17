--Inspect the health-insurance data 
SELECT * 
FROM health_insurance
LIMIT 10;

--  checking count of people and records
SELECT count(*) AS total_rows , count(DISTINCT(person_id)) as unique_people
from health_insurance ;

-- COLUMN NAMES	
PRAGMA table_info(health_insurance) ;

-- summarise claim payments
SELECT round(sum(total_claims_paid), 2) as total_paid ,round(avg(total_claims_paid),2) as average_paid_per_person , round(min(total_claims_paid),2) as minimum_paid , round(max(total_claims_paid),2) as maximum_paid
FROM health_insurance;

--Looking at zero claim amount and count
SELECT  claims_count
FROM health_insurance
WHERE total_claims_paid = 0
order by claims_count desc;

SELECT total_claims_paid
FROM health_insurance
WHERE claims_count = 0
order by total_claims_paid DESC;

--