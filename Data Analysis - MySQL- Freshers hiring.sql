create database analysis_of_freshers_hiring;
use analysis_of_freshers_hiring;
select * from freshers_hiring_india_dataset;

-- Business Insights
/* Q1. Show the companies where the candidates with backlogs were hired the most than the candidates 
	   with no backlogs and rank those companies.*/
select company_applied, arrear_candidates, no_arrear_candidates,
arrear_candidates - no_arrear_candidates as difference,
dense_rank() over(order by arrear_candidates desc) as d_rank
from
(select e.company_applied, count(candidate_id) as arrear_candidates, t.no_arrear_candidates
from freshers_hiring_india_dataset e
join
(select company_applied, count(candidate_id) as no_arrear_candidates
from freshers_hiring_india_dataset
where hiring_stage = "Offer" and backlogs = 0
group by company_applied) as t
on e.company_applied = t.company_applied
where hiring_stage = "Offer" and backlogs > 0
group by e.company_applied) as subquery
where arrear_candidates > no_arrear_candidates
order by d_rank;
-- BigBasket hired the most number of candidates with backlogs than the candidates with no backlogs compared to other companies.

-- Q2. show the colleges with high average CGPA and high backlogs .How many candidates are from those colleges?
select college, avg_cgpa, cgpa_rank, avg_arrears, arrears_rank
from
(select college, round((avg(cgpa)),2) as avg_cgpa, round((avg(backlogs)),0) as avg_arrears,
count(candidate_id) as total_students,
dense_rank() over(order by avg(cgpa) desc) as cgpa_rank,
dense_rank() over(order by avg(backlogs) desc) as arrears_rank
from freshers_hiring_india_dataset
group by college) as subquery
where cgpa_rank <= 5 and arrears_rank <= 5
order by college;
-- There are no such colleges where both average CGPA and average backlogs are high.

/* Q3. Show the number of days a company takes to respond and the salary they offer? 
       Show the companies which respond quickly and offers high salary.*/
select company_applied, avg_response_time, response_time_rank, avg_salary, salary_rank
from 
    (select company_applied, 
            round((avg(response_time_days)),0) as avg_response_time,
            round((avg(cast(nullif(offered_salary_inr, "Not Available") as decimal(10,2)))),2) as avg_salary,
            dense_rank() over (order by avg(cast(nullif(offered_salary_inr, "Not Available") as decimal(10,2))) desc) as salary_rank,
			dense_rank() over(order by  round((avg(response_time_days)),0) ) as response_time_rank
     from freshers_hiring_india_dataset
     group by company_applied) as subquery
where response_time_rank <= 5 and  salary_rank <= 5
order by response_time_rank;
-- Fractal Analytics, Absolutdata, Tata Steel, Cognizant are the companies which respond quickly and offer high salary.

-- Q4. show the average salary and average CGPA of the students of IIT institutes and classify their salary as high and low.

select college, avg_cgpa, avg_salary,
	   if(avg_salary > (select avg(cast(nullif(offered_salary_inr, "Not Available") as decimal(10,2))) 
                        from freshers_hiring_india_dataset),"High","Low") as classification
from
    (select college,
			round((avg(cgpa)),2) as avg_cgpa, 
            round((avg(cast(nullif(offered_salary_inr, "Not Available") as decimal(10,2)))),2) as avg_salary
            from freshers_hiring_india_dataset
            where college like "IIT%" 
            and 
            hiring_stage = "Offer"
            group by college) as subquery
order by college;

-- Q5. show the top 3 job platform where companies choose most of the candidates from.
select company_applied, job_application_platform, total_candidates, job_app_rank
from
     (select company_applied, job_application_platform , 
             count(candidate_id) as total_candidates,
             dense_rank() over(partition by company_applied order by count(candidate_id) desc) as job_app_rank
	  from freshers_hiring_india_dataset
      where hiring_stage != "applied"
      group by company_applied, job_application_platform) as subquery
where  job_app_rank <= 3
order by company_applied, job_app_rank ;

-- Q6. show how many candidates have very strong and moderate profile and candidates those who have to improve their profile.
select
case
    when cgpa >= 8.5 and backlogs = 0 and prior_internship = "yes" and skill_set_count >= 6 and profile_completion_pct >= 90 
         and linkedin_connections >= 100 and referral_applied = "yes" then "very strong"
    when cgpa between 7.5 and 8.4 and skill_set_count between 3 and 5 and profile_completion_pct between 80 and 89 
		 and linkedin_connections between 50 and 99 then "moderate"
    else "Needs Improvement"
end as classification,
count(candidate_id) as total_candidates
from freshers_hiring_india_dataset
group by classification;
 /*There only 3 candidates who have a very strong profile and all the remaining candidates fall under "Needs Improvement" 
   category. No candidates fall under the "Moderate" category.*/
   
-- Q7. Create a function to classify the companies.
delimiter $$
create function company_classification(salary decimal(10,2), response_days int)
returns varchar(20)
deterministic
begin
     if salary is null then 
        return null;
	end if;
    return case
                when salary > 1000000 and response_days <= 5 then "Very Good"
			    when salary > 500000  and response_days <= 15 then "Good"
                when salary > 80000 and response_days <= 35 then "moderate"
                else "Not good"
	end;
end $$
delimiter ;

select company_applied,  offered_salary_inr, response_time_days,
company_classification((cast(nullif(offered_salary_inr,"Not Available") as decimal(10,2))), response_time_days) as classification 
from freshers_hiring_india_dataset;

-- Q8. Create a stored procedure to view the important aspects to get hired
delimiter **
create procedure candidate_details(qualification varchar(10), graduated_year int,referral varchar(5), 
                                    projects_and_certificates int, internship varchar(5))
begin
    select * from freshers_hiring_india_dataset 
    where 
         degree = qualification and
         graduation_year > graduated_year and
         referral_applied = referral and
         skill_set_count > projects_and_certificates and
         prior_internship = internship;
end**
delimiter ;

call candidate_details("B.E.", 2023, "Yes", 5, "Yes");

-- Q9. Show the number of female and male candidates got hired
select count(case when gender = "Female" then 1 end) as female_candidates,
count(case when gender = "Male" then 1 end) as male_candidates
from freshers_hiring_india_dataset 
where hiring_stage = "Offer";

-- 123 female candidates and 194 male candidates were hired during the period 2021-2024.

/*Q10. Compare candidates with and without prior internships. For each group, calculate:
Total number of candidates, average CGPA, average number of projects, average number of certifications
Then determine which internship group has the higher percentage of candidates who reached the final hiring stage.*/

select e.prior_internship, 
count(e.candidate_id) as hired_candidates,
t.total_candidates,
count(e.candidate_id) * 100/t.total_candidates as percentage,
t.avg_cgpa, t.avg_projects, t.avg_certificates
from freshers_hiring_india_dataset e
join
(select prior_internship, 
        count(candidate_id) as total_candidates, 
        round((avg(cgpa)),2) as avg_cgpa, round((avg(projects_count)),0) as avg_projects, 
        round((avg(certifications_count)),0) as avg_certificates
from freshers_hiring_india_dataset
group by  prior_internship) as t
on e.prior_internship = t.prior_internship
where e.hiring_stage = "Offer"
group by e.prior_internship;
/*Percentage of hired candidates without prior internship experience is slightly higher than the percentage
 of hired candidates with prior internship experience*/
 
/*Q11. For each sector, rank the top 3 job locations by average offered salary. Exclude 
any location-sector combination with fewer than 5 candidates.*/

select sector, job_location, total_candidates, avg_salary, d_rank
from
(select sector, job_location, total_candidates, avg_salary,
dense_rank() over (partition by sector order by avg_salary desc) as d_rank 
from
(select sector, job_location, 
count(candidate_id) as total_candidates, 
round((avg(cast(nullif(offered_salary_inr, "Not Available")as decimal(10,2)))),2) as avg_salary 
from freshers_hiring_india_dataset
group by sector, job_location) as s
where total_candidates >= 5) as t
where d_rank <= 3
order by sector, d_rank;

/*Q12. Find all candidates who have a higher CGPA than the average CGPA of their own branch AND reached at least the 
"HR Interview" or "Offer" stage in the hiring process. Show their candidate_id, branch, cgpa, and hiring_stage.*/

select e.branch, e.candidate_id, e.cgpa, t.avg_cgpa, e.hiring_stage
from freshers_hiring_india_dataset e
join
(select branch, round((avg(cgpa)),2) as avg_cgpa
from freshers_hiring_india_dataset
group by branch) as t
on e.branch = t.branch
where (e.cgpa > t.avg_cgpa) 
and
(e.hiring_stage in ("HR Interview", "offer"));

/*Q13. Calculate the hiring success rate per job application platform — define "success" as hiring_stage = "Offer". 
Show platform name, total applicants, successful offers, and success percentage. Rank them by success rate.*/
select e.job_application_platform, count(e.candidate_id) as selected_candidates,
t.total_candidates,
round((count(e.candidate_id) * 100/t.total_candidates),2) as percentage,
dense_rank() over (order by round((count(e.candidate_id) * 100/t.total_candidates),2) desc) as success_rate
from freshers_hiring_india_dataset e
join
(select job_application_platform, count(candidate_id) as total_candidates
from freshers_hiring_india_dataset
group by job_application_platform) as t
on  e.job_application_platform =  t.job_application_platform
where e.hiring_stage = "offer"
group by e.job_application_platform
order by success_rate;
-- HackerEarth has the highest percent of success rate compared to other companies.

/*Q14. Among candidates who used referral to apply, calculate what percentage got an "Offer" in each sector. 
Compare this with the non-referral offer percentage in the same sector. Show both percentages and the difference.*/

select sector, selected_by_reference, selected_by_no_reference, referred_candidates, no_referral_candidates, 
round((selected_by_reference * 100/ referred_candidates ),2) as selected_by_reference_pct,
round((selected_by_no_reference * 100/ no_referral_candidates),2) as selected_by_no_reference_pct,
selected_by_no_reference - selected_by_reference  as difference
from
(select sector, count(case when referral_applied = "Yes" and  hiring_stage = "Offer" then 1 end) as selected_by_reference,
	             count(case when referral_applied = "No" and  hiring_stage = "Offer" then 1 end) as selected_by_no_reference,
				 count(case when referral_applied = "Yes" then 1 end) as referred_candidates,
                 count(case when referral_applied = "No" then 1 end) as no_referral_candidates
from freshers_hiring_india_dataset 
group by sector) as subquery
order by sector;

/*Q15. Identify candidates who have zero backlogs, more than 3 certifications, and a career_gap of 0 — but are still in 
"Rejected" or "Applied" hiring stage. Count them per branch and rank branches by this count.*/
select branch, count(candidate_id) as total_candidates,
dense_rank() over(order by count(candidate_id) desc) as d_rank
from freshers_hiring_india_dataset 
where hiring_stage in ("Applied", "Rejected") and backlogs = 0 and certifications_count > 3 and  career_gap = 0
group by branch
order by  d_rank;
-- Computer Application branch has the most number of potential candidates who are still in "Rejected" or "Applied" stage.



