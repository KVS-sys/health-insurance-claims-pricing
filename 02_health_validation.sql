-- 1 record integrity
SELECT count(*)  as total_rows , count(distinct(person_id)) as unique_poeple , (SELECT count(*)  as missing_ids from health_insurance WHERE person_id is null) as missing_ids ,COUNT(person_id) - COUNT(DISTINCT person_id) AS duplicate_extra_rows
FROM health_insurance ;

--2 Missing financial data 
SELECT count(case when claims_count is null then 1 end ) as missing_claims_count , count(case when total_claims_paid is null then 1 end) as missing_total_claims_paid , count(case when annual_premium is null then 1 end) as missing_annual_premium
from health_insurance;


-- 3 checking claim counts 
SELECT count(case when claims_count < 0  OR claims_count != CAST(claims_count AS INTEGER) then 1 END) as invalid_claims_counts
from health_insurance;


-- 4 checking finacial values 
SELECT count(case when total_claims_paid < 0 then 1 END) as neg_total_claims_paid , count(case when annual_medical_cost < 0 then 1 END)  as neg_medical_cost , count(case when annual_premium < 0 then 1 END) as neg_annual_premium
FROM health_insurance;

-- 5 checking premium consistency
SELECT count(case when abs( annual_premium - 12* monthly_premium) >0.12 then 1 end) as inconsistent_premiums
from health_insurance;

--6 checking claim_payment consistency
SELECT count(case when claims_count =0 and total_claims_paid > 0 then 1 end) as payments_without_claims , count(case when claims_count >0 and total_claims_paid = 0 then 1 end ) as positive_claims_zero_paid
from health_insurance;

-- 7 checking financial fields for missing values 
select count(case when annual_medical_cost is null then 1 end) as missing_annual_medical_cost , count(case when monthly_premium  is null then 1 end ) as missing_monthly_premium , count( case when avg_claim_amount is null then 1 end) as missing_avg_claim_amount
FROM health_insurance;


-- 8 checking claim amount consisitency
select count(case when abs(claims_count*avg_claim_amount - total_claims_paid) > 0.005*claims_count +0.01 then 1 end) as inconsistent_claim_amount
FROM health_insurance;

--9 checking demographic and policy values 
SELECT count(case when age is null or age < 0 then 1 end) as invalid_age , count(case WHEN policy_term_years <= 0 or policy_term_years is null then 1 end) as invalid_policy_term_years , count(case when plan_type is null then 1 end) as invalid_plan_type
from health_insurance;


select distinct(policy_term_years) , count(*)
from health_insurance
group by policy_term_years