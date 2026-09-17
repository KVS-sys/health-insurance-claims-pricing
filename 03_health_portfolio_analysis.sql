SELECT plan_type , count(*) as grp_size , sum(claims_count)*1.0/ count(*) as claim_freq ,sum(total_claims_paid)*1.0 / sum(claims_count) as avg_claim_cost , sum(total_claims_paid)*1.0 / count(*) as payment_per_person
from health_insurance
group by plan_type;

-- loss ratio 
SELECT plan_type , count(*) as grp_size, sum(total_claims_paid) as total_claim_payments ,  sum(annual_premium) as total_annual_premium , round(sum( total_claims_paid)*100.0/ nullif(sum(annual_premium),0),2)as loss_ratio
from health_insurance
group by plan_type;

-- Risk via smoking status

SELECT smoker ,count(*) as grp_size , round(count(case when claims_count >0 then 1 end)*100.0 /count(*) ,2) as claimant_pct ,round(sum(claims_count)*1.0/ count(*),2) as claim_per_person , round(sum(total_claims_paid)*1.0 /count(*) ,2) as payment_per_person , round( sum(total_claims_paid)*100.0 /NULLIF(SUM(annual_premium), 0) , 2) as loss_ratio , ROUND(
    SUM(total_claims_paid) * 1.0 / NULLIF(SUM(claims_count), 0), 2) AS paid_per_claim
from health_insurance
group by smoker;

-- Analysis base
SELECT * , case WHEN claims_count > 0 then 1  else  0 END as has_claim 
FROM health_insurance
LIMIT 10;

-- Saviing the base
CREATE VIEW health_analysis_base AS
SELECT * , case WHEN claims_count > 0 then 1  else  0 END as has_claim 
FROM health_insurance;

SELECT *
FROM health_analysis_base
LIMIT 10;