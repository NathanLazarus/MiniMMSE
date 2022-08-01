/****************************************************************************
Project: TN Aging
Purpose: Create official merged dataset of BL and WL
Author: Erin Grela 
Date created: August 4 2021 
Last modified: April 4 2021 (EG)
****************************************************************************/

/*	Notes:
		
		This do file creates a merged dataset from the BL 
		data and the wave 1 data. It has statuses for all
		respondents at both surveys as well as "official"
		demographics that draw on all sources of data. 
	
	                                                   */
													   
clear all											 	   
set more off
pause on 

/**************************************************************
Set seed and macros
**************************************************************/	

	*User 
	if "`c(username)'"=="eringrela" {
		gl user "/Users/eringrela/Dropbox (MIT)"
	}
	else if "`c(username)'"=="madelinemckelway" {
		gl user "/Users/madelinemckelway/Dropbox (MIT)/tamil nadu aging"
	}
	if "`c(username)'"=="Sohaib" {
		gl user "D:/Dropbox"
	}
	else if "`c(username)'"=="Sohaib Nasim" {
		gl user "C:/Users/Sohaib Nasim/Dropbox"
	}	
	
/**************************************************************
Load baseline data 
**************************************************************/

*rename BL vars
use "$user/Tamil Nadu Aging/Data/Baseline/2. Final Cleaned Data/All_Survey_Merge_Weighted.dta", clear 

ren *elderly_* *eld*
ren *health_care* *health*
ren *visitng_teatmnts* *vist_treatmnt*
ren *financial_supprt* *financial_sup*
ren *maligancy_signs* *malignan*
ren * B_* // This increases the length of the var names. 15 original names would be invalid hence the changes above
ren B_q010_1_elder_id q010_1_elder_id



/**************************************************************
Merge in wave 1 data 
**************************************************************/

*merge in wave 1 data 
*first the statuses (including incomplete)
preserve

use "$user/Tamil Nadu Aging/Data/Wave_1/2. Final Cleaned Data/Full_Ind_DES.dta", clear
egen q010_1_elder_id = sieve(calc_elder_id), omit("_")

keep q010_1_elder_id q9_011_1_surv_status q9_011_2_comments
rename q9_011_1_surv_status W1_full_status
rename q9_011_2_comments W1_full_comments

tempfile w1_statuses
save `w1_statuses'

restore

merge 1:1 q010_1_elder_id using `w1_statuses'
drop if _merge==2 
drop _merge

preserve

use "$user/Tamil Nadu Aging/Data/Wave_1/2. Final Cleaned Data/HH_Ind(Full)_Merged.dta", clear

egen q010_1_elder_id = sieve(calc_elder_id), omit("_")

rename *neurological* *neur*
rename *limittns* *lim*
rename *visitng* *vst*
rename *health_care* *hlthcr*
rename *financial* *fin*
rename *type_assis_req* *assis*
rename *elderly_pass_place_* *pass_loc*
rename *death_prime_rson* *dth_cause*

rename * w1_*

rename w1_q010_1_elder_id q010_1_elder_id

tempfile wave_1
save `wave_1'

restore

merge 1:1 q010_1_elder_id using `wave_1'
drop if _merge==2 
drop _merge

/**************************************************************
Deaths survey 
**************************************************************/

*merge in deaths survey 
preserve

use "$user/Tamil Nadu Aging/Data/2020 Coronavirus Phone Survey/2.Cleaned Data/Deceased Elderly/Deceased_elderly_cleaned.dta", clear

egen q010_1_elder_id = sieve(pt_id), omit("_")

rename * D_*

rename D_q010_1_elder_id q010_1_elder_id

tempfile deaths
save `deaths'

restore

merge 1:1 q010_1_elder_id using `deaths'
drop if _merge==2 // because only those surveyed at bL were surveyed at w1
drop _merge

/**************************************************************
RCT statuses
**************************************************************/

*Counseling RCT 
merge 1:1 q010_1_elder_id using "$user/Loneliness Intervention/3. Data/3. Intervention/0. Pre-intervention work/wave_1_treatments.dta", keepusing(treatment_string)
drop if _merge==2 
drop _merge 
gen Lone_RCT_treat = treatment_string
drop treatment_string
merge 1:1 q010_1_elder_id using "$user/Loneliness Intervention/3. Data/3. Intervention/0. Pre-intervention work/wave_2_treatments.dta", keepusing(treatment_string)
drop if _merge==2 
drop _merge 
replace Lone_RCT_treat = treatment_string if treatment_string!=""
drop treatment_string
merge 1:1 q010_1_elder_id using "$user/Loneliness Intervention/3. Data/3. Intervention/0. Pre-intervention work/wave_3_treatments.dta", keepusing(treatment_string)
drop if _merge==2 
drop _merge
replace Lone_RCT_treat = treatment_string if treatment_string!=""
drop treatment_string


*OAP RCT
rename q010_1_elder_id elder_id 
merge 1:1 elder_id using "$user/Tamil Nadu Aging/Data/OAP Related/oap_rnd_individual.dta", keepusing(treat)
drop if _merge==2 // because only those surveyed at bL were surveyed at w1, this excludes 84 
drop _merge
rename treat OAP_RCT_treatment

rename B_ELA ELA_at_BL
rename B_oap_sample OAP_at_BL


/**************************************************************
Statuses and mortality 
**************************************************************/	

*surveyed // all people in this sample were surveyed at BL 
*one-off fixes come from comments from surveyors 
gen surveyed_BL = 0 
replace surveyed_BL = 1 if B_q0_22_status_code==1 

gen status_BL = "Surveyed"

gen surveyed_w1 = 0 
replace surveyed_w1 = 1 if w1_q9_011_1_surv_status==1 


gen deceased_w1 = 0 
replace deceased_w1 = 1 if W1_full_status==. // those not in the w1 sample frame but in the bl survey had died 
replace deceased_w1= 1 if D_h_status_call==1 | W1_full_status==4 
replace deceased_w1= 1 if elder_id=="163064327922401"
replace deceased_w1= 1 if elder_id=="163064350417003"
replace deceased_w1 = 0 if surveyed_w1==1


*Extreme refusals 
preserve 
use "$user/Tamil Nadu Aging/Data/General Panel/Extreme Refusal Cases - TNAGE.dta", clear
egen elder_id = sieve(pt_id), omit("_")
keep elder_id
tempfile refusals
save `refusals'
restore

merge 1:1 elder_id using `refusals'

gen refused_w1 = 0 
replace refused_w1= 1 if W1_full_status==3
replace refused_w1= 1 if elder_id=="60301152932521601"
replace refused_w1 =1 if _merge==3  & surveyed_w1!=1
drop _merge

gen not_found_w1 = 0 
replace not_found_w1= 1 if W1_full_status==2
replace not_found_w1= 1 if elder_id=="60611170010833101"
replace not_found_w1= 1 if elder_id=="62957170010731902"
replace not_found_w1= 1 if elder_id=="63021150010622601"
replace not_found_w1= 1 if elder_id=="61412150012510202"
replace not_found_w1= 1 if elder_id=="60619170010413801"
replace not_found_w1= 1 if elder_id=="62936170162023901"
replace not_found_w1= 1 if elder_id=="160663119924502"
replace not_found_w1= 1 if elder_id=="162964314915301"
replace not_found_w1= 1 if elder_id=="63009170011315801"
replace not_found_w1= 1 if elder_id=="60301151332231401"
replace not_found_w1= 1 if elder_id=="62931170011224301"

gen migrated_w1 = 0 
replace migrated_w1= 1 if W1_full_status==5
replace migrated_w1= 1 if elder_id=="161463598611701"
replace migrated_w1= 1 if elder_id=="161463585317102"


*hh statuses for missing remaining ones 
rename B_q0_8_1_hh_id hh_id 
preserve
use "$user/Tamil Nadu Aging/Data/Wave_1/2. Final Cleaned Data/Full_HH.dta", clear
egen hh_id = sieve(q0_8_1_hh_id), omit("_")
keep q0_22_status_code* hh_id
tempfile hhs
save `hhs'
restore
merge m:1 hh_id using `hhs', keepusing(q0_22_status_code*)
drop if _merge==2 
drop _merge
rename q0_22_status_code hh_status 
rename q0_22_status_code_oth hh_status_reason

*individual fixes based on hh statuses 
replace not_found_w1 = 1 if hh_id=="629181700115121"
replace migrated_w1 = 1 if hh_id=="630211500106376"
replace refused_w1 = 1 if hh_id=="1606632120215"
replace deceased_w1 = 1 if elder_id=="161463572720201"
replace deceased_w1 = 1 if elder_id=="263064343116601" // from lone RCT deaths survey 


gen status_w1 = "Surveyed" if surveyed_w1==1
replace status_w1 = "Deceased" if deceased_w1==1
replace status_w1 = "Refused" if refused_w1==1
replace status_w1 = "Not found" if not_found_w1==1
replace status_w1 = "Migrated" if migrated_w1==1
tab status_w1

/**************************************************************
Demographics 
**************************************************************/	

rename B_weight weight // this is the sampling weight 

gen ELA_at_w1 = 0 if surveyed_w1==1 
replace ELA_at_w1 = 1 if w1_q015_live_alone==1 

*gender 
rename B_gender gender 
replace gender = . if gender ==3 
replace gender = B_gender_health if gender==. 
// EDIT: when the wave 1 health data is digitized and shared, we should add that gender data source into this for the one person missing


*age 
gen age_at_BL = B_a3_1_age_ 
replace age_at_BL = . if age_at_BL<55
replace age_at_BL = B_age_health if age_at_BL==. & B_age_health>=55

*filling in age from the hh age roster based on hh id; there are only 55+ in up to elder 7 at all 

preserve 
use "$user/Tamil Nadu Aging/Data/Wave_1/2. Final Cleaned Data/DES_Ind_Profile_Matched.dta", clear 
egen elder_id = sieve(calc_elder_id), omit("_")
keep elder_id a3_1_age_ 
rename a3_1_age_ w1_a3_1_age_
tempfile ages_w1
save `ages_w1'
restore 

preserve 
use "$user/Tamil Nadu Aging/Data/Baseline/2. Final Cleaned Data/DES_Ind_Profile_Matched.dta", clear 
rename q010_1_elder_id elder_id
keep elder_id a3_1_age_ 
rename a3_1_age_ B_a3_1_age_
tempfile ages_bl
save `ages_bl'
restore 

merge 1:1 elder_id using `ages_w1'
drop _merge
merge 1:1 elder_id using `ages_bl'
drop _merge

replace age_at_BL = B_a3_1_age_ if age_at_BL==. & B_a3_1_age_>=55
replace age_at_BL = w1_a3_1_age_ - 3 if age_at_BL==. & w1_a3_1_age_>=58 

tab age_at_BL
// EDIT: when the wave 1 health data is digitized and shared, we should add that age data source into this for those still missing a numerical age 


*age category 
rename B_age_cat age_cat_at_BL
pause 
/**************************************************************
Depression 
**************************************************************/

*missings imputed from avg if up to two missing
*no proxy scores  
*BL
gen B_dep_missing = 0 
*calc number missing and nonmissing 
foreach var in B_q5_f1_satisfied B_q5_f2_activities B_q5_f3_empty_life B_q5_f4_bored B_q5_f5_good_spirit B_q5_f6_afraid B_q5_f7_feel_happy B_q5_f8_hopeless_feel B_q5_f9_stay_home B_q5_f10_more_problms B_q5_f11_wondrful B_q5_f12_pretty_wrthless B_q5_f13_full_energy B_q5_f14_hopeless_situation B_q5_f15_people_better {
	replace B_dep_missing = B_dep_missing + 1 if `var'==. 
	replace `var' = 0 if `var'==2
}

*flip positive vars 
foreach var in B_q5_f1_satisfied B_q5_f5_good_spirit B_q5_f7_feel_happy B_q5_f11_wondrful B_q5_f13_full_energy {
	replace `var' = 1 -`var'
}


gen B_dep_nonmiss = 15 - B_dep_missing
*calculate nonmmissing average
egen B_dep_nonmiss_tot = rowtotal(B_q5_f1_satisfied B_q5_f2_activities B_q5_f3_empty_life B_q5_f4_bored B_q5_f5_good_spirit B_q5_f6_afraid B_q5_f7_feel_happy B_q5_f8_hopeless_feel B_q5_f9_stay_home B_q5_f10_more_problms B_q5_f11_wondrful B_q5_f12_pretty_wrthless B_q5_f13_full_energy B_q5_f14_hopeless_situation B_q5_f15_people_better)
gen B_dep_nonmiss_avg = B_dep_nonmiss_tot/B_dep_nonmiss
 
*impute where appropriate 
foreach var in B_q5_f1_satisfied B_q5_f2_activities B_q5_f3_empty_life B_q5_f4_bored B_q5_f5_good_spirit B_q5_f6_afraid B_q5_f7_feel_happy B_q5_f8_hopeless_feel B_q5_f9_stay_home B_q5_f10_more_problms B_q5_f11_wondrful B_q5_f12_pretty_wrthless B_q5_f13_full_energy B_q5_f14_hopeless_situation B_q5_f15_people_better {
	replace `var' = B_dep_nonmiss_avg if `var'==. & B_dep_missing<=5
}

*final score
gen B_dep_score = B_q5_f1_satisfied + B_q5_f2_activities + B_q5_f3_empty_life + B_q5_f4_bored + B_q5_f5_good_spirit + B_q5_f6_afraid  + B_q5_f7_feel_happy + B_q5_f8_hopeless_feel + B_q5_f9_stay_home + B_q5_f10_more_problms + B_q5_f11_wondrful + B_q5_f12_pretty_wrthless + B_q5_f13_full_energy + B_q5_f14_hopeless_situation + B_q5_f15_people_better if B_dep_missing<=5

tab B_dep_score

*wave 1 
gen w1_dep_missing = 0 
foreach var in w1_q5_f1_satisfied w1_q5_f2_activities w1_q5_f3_empty_life w1_q5_f4_bored w1_q5_f5_good_spirit w1_q5_f6_afraid w1_q5_f7_feel_happy w1_q5_f8_hopeless_feel w1_q5_f9_stay_home w1_q5_f10_more_problms w1_q5_f11_wondrful w1_q5_f12_pretty_wrthless w1_q5_f13_full_energy w1_q5_f14_hopeless_situation w1_q5_f15_people_better {
	replace `var' = . if `var'==777
	replace w1_dep_missing = w1_dep_missing + 1 if `var'==. 
	replace `var' = 0 if `var'==2
}

*flip positive vars 
foreach var in w1_q5_f1_satisfied w1_q5_f5_good_spirit w1_q5_f7_feel_happy w1_q5_f11_wondrful w1_q5_f13_full_energy {
	replace `var' = 1 -`var'
}

gen w1_dep_nonmiss = 15 - w1_dep_missing
egen w1_dep_nonmiss_tot = rowtotal(w1_q5_f1_satisfied w1_q5_f2_activities w1_q5_f3_empty_life w1_q5_f4_bored w1_q5_f5_good_spirit w1_q5_f6_afraid w1_q5_f7_feel_happy w1_q5_f8_hopeless_feel w1_q5_f9_stay_home w1_q5_f10_more_problms w1_q5_f11_wondrful w1_q5_f12_pretty_wrthless w1_q5_f13_full_energy w1_q5_f14_hopeless_situation w1_q5_f15_people_better)
gen w1_dep_nonmiss_avg = w1_dep_nonmiss_tot/w1_dep_nonmiss

foreach var in w1_q5_f1_satisfied w1_q5_f2_activities w1_q5_f3_empty_life w1_q5_f4_bored w1_q5_f5_good_spirit w1_q5_f6_afraid w1_q5_f7_feel_happy w1_q5_f8_hopeless_feel w1_q5_f9_stay_home w1_q5_f10_more_problms w1_q5_f11_wondrful w1_q5_f12_pretty_wrthless w1_q5_f13_full_energy w1_q5_f14_hopeless_situation w1_q5_f15_people_better {
	replace `var' = w1_dep_nonmiss_avg if `var'==. & w1_dep_missing<=5
}

gen w1_dep_score = w1_q5_f1_satisfied + w1_q5_f2_activities + w1_q5_f3_empty_life + w1_q5_f4_bored + w1_q5_f5_good_spirit + w1_q5_f6_afraid  + w1_q5_f7_feel_happy + w1_q5_f8_hopeless_feel + w1_q5_f9_stay_home + w1_q5_f10_more_problms + w1_q5_f11_wondrful + w1_q5_f12_pretty_wrthless + w1_q5_f13_full_energy + w1_q5_f14_hopeless_situation + w1_q5_f15_people_better if w1_dep_missing<=5


*thresholds 
gen B_not_dep = 0 if B_dep_score!=. 
replace B_not_dep = 1 if B_dep_score>=0 & B_dep_score<=4
gen B_mild_dep = 0 if B_dep_score!=. 
replace B_mild_dep = 1 if B_dep_score>=5 & B_dep_score<=8
gen B_mod_dep = 0 if B_dep_score!=. 
replace B_mod_dep = 1 if B_dep_score>=9 & B_dep_score<=11
gen B_sev_dep = 0 if B_dep_score!=. 
replace B_sev_dep = 1 if B_dep_score>=12 & B_dep_score<=15

gen w1_not_dep = 0 if w1_dep_score!=. 
replace w1_not_dep = 1 if w1_dep_score>=0 & w1_dep_score<=4
gen w1_mild_dep = 0 if w1_dep_score!=. 
replace w1_mild_dep = 1 if w1_dep_score>=5 & w1_dep_score<=8
gen w1_mod_dep = 0 if w1_dep_score!=. 
replace w1_mod_dep = 1 if w1_dep_score>=9 & w1_dep_score<=11
gen w1_sev_dep = 0 if w1_dep_score!=. 
replace w1_sev_dep = 1 if w1_dep_score>=12 & w1_dep_score<=15

/**************************************************************
Literacy 
**************************************************************/

gen B_literate = (B_q6_a31_resp_literate==1)

gen w1_literate = 0 if surveyed_w1==1 
replace w1_literate = 1 if w1_q6_a31_resp_literate==1 

/**************************************************************
Cognition 
**************************************************************/

*No proxy responses here 
*For missings, counted as incorrect 
*Fix any dates very off in submission form 
*Separate options for those who can't see and use at least one hand, can't speak: create score for them 
*different responses for visually impaired 

*BL
*question 1 - time of day 
			destring B_calc_cogntn_mod_edhrs, replace 
			gen B_mmse_1 = 0 if B_q2_verbal_consnt==1 // all non proxy respondents 
			replace B_mmse_1 = 1 if B_q6_a1_now==1 & (B_calc_cogntn_mod_edhrs==0 | B_calc_cogntn_mod_edhrs==6 | B_calc_cogntn_mod_edhrs==7 | B_calc_cogntn_mod_edhrs==8 | B_calc_cogntn_mod_edhrs==9 | B_calc_cogntn_mod_edhrs==10 | B_calc_cogntn_mod_edhrs==11 | B_calc_cogntn_mod_edhrs==12)
			replace B_mmse_1 = 1 if B_q6_a1_now==2 & (B_calc_cogntn_mod_edhrs==0 | B_calc_cogntn_mod_edhrs==1 | B_calc_cogntn_mod_edhrs==11 | B_calc_cogntn_mod_edhrs==12 | B_calc_cogntn_mod_edhrs==13 | B_calc_cogntn_mod_edhrs==14 | B_calc_cogntn_mod_edhrs==15 | B_calc_cogntn_mod_edhrs==16 | B_calc_cogntn_mod_edhrs==17 | B_calc_cogntn_mod_edhrs==3 | B_calc_cogntn_mod_edhrs==4 | B_calc_cogntn_mod_edhrs==5)
			replace B_mmse_1 = 1 if B_q6_a1_now==3 & (B_calc_cogntn_mod_edhrs==15 | B_calc_cogntn_mod_edhrs==16 | B_calc_cogntn_mod_edhrs==17 | B_calc_cogntn_mod_edhrs==18 | B_calc_cogntn_mod_edhrs==19 | B_calc_cogntn_mod_edhrs==20 | B_calc_cogntn_mod_edhrs==21 | B_calc_cogntn_mod_edhrs==22 | B_calc_cogntn_mod_edhrs==23 | B_calc_cogntn_mod_edhrs==3 | B_calc_cogntn_mod_edhrs==4 | B_calc_cogntn_mod_edhrs==5 | B_calc_cogntn_mod_edhrs==6 | B_calc_cogntn_mod_edhrs==7 | B_calc_cogntn_mod_edhrs==8 | B_calc_cogntn_mod_edhrs==9)

*question 2 - day of week  
			*three manual replaces of date that shows up as 2013 
			replace B_survey_date = td(25mar2019) if B_survey_date==td(21jan2013) & hh_id=="2614635943249"
			replace B_survey_date = td(09may2019) if B_survey_date==td(21jan2013)

			*grab dates and day from survey_date 
			gen B_survey_day_week = dow(B_survey_date)
			replace B_q6_a2_day_week = 0 if B_q6_a2_day_week==7
			gen B_mmse_2 = 0 if B_q2_verbal_consnt==1 
			replace B_mmse_2 = 1 if B_q6_a2_day_week==B_survey_day_week
			
*question 3 - date 
			gen B_survey_day_num = day(B_survey_date)
			gen B_mmse_3 = 0 if B_q2_verbal_consnt==1 
			replace B_mmse_3 = 1 if B_q6_a3_today_date==B_survey_day_num
			
*question 4 - month 
			gen B_survey_month = month(B_survey_date)
			foreach var in B_q6_a4_month_english B_q6_a4_month_tamil {
				replace `var' = . if `var'==.b
			}
			gen B_mmse_4 = 0 if B_q2_verbal_consnt==1 
			replace B_mmse_4 = 1 if (B_q6_a4_month_english==B_survey_month)
			replace B_mmse_4 = 1 if  (B_q6_a4_month_tamil==1 & (B_survey_month==4 | B_survey_month==5))
			replace B_mmse_4 = 1 if  (B_q6_a4_month_tamil==2 & (B_survey_month==6 | B_survey_month==5))
			replace B_mmse_4 = 1 if  (B_q6_a4_month_tamil==3 & (B_survey_month==6 | B_survey_month==7))
			replace B_mmse_4 = 1 if  (B_q6_a4_month_tamil==4 & (B_survey_month==7 | B_survey_month==8))
			replace B_mmse_4 = 1 if  (B_q6_a4_month_tamil==5 & (B_survey_month==8 | B_survey_month==9))
			replace B_mmse_4 = 1 if  (B_q6_a4_month_tamil==6 & (B_survey_month==9 | B_survey_month==10))
			replace B_mmse_4 = 1 if  (B_q6_a4_month_tamil==7 & (B_survey_month==10 | B_survey_month==11))
			replace B_mmse_4 = 1 if  (B_q6_a4_month_tamil==8 & (B_survey_month==12 | B_survey_month==11))
			replace B_mmse_4 = 1 if  (B_q6_a4_month_tamil==9 & (B_survey_month==12 | B_survey_month==1))
			replace B_mmse_4 = 1 if  (B_q6_a4_month_tamil==10 & (B_survey_month==1 | B_survey_month==2))
			replace B_mmse_4 = 1 if  (B_q6_a4_month_tamil==11 & (B_survey_month==2 | B_survey_month==3))
			replace B_mmse_4 = 1 if  (B_q6_a4_month_tamil==12 & (B_survey_month==4 | B_survey_month==3))
			
*question 5 - season 
			gen B_mmse_5 = 0 if B_q2_verbal_consnt==1 
			replace B_mmse_5 = 1 if B_q6_a5_season==1 & (B_survey_month==3 | B_survey_month==4 | B_survey_month==5 | B_survey_month==6)
			replace B_mmse_5 = 1 if B_q6_a5_season==2 & (B_survey_month==3 | B_survey_month==2)
			replace B_mmse_5 = 1 if B_q6_a5_season==3 & (B_survey_month==12 | B_survey_month==1 | B_survey_month==2 | B_survey_month==3)
			replace B_mmse_5 = 1 if B_q6_a5_season==5 & (B_survey_month==6 | B_survey_month==7 | B_survey_month==8 | B_survey_month==9 | B_survey_month==10 | B_survey_month==11 | B_survey_month==12) // there was no 4 option 
			
			
*question 6 - state
		gen B_mmse_6 = 0 if B_q2_verbal_consnt==1 
		replace B_mmse_6 = 1 if B_q6_a6_state==1
			
		*question 7 - country 
		gen B_mmse_7 = 0 if B_q2_verbal_consnt==1
		replace B_mmse_7 = 1 if B_q6_a7_country==1
		
*question 8 - district 
			gen B_mmse_8 = 0 if B_q2_verbal_consnt==1
			replace B_mmse_8 = 1 if B_q01_district_nm==603 & (B_q6_a8_district_rural==1 | B_q6_a8_district_urban==1 | B_q6_a8_district_rural==7 | B_q6_a8_district_urban==7 | B_q6_a8_district_rural==6 | B_q6_a8_district_urban==6)
			replace B_mmse_8 = 1 if B_q01_district_nm==602 & (B_q6_a8_district_rural==1 | B_q6_a8_district_urban==1 | B_q6_a8_district_rural==7 | B_q6_a8_district_urban==7 | B_q6_a8_district_rural==6 | B_q6_a8_district_urban==6)
			replace B_mmse_8 = 1 if B_q01_district_nm==604 & (B_q6_a8_district_rural==1 | B_q6_a8_district_urban==1 | B_q6_a8_district_rural==7 | B_q6_a8_district_urban==7 | B_q6_a8_district_rural==6 | B_q6_a8_district_urban==6)
			replace B_mmse_8 = 1 if B_q01_district_nm==606 & (B_q6_a8_district_rural==4 | B_q6_a8_district_urban==4)
			replace B_mmse_8 = 1 if B_q01_district_nm==614 & (B_q6_a8_district_rural==2 | B_q6_a8_district_urban==2)
			replace B_mmse_8 = 1 if B_q01_district_nm==629 & (B_q6_a8_district_rural==3 | B_q6_a8_district_urban==3)
			replace B_mmse_8 = 1 if B_q01_district_nm==630 & (B_q6_a8_district_rural==5 | B_q6_a8_district_urban==5)	
			
			*question 9 - village 
			gen B_mmse_9 = 0 if B_q2_verbal_consnt==1
			replace B_mmse_9 = 1 if (B_q6_a9_village_rural==1 | B_q6_a9_village_urban==1)
			
			*question 10 - house 
			gen B_mmse_10 = 0 if B_q2_verbal_consnt==1
			replace B_mmse_10 = 1 if B_q6_a10_house==1

			*question 11 - repeat 3 things 
			gen B_mmse_11 = 0 if B_q2_verbal_consnt==1
			foreach var in B_q6_a11_delhi_brought_1 B_q6_a11_delhi_brought_2 B_q6_a11_delhi_brought_3 {
				replace B_mmse_11 = B_mmse_11 + 1 if `var'==1
			}
			
			*question 13 - backwards days of the week 
			gen B_mmse_13 = 0 if B_q2_verbal_consnt==1
			replace B_mmse_13 = B_mmse_13 + 1 if B_q6_a13_1_name_backward==5 
			replace B_mmse_13 = B_mmse_13 + 1 if B_q6_a13_2_before_tht==4
			replace B_mmse_13 = B_mmse_13 + 1 if B_q6_a13_3_before_tht==3
			replace B_mmse_13 = B_mmse_13 + 1 if B_q6_a13_4_before_tht==2
			replace B_mmse_13 = B_mmse_13 + 1 if B_q6_a13_5_before_tht==1

			*question 14 - recall 3 things 
			gen B_mmse_14 = 0 if B_q2_verbal_consnt==1
			foreach var in B_q6_a14_earlier_boug_1 B_q6_a14_earlier_boug_2 B_q6_a14_earlier_boug_3 {
				replace B_mmse_14 = B_mmse_14 + 1 if `var'==1
			}
			
			*question 17 and 18 or 19 and 20 - identify object 
			gen B_mmse_17_19 = 0 if B_q2_verbal_consnt==1
			gen B_mmse_18_20 = 0 if B_q2_verbal_consnt==1
			replace B_mmse_17_19 = 1 if (B_q6_a17_show_lock==1 | B_q6_a19_put_lock==1)
			replace B_mmse_18_20 = 1 if (B_q6_a18_show_pen==1 | B_q6_a20_put_pen==1)

			*question 21 - repeat phrase exactly 
			gen B_mmse_21 = 0 if B_q2_verbal_consnt==1
			replace B_mmse_21 = 1 if B_q6_a21_neither==1 
			replace B_mmse_21 = . if B_q6_a21_neither==2
			
			*question 23 or 24 - close eyes 
			gen B_mmse_23_24 = 0 if B_q2_verbal_consnt==1
			replace B_mmse_23_24 = 1 if (B_q6_a23_look_my_face==1 | B_q6_a24_close_ur_eyes==1)
		 	
			*questions 26.1-26.3 - mimicked action
			gen B_mmse_26_1 = 0 if B_q2_verbal_consnt==1
			replace B_mmse_26_1 = 1 if (B_q6_a26_1_resp_take_paper==1 | B_q6_a26_1_resp_take_paper==2) 
			replace B_mmse_26_1 = . if B_q6_a25_response==2
			gen B_mmse_26_2 = 0 if B_q2_verbal_consnt==1
			replace B_mmse_26_2 = 1 if B_q6_a26_2_fold_paper==1  
			replace B_mmse_26_2 = . if B_q6_a25_response==2
			gen B_mmse_26_3 = 0 if B_q2_verbal_consnt==1
			replace B_mmse_26_3 = 1 if B_q6_a26_3_return_paper==1
			replace B_mmse_26_3 = . if B_q6_a25_response==2
			
			*question 27 - said sentence 
			gen B_mmse_27 = 0 if B_q2_verbal_consnt==1
			replace B_mmse_27 = 1 if B_q6_a27_say_abt_house==1 
			
			*question 29 - draw picture 
			gen B_mmse_29 = 0 if B_q2_verbal_consnt==1
			replace B_mmse_29 = 1 if (B_q6_a29_1_4side_figure==1 & B_q6_a29_2_1fig_entirely==1 & B_q6_a29_3_rough_45angle==1)
			replace B_mmse_29= . if B_q6_a28_response==2
			
			*missing scores due to impairments to be accounted for 
			gen B_pts_missing_21 = (B_q6_a21_neither==2)
			gen B_pts_missing_26 = 3 if B_q6_a25_response==2
			gen B_pts_missing_29 = (B_q6_a28_response==2)	
			
			*create num points missing/nonmissing 
			gen B_mmse_missing = 0 if B_q2_verbal_consnt==1
			replace B_mmse_missing = B_mmse_missing + 1 if B_pts_missing_21==1 
			replace B_mmse_missing = B_mmse_missing + 3 if B_pts_missing_26==3
			replace B_mmse_missing = B_mmse_missing + 1 if B_pts_missing_29==1 
			
			gen B_mmse_nonmissing = 30 - B_mmse_missing
			 
			*calculate nonmissing average 
			egen B_mmse_nonmiss_tot = rowtotal(B_mmse_1 B_mmse_2 B_mmse_3 B_mmse_4 B_mmse_5 B_mmse_6 B_mmse_7 B_mmse_8 B_mmse_9 B_mmse_10 B_mmse_11 B_mmse_13 B_mmse_14 B_mmse_17_19 B_mmse_18_20 B_mmse_21 B_mmse_23_24 B_mmse_26_1 B_mmse_26_2 B_mmse_26_3 B_mmse_27 B_mmse_29)
			gen B_mmse_nonmiss_avg = B_mmse_nonmiss_tot/B_mmse_nonmissing
			
			*impute missings 
			replace B_mmse_21 = B_mmse_nonmiss_avg if B_pts_missing_21==1 
			replace B_mmse_26_1 = B_mmse_nonmiss_avg if B_pts_missing_26==3 
			replace B_mmse_26_2 = B_mmse_nonmiss_avg if B_pts_missing_26==3 
			replace B_mmse_26_3 = B_mmse_nonmiss_avg if B_pts_missing_26==3 
			replace B_mmse_29 = B_mmse_nonmiss_avg if B_pts_missing_29==1 
			
			*final score 
			gen B_mmse_score = B_mmse_1 + B_mmse_2 + B_mmse_3 + B_mmse_4 + B_mmse_5 + B_mmse_6 + B_mmse_7 + B_mmse_8 + B_mmse_9 + B_mmse_10 + B_mmse_11 + B_mmse_13 + B_mmse_14 + B_mmse_17_19 + B_mmse_18_20 + B_mmse_21 + B_mmse_23_24 + B_mmse_26_1 + B_mmse_26_2 + B_mmse_26_3 + B_mmse_27 + B_mmse_29

			*thresholds //according to 
			gen B_cognit_impaired = 0 if B_q2_verbal_consnt==1
			replace B_cognit_impaired = 1 if B_mmse_score>=0 & B_mmse_score<=19
			
			*those who needed a proxy for cognitive reasons are included as cognitively impaired for selection bias mitigation purposes
			replace B_cognit_impaired = 1 if B_proxy_mental==1 
			
			
*Wave 1 
*question 1 - time of day 
			destring w1_calc_cogntn_mod_edhrs, replace 
			gen w1_mmse_1 = 0 if w1_q2_verbal_consnt==1 // all non proxy respondents 
			replace w1_mmse_1 = 1 if w1_q6_a1_now==1 & (w1_calc_cogntn_mod_edhrs==0 | w1_calc_cogntn_mod_edhrs==6 | w1_calc_cogntn_mod_edhrs==7 | w1_calc_cogntn_mod_edhrs==8 | w1_calc_cogntn_mod_edhrs==9 | w1_calc_cogntn_mod_edhrs==10 | w1_calc_cogntn_mod_edhrs==11 | w1_calc_cogntn_mod_edhrs==12)
			replace w1_mmse_1 = 1 if w1_q6_a1_now==2 & (w1_calc_cogntn_mod_edhrs==0 | w1_calc_cogntn_mod_edhrs==1 | w1_calc_cogntn_mod_edhrs==11 | w1_calc_cogntn_mod_edhrs==12 | w1_calc_cogntn_mod_edhrs==13 | w1_calc_cogntn_mod_edhrs==14 | w1_calc_cogntn_mod_edhrs==15 | w1_calc_cogntn_mod_edhrs==16 | w1_calc_cogntn_mod_edhrs==17 | w1_calc_cogntn_mod_edhrs==3 | w1_calc_cogntn_mod_edhrs==4 | w1_calc_cogntn_mod_edhrs==5)
			replace w1_mmse_1 = 1 if w1_q6_a1_now==3 & (w1_calc_cogntn_mod_edhrs==15 | w1_calc_cogntn_mod_edhrs==16 | w1_calc_cogntn_mod_edhrs==17 | w1_calc_cogntn_mod_edhrs==18 | w1_calc_cogntn_mod_edhrs==19 | w1_calc_cogntn_mod_edhrs==20 | w1_calc_cogntn_mod_edhrs==21 | w1_calc_cogntn_mod_edhrs==22 | w1_calc_cogntn_mod_edhrs==23 | w1_calc_cogntn_mod_edhrs==3 | w1_calc_cogntn_mod_edhrs==4 | w1_calc_cogntn_mod_edhrs==5 | w1_calc_cogntn_mod_edhrs==6 | w1_calc_cogntn_mod_edhrs==7 | w1_calc_cogntn_mod_edhrs==8 | w1_calc_cogntn_mod_edhrs==9)

*question 2 - day of week  
			*three manual replaces of date that shows up as 2013 
			replace w1_survey_date = td(23dec2021) if w1_survey_date==td(22jan2013) & hh_id=="3606631450237"
			replace w1_survey_date = td(24jan2022) if w1_survey_date==td(22jan2013)

			*grab dates and day from survey_date 
			gen w1_survey_day_week = dow(w1_survey_date)
			replace w1_q6_a2_day_week = 0 if w1_q6_a2_day_week==7
			gen w1_mmse_2 = 0 if w1_q2_verbal_consnt==1 
			replace w1_mmse_2 = 1 if w1_q6_a2_day_week==w1_survey_day_week
			
*question 3 - date 
			gen w1_survey_day_num = day(w1_survey_date)
			gen w1_mmse_3 = 0 if w1_q2_verbal_consnt==1 
			replace w1_mmse_3 = 1 if w1_q6_a3_today_date==w1_survey_day_num
			
*question 4 - month 
			gen w1_survey_month = month(w1_survey_date)
			foreach var in w1_q6_a4_month_english w1_q6_a4_month_tamil {
				replace `var' = . if `var'==.b
			}
			gen w1_mmse_4 = 0 if w1_q2_verbal_consnt==1 
			replace w1_mmse_4 = 1 if (w1_q6_a4_month_english==w1_survey_month)
			replace w1_mmse_4 = 1 if  (w1_q6_a4_month_tamil==1 & (w1_survey_month==4 | w1_survey_month==5))
			replace w1_mmse_4 = 1 if  (w1_q6_a4_month_tamil==2 & (w1_survey_month==6 | w1_survey_month==5))
			replace w1_mmse_4 = 1 if  (w1_q6_a4_month_tamil==3 & (w1_survey_month==6 | w1_survey_month==7))
			replace w1_mmse_4 = 1 if  (w1_q6_a4_month_tamil==4 & (w1_survey_month==7 | w1_survey_month==8))
			replace w1_mmse_4 = 1 if  (w1_q6_a4_month_tamil==5 & (w1_survey_month==8 | w1_survey_month==9))
			replace w1_mmse_4 = 1 if  (w1_q6_a4_month_tamil==6 & (w1_survey_month==9 | w1_survey_month==10))
			replace w1_mmse_4 = 1 if  (w1_q6_a4_month_tamil==7 & (w1_survey_month==10 | w1_survey_month==11))
			replace w1_mmse_4 = 1 if  (w1_q6_a4_month_tamil==8 & (w1_survey_month==12 | w1_survey_month==11))
			replace w1_mmse_4 = 1 if  (w1_q6_a4_month_tamil==9 & (w1_survey_month==12 | w1_survey_month==1))
			replace w1_mmse_4 = 1 if  (w1_q6_a4_month_tamil==10 & (w1_survey_month==1 | w1_survey_month==2))
			replace w1_mmse_4 = 1 if  (w1_q6_a4_month_tamil==11 & (w1_survey_month==2 | w1_survey_month==3))
			replace w1_mmse_4 = 1 if  (w1_q6_a4_month_tamil==12 & (w1_survey_month==4 | w1_survey_month==3))
			 
*question 5 - season 
			gen w1_mmse_5 = 0 if w1_q2_verbal_consnt==1 
			replace w1_mmse_5 = 1 if w1_q6_a5_season==1 & (w1_survey_month==2 | w1_survey_month==3 | w1_survey_month==4 | w1_survey_month==5 | w1_survey_month==6)
			replace w1_mmse_5 = 1 if w1_q6_a5_season==2 & (w1_survey_month==3 | w1_survey_month==2)
			replace w1_mmse_5 = 1 if w1_q6_a5_season==3 & (w1_survey_month==12 | w1_survey_month==1 | w1_survey_month==2 | w1_survey_month==3)
			replace w1_mmse_5 = 1 if w1_q6_a5_season==5 & (w1_survey_month==6 | w1_survey_month==7 | w1_survey_month==8 | w1_survey_month==9 | w1_survey_month==10 | w1_survey_month==11 | w1_survey_month==12) // there was no 4 option 
			
			
*question 6 - state
		gen w1_mmse_6 = 0 if w1_q2_verbal_consnt==1 
		replace w1_mmse_6 = 1 if w1_q6_a6_state==1
			
		*question 7 - country 
		gen w1_mmse_7 = 0 if w1_q2_verbal_consnt==1
		replace w1_mmse_7 = 1 if w1_q6_a7_country==1
		
*question 8 - district 
			gen w1_mmse_8 = 0 if w1_q2_verbal_consnt==1
			replace w1_mmse_8 = 1 if w1_q01_district_nm==603 & (w1_q6_a8_district_rural==1 | w1_q6_a8_district_urban==1 | w1_q6_a8_district_rural==7 | w1_q6_a8_district_urban==7 | w1_q6_a8_district_rural==6 | w1_q6_a8_district_urban==6)
			replace w1_mmse_8 = 1 if w1_q01_district_nm==602 & (w1_q6_a8_district_rural==1 | w1_q6_a8_district_urban==1 | w1_q6_a8_district_rural==7 | w1_q6_a8_district_urban==7 | w1_q6_a8_district_rural==6 | w1_q6_a8_district_urban==6)
			replace w1_mmse_8 = 1 if w1_q01_district_nm==604 & (w1_q6_a8_district_rural==1 | w1_q6_a8_district_urban==1 | w1_q6_a8_district_rural==7 | w1_q6_a8_district_urban==7 | w1_q6_a8_district_rural==6 | w1_q6_a8_district_urban==6)
			replace w1_mmse_8 = 1 if w1_q01_district_nm==606 & (w1_q6_a8_district_rural==4 | w1_q6_a8_district_urban==4)
			replace w1_mmse_8 = 1 if w1_q01_district_nm==614 & (w1_q6_a8_district_rural==2 | w1_q6_a8_district_urban==2)
			replace w1_mmse_8 = 1 if w1_q01_district_nm==629 & (w1_q6_a8_district_rural==3 | w1_q6_a8_district_urban==3)
			replace w1_mmse_8 = 1 if w1_q01_district_nm==630 & (w1_q6_a8_district_rural==5 | w1_q6_a8_district_urban==5)	
			
			*question 9 - village 
			gen w1_mmse_9 = 0 if w1_q2_verbal_consnt==1
			replace w1_mmse_9 = 1 if (w1_q6_a9_village_rural==1 | w1_q6_a9_village_urban==1)
			
			*question 10 - house 
			gen w1_mmse_10 = 0 if w1_q2_verbal_consnt==1
			replace w1_mmse_10 = 1 if w1_q6_a10_house==1

			*question 11 - repeat 3 things 
			gen w1_mmse_11 = 0 if w1_q2_verbal_consnt==1
			foreach var in w1_q6_a11_delhi_brought_1 w1_q6_a11_delhi_brought_2 w1_q6_a11_delhi_brought_3 {
				replace w1_mmse_11 = w1_mmse_11 + 1 if `var'==1
			}
			
			*question 13 - backwards days of the week 
			gen w1_mmse_13 = 0 if w1_q2_verbal_consnt==1
			replace w1_mmse_13 = w1_mmse_13 + 1 if w1_q6_a13_1_name_backward==5 
			replace w1_mmse_13 = w1_mmse_13 + 1 if w1_q6_a13_2_before_tht==4
			replace w1_mmse_13 = w1_mmse_13 + 1 if w1_q6_a13_3_before_tht==3
			replace w1_mmse_13 = w1_mmse_13 + 1 if w1_q6_a13_4_before_tht==2
			replace w1_mmse_13 = w1_mmse_13 + 1 if w1_q6_a13_5_before_tht==1

			*question 14 - recall 3 things 
			gen w1_mmse_14 = 0 if w1_q2_verbal_consnt==1
			foreach var in w1_q6_a14_earlier_boug_1 w1_q6_a14_earlier_boug_2 w1_q6_a14_earlier_boug_3 {
				replace w1_mmse_14 = w1_mmse_14 + 1 if `var'==1
			}
			
			*question 17 and 18 or 19 and 20 - identify object 
			gen w1_mmse_17_19 = 0 if w1_q2_verbal_consnt==1
			gen w1_mmse_18_20 = 0 if w1_q2_verbal_consnt==1
			replace w1_mmse_17_19 = 1 if (w1_q6_a17_show_lock==1 | w1_q6_a19_put_lock==1)
			replace w1_mmse_18_20 = 1 if (w1_q6_a18_show_pen==1 | w1_q6_a20_put_pen==1)

			*question 21 - repeat phrase exactly 
			gen w1_mmse_21 = 0 if w1_q2_verbal_consnt==1
			replace w1_mmse_21 = 1 if w1_q6_a21_neither==1 
			replace w1_mmse_21 = . if w1_q6_a21_neither==2
			
			*question 23 or 24 - close eyes 
			gen w1_mmse_23_24 = 0 if w1_q2_verbal_consnt==1
			replace w1_mmse_23_24 = 1 if (w1_q6_a23_look_my_face==1 | w1_q6_a24_close_ur_eyes==1)
		 	
			*questions 26.1-26.3 - mimicked action
			gen w1_mmse_26_1 = 0 if w1_q2_verbal_consnt==1
			replace w1_mmse_26_1 = 1 if (w1_q6_a26_1_resp_take_paper==1 | w1_q6_a26_1_resp_take_paper==2) 
			replace w1_mmse_26_1 = . if w1_q6_a25_response==2
			gen w1_mmse_26_2 = 0 if w1_q2_verbal_consnt==1
			replace w1_mmse_26_2 = 1 if w1_q6_a26_2_fold_paper==1  
			replace w1_mmse_26_2 = . if w1_q6_a25_response==2
			gen w1_mmse_26_3 = 0 if w1_q2_verbal_consnt==1
			replace w1_mmse_26_3 = 1 if w1_q6_a26_3_return_paper==1
			replace w1_mmse_26_3 = . if w1_q6_a25_response==2
			
			*question 27 - said sentence 
			gen w1_mmse_27 = 0 if w1_q2_verbal_consnt==1
			replace w1_mmse_27 = 1 if w1_q6_a27_say_abt_house==1 
			
			*question 29 - draw picture 
			gen w1_mmse_29 = 0 if w1_q2_verbal_consnt==1
			replace w1_mmse_29 = 1 if (w1_q6_a29_1_4side_figure==1 & w1_q6_a29_2_1fig_entirely==1 & w1_q6_a29_3_rough_45angle==1)
			replace w1_mmse_29= . if w1_q6_a28_response==2
			
			*missing scores due to impairments to be accounted for 
			gen w1_pts_missing_21 = (w1_q6_a21_neither==2)
			gen w1_pts_missing_26 = 3 if w1_q6_a25_response==2
			gen w1_pts_missing_29 = (w1_q6_a28_response==2)	
			
			*create num points missing/nonmissing 
			gen w1_mmse_missing = 0 if w1_q2_verbal_consnt==1
			replace w1_mmse_missing = w1_mmse_missing + 1 if w1_pts_missing_21==1 
			replace w1_mmse_missing = w1_mmse_missing + 3 if w1_pts_missing_26==3
			replace w1_mmse_missing = w1_mmse_missing + 1 if w1_pts_missing_29==1 
			
			gen w1_mmse_nonmissing = 30 - w1_mmse_missing
			 
			*calculate nonmissing average 
			egen w1_mmse_nonmiss_tot = rowtotal(w1_mmse_1 w1_mmse_2 w1_mmse_3 w1_mmse_4 w1_mmse_5 w1_mmse_6 w1_mmse_7 w1_mmse_8 w1_mmse_9 w1_mmse_10 w1_mmse_11 w1_mmse_13 w1_mmse_14 w1_mmse_17_19 w1_mmse_18_20 w1_mmse_21 w1_mmse_23_24 w1_mmse_26_1 w1_mmse_26_2 w1_mmse_26_3 w1_mmse_27 w1_mmse_29)
			gen w1_mmse_nonmiss_avg = w1_mmse_nonmiss_tot/w1_mmse_nonmissing
			
			*impute missings 
			replace w1_mmse_21 = w1_mmse_nonmiss_avg if w1_pts_missing_21==1 
			replace w1_mmse_26_1 = w1_mmse_nonmiss_avg if w1_pts_missing_26==3 
			replace w1_mmse_26_2 = w1_mmse_nonmiss_avg if w1_pts_missing_26==3 
			replace w1_mmse_26_3 = w1_mmse_nonmiss_avg if w1_pts_missing_26==3 
			replace w1_mmse_29 = w1_mmse_nonmiss_avg if w1_pts_missing_29==1 
			
			*final score 
			gen w1_mmse_score = w1_mmse_1 + w1_mmse_2 + w1_mmse_3 + w1_mmse_4 + w1_mmse_5 + w1_mmse_6 + w1_mmse_7 + w1_mmse_8 + w1_mmse_9 + w1_mmse_10 + w1_mmse_11 + w1_mmse_13 + w1_mmse_14 + w1_mmse_17_19 + w1_mmse_18_20 + w1_mmse_21 + w1_mmse_23_24 + w1_mmse_26_1 + w1_mmse_26_2 + w1_mmse_26_3 + w1_mmse_27 + w1_mmse_29

			*thresholds //according to 
			gen w1_cognit_impaired = 0 if w1_q2_verbal_consnt==1
			replace w1_cognit_impaired = 1 if w1_mmse_score>=0 & w1_mmse_score<=19
			
			*those who needed a proxy for cognitive reasons are included as cognitively impaired for selection bias mitigation purposes
			replace w1_cognit_impaired = 1 if w1_proxy_mental==1 

/**************************************************************
ADLs
**************************************************************/
*BL
*first ensure responses are put to missing if there was a proxy (there is a separate set of questions for the proxy); in initial cleaning, these were merged but should not be; or if it is a dont know or refused 
foreach var in B_q3_a1_lng_periods B_q3_a2_stnding_up B_q3_a3_lyng_dwn B_q3_a4_stndng_lng_periods B_q3_a5_extndng_arms B_q3_a6_whole_bdy_washng B_q3_a7_gettng_dressd B_q3_a8_toilt_using B_q3_a9_takecare_hh B_q3_a10_movng_around B_q3_a11_walkng_100_metrs B_q3_a12_walkng_lng_distnce B_q3_a13_climbing B_q3_a14_stooping B_q3_a15_things_pickup B_q3_a16_carryng_thngs B_q3_a17_eating B_q3_a18_out_of_hm B_q3_a19_usng_pvt B_q3_a20_concntratng B_q3_a21_learning_nw_tsk B_q3_a22_joining_cmmnty {
	replace `var' = . if B_proxy_need==1 
	replace `var' = . if `var'==888 | `var'==777
}

*replace NA with extreme difficulty 
foreach var in B_q3_a1_lng_periods B_q3_a2_stnding_up B_q3_a3_lyng_dwn B_q3_a4_stndng_lng_periods B_q3_a5_extndng_arms B_q3_a6_whole_bdy_washng B_q3_a7_gettng_dressd B_q3_a8_toilt_using B_q3_a9_takecare_hh B_q3_a10_movng_around B_q3_a11_walkng_100_metrs B_q3_a12_walkng_lng_distnce B_q3_a13_climbing B_q3_a14_stooping B_q3_a15_things_pickup B_q3_a16_carryng_thngs B_q3_a17_eating B_q3_a18_out_of_hm B_q3_a19_usng_pvt B_q3_a20_concntratng B_q3_a21_learning_nw_tsk B_q3_a22_joining_cmmnty {
	replace `var' = 5 if `var'==9 | `var'==6
}
*topcode those that were skipped 
foreach var in B_q3_a10_movng_around B_q3_a11_walkng_100_metrs B_q3_a12_walkng_lng_distnce B_q3_a13_climbing {
	replace `var' = 5 if B_q3_a9_takecare_hh==5
}

*Calculate number missing 
gen B_adl_missing = 0 if B_q2_verbal_consnt==1
foreach var in B_q3_a1_lng_periods B_q3_a2_stnding_up B_q3_a3_lyng_dwn B_q3_a4_stndng_lng_periods B_q3_a5_extndng_arms B_q3_a6_whole_bdy_washng B_q3_a7_gettng_dressd B_q3_a8_toilt_using B_q3_a9_takecare_hh B_q3_a10_movng_around B_q3_a11_walkng_100_metrs B_q3_a12_walkng_lng_distnce B_q3_a13_climbing B_q3_a14_stooping B_q3_a15_things_pickup B_q3_a16_carryng_thngs B_q3_a17_eating B_q3_a18_out_of_hm B_q3_a19_usng_pvt B_q3_a20_concntratng B_q3_a21_learning_nw_tsk B_q3_a22_joining_cmmnty {
	replace B_adl_missing = B_adl_missing + 1 if `var'==. 
}

*generate whether they were deficient in each activity 
foreach var in B_q3_a1_lng_periods B_q3_a2_stnding_up B_q3_a3_lyng_dwn B_q3_a4_stndng_lng_periods B_q3_a5_extndng_arms B_q3_a6_whole_bdy_washng B_q3_a7_gettng_dressd B_q3_a8_toilt_using B_q3_a9_takecare_hh B_q3_a10_movng_around B_q3_a11_walkng_100_metrs B_q3_a12_walkng_lng_distnce B_q3_a13_climbing B_q3_a14_stooping B_q3_a15_things_pickup B_q3_a16_carryng_thngs B_q3_a17_eating B_q3_a18_out_of_hm B_q3_a19_usng_pvt B_q3_a20_concntratng B_q3_a21_learning_nw_tsk B_q3_a22_joining_cmmnty {
	gen `var'_def = 0 if (`var'==1 | `var'==2 | `var'==3) & (B_adl_missing==2 |  B_adl_missing==1 |  B_adl_missing==0)
	replace `var'_def = 1 if (`var'==4 | `var'==5)  & (B_adl_missing==2 |  B_adl_missing==1 |  B_adl_missing==0)
}

*generate nonmissing average 
egen B_adl_nonmiss_avg = rowmean(B_q3_a1_lng_periods B_q3_a2_stnding_up B_q3_a3_lyng_dwn B_q3_a4_stndng_lng_periods B_q3_a5_extndng_arms B_q3_a6_whole_bdy_washng B_q3_a7_gettng_dressd B_q3_a8_toilt_using B_q3_a9_takecare_hh B_q3_a10_movng_around B_q3_a11_walkng_100_metrs B_q3_a12_walkng_lng_distnce B_q3_a13_climbing B_q3_a14_stooping B_q3_a15_things_pickup B_q3_a16_carryng_thngs B_q3_a17_eating B_q3_a18_out_of_hm B_q3_a19_usng_pvt B_q3_a20_concntratng B_q3_a21_learning_nw_tsk B_q3_a22_joining_cmmnty)

*fill in deficiencies for those missing less than or equal to 2 
foreach var in B_q3_a1_lng_periods B_q3_a2_stnding_up B_q3_a3_lyng_dwn B_q3_a4_stndng_lng_periods B_q3_a5_extndng_arms B_q3_a6_whole_bdy_washng B_q3_a7_gettng_dressd B_q3_a8_toilt_using B_q3_a9_takecare_hh B_q3_a10_movng_around B_q3_a11_walkng_100_metrs B_q3_a12_walkng_lng_distnce B_q3_a13_climbing B_q3_a14_stooping B_q3_a15_things_pickup B_q3_a16_carryng_thngs B_q3_a17_eating B_q3_a18_out_of_hm B_q3_a19_usng_pvt B_q3_a20_concntratng B_q3_a21_learning_nw_tsk B_q3_a22_joining_cmmnty {

	replace `var'_def = 1 if `var'_def==. & (B_adl_missing==2 |  B_adl_missing==1 |  B_adl_missing==0) & B_adl_nonmiss_avg>=4
	replace `var'_def = 0 if `var'_def==.  & (B_adl_missing==2 |  B_adl_missing==1 |  B_adl_missing==0) & B_adl_nonmiss_avg<4
}

*create percent deficient score 
gen B_share_def_adl = (B_q3_a1_lng_periods_def + B_q3_a2_stnding_up_def + B_q3_a3_lyng_dwn_def + B_q3_a4_stndng_lng_periods_def + B_q3_a5_extndng_arms_def + B_q3_a6_whole_bdy_washng_def + B_q3_a7_gettng_dressd_def + B_q3_a8_toilt_using_def + B_q3_a9_takecare_hh_def + B_q3_a10_movng_around_def + B_q3_a11_walkng_100_metrs_def + B_q3_a12_walkng_lng_distnce_def + B_q3_a13_climbing_def + B_q3_a14_stooping_def + B_q3_a15_things_pickup_def + B_q3_a16_carryng_thngs_def + B_q3_a17_eating_def + B_q3_a18_out_of_hm_def + B_q3_a19_usng_pvt_def + B_q3_a20_concntratng_def + B_q3_a21_learning_nw_tsk_def + B_q3_a22_joining_cmmnty_def)/22

*wave 1
*first ensure responses are put to missing if there was a proxy (there is a separate set of questions for the proxy); in initial cleaning, these were merged but should not be; or if it is a dont know or refused 
foreach var in w1_q3_a1_lng_periods w1_q3_a2_stnding_up w1_q3_a3_lyng_dwn w1_q3_a4_stndng_lng_periods w1_q3_a5_extndng_arms w1_q3_a6_whole_bdy_washng w1_q3_a7_gettng_dressd w1_q3_a8_toilt_using w1_q3_a9_takecare_hh w1_q3_a10_movng_around w1_q3_a11_walkng_100_metrs w1_q3_a12_walkng_lng_distnce w1_q3_a13_climbing w1_q3_a14_stooping w1_q3_a15_things_pickup w1_q3_a16_carryng_thngs w1_q3_a17_eating w1_q3_a18_out_of_hm w1_q3_a19_usng_pvt w1_q3_a20_concntratng w1_q3_a21_learning_nw_tsk w1_q3_a22_joining_cmmnty {
	replace `var' = . if w1_proxy_need==1 
	replace `var' = . if `var'==888 | `var'==777
}

*replace NA with extreme difficulty 
foreach var in w1_q3_a1_lng_periods w1_q3_a2_stnding_up w1_q3_a3_lyng_dwn w1_q3_a4_stndng_lng_periods w1_q3_a5_extndng_arms w1_q3_a6_whole_bdy_washng w1_q3_a7_gettng_dressd w1_q3_a8_toilt_using w1_q3_a9_takecare_hh w1_q3_a10_movng_around w1_q3_a11_walkng_100_metrs w1_q3_a12_walkng_lng_distnce w1_q3_a13_climbing w1_q3_a14_stooping w1_q3_a15_things_pickup w1_q3_a16_carryng_thngs w1_q3_a17_eating w1_q3_a18_out_of_hm w1_q3_a19_usng_pvt w1_q3_a20_concntratng w1_q3_a21_learning_nw_tsk w1_q3_a22_joining_cmmnty {
	replace `var' = 5 if `var'==9 | `var'==6
}
*topcode those that were skipped 
foreach var in w1_q3_a10_movng_around w1_q3_a11_walkng_100_metrs w1_q3_a12_walkng_lng_distnce w1_q3_a13_climbing {
	replace `var' = 5 if w1_q3_a9_takecare_hh==5
}

*Calculate number missing 
gen w1_adl_missing = 0 if w1_q2_verbal_consnt==1
foreach var in w1_q3_a1_lng_periods w1_q3_a2_stnding_up w1_q3_a3_lyng_dwn w1_q3_a4_stndng_lng_periods w1_q3_a5_extndng_arms w1_q3_a6_whole_bdy_washng w1_q3_a7_gettng_dressd w1_q3_a8_toilt_using w1_q3_a9_takecare_hh w1_q3_a10_movng_around w1_q3_a11_walkng_100_metrs w1_q3_a12_walkng_lng_distnce w1_q3_a13_climbing w1_q3_a14_stooping w1_q3_a15_things_pickup w1_q3_a16_carryng_thngs w1_q3_a17_eating w1_q3_a18_out_of_hm w1_q3_a19_usng_pvt w1_q3_a20_concntratng w1_q3_a21_learning_nw_tsk w1_q3_a22_joining_cmmnty {
	replace w1_adl_missing = w1_adl_missing + 1 if `var'==. 
}

*generate whether they were deficient in each activity 
foreach var in w1_q3_a1_lng_periods w1_q3_a2_stnding_up w1_q3_a3_lyng_dwn w1_q3_a4_stndng_lng_periods w1_q3_a5_extndng_arms w1_q3_a6_whole_bdy_washng w1_q3_a7_gettng_dressd w1_q3_a8_toilt_using w1_q3_a9_takecare_hh w1_q3_a10_movng_around w1_q3_a11_walkng_100_metrs w1_q3_a12_walkng_lng_distnce w1_q3_a13_climbing w1_q3_a14_stooping w1_q3_a15_things_pickup w1_q3_a16_carryng_thngs w1_q3_a17_eating w1_q3_a18_out_of_hm w1_q3_a19_usng_pvt w1_q3_a20_concntratng w1_q3_a21_learning_nw_tsk w1_q3_a22_joining_cmmnty {
	gen `var'_def = 0 if (`var'==1 | `var'==2 | `var'==3) & (w1_adl_missing==2 |  w1_adl_missing==1 |  w1_adl_missing==0)
	replace `var'_def = 1 if (`var'==4 | `var'==5)  & (w1_adl_missing==2 |  w1_adl_missing==1 |  w1_adl_missing==0)
}

*generate nonmissing average 
egen w1_adl_nonmiss_avg = rowmean(w1_q3_a1_lng_periods w1_q3_a2_stnding_up w1_q3_a3_lyng_dwn w1_q3_a4_stndng_lng_periods w1_q3_a5_extndng_arms w1_q3_a6_whole_bdy_washng w1_q3_a7_gettng_dressd w1_q3_a8_toilt_using w1_q3_a9_takecare_hh w1_q3_a10_movng_around w1_q3_a11_walkng_100_metrs w1_q3_a12_walkng_lng_distnce w1_q3_a13_climbing w1_q3_a14_stooping w1_q3_a15_things_pickup w1_q3_a16_carryng_thngs w1_q3_a17_eating w1_q3_a18_out_of_hm w1_q3_a19_usng_pvt w1_q3_a20_concntratng w1_q3_a21_learning_nw_tsk w1_q3_a22_joining_cmmnty)

*fill in deficiencies for those missing less than or equal to 2 
foreach var in w1_q3_a1_lng_periods w1_q3_a2_stnding_up w1_q3_a3_lyng_dwn w1_q3_a4_stndng_lng_periods w1_q3_a5_extndng_arms w1_q3_a6_whole_bdy_washng w1_q3_a7_gettng_dressd w1_q3_a8_toilt_using w1_q3_a9_takecare_hh w1_q3_a10_movng_around w1_q3_a11_walkng_100_metrs w1_q3_a12_walkng_lng_distnce w1_q3_a13_climbing w1_q3_a14_stooping w1_q3_a15_things_pickup w1_q3_a16_carryng_thngs w1_q3_a17_eating w1_q3_a18_out_of_hm w1_q3_a19_usng_pvt w1_q3_a20_concntratng w1_q3_a21_learning_nw_tsk w1_q3_a22_joining_cmmnty {

	replace `var'_def = 1 if `var'_def==. & (w1_adl_missing==2 |  w1_adl_missing==1 |  w1_adl_missing==0) & w1_adl_nonmiss_avg>=4
	replace `var'_def = 0 if `var'_def==. & (w1_adl_missing==2 |  w1_adl_missing==1 |  w1_adl_missing==0) & w1_adl_nonmiss_avg<4
}

*create percent deficient score 
gen w1_share_def_adl = (w1_q3_a1_lng_periods_def + w1_q3_a2_stnding_up_def + w1_q3_a3_lyng_dwn_def + w1_q3_a4_stndng_lng_periods_def + w1_q3_a5_extndng_arms_def + w1_q3_a6_whole_bdy_washng_def + w1_q3_a7_gettng_dressd_def + w1_q3_a8_toilt_using_def + w1_q3_a9_takecare_hh_def + w1_q3_a10_movng_around_def + w1_q3_a11_walkng_100_metrs_def + w1_q3_a12_walkng_lng_distnce_def + w1_q3_a13_climbing_def + w1_q3_a14_stooping_def + w1_q3_a15_things_pickup_def + w1_q3_a16_carryng_thngs_def + w1_q3_a17_eating_def + w1_q3_a18_out_of_hm_def + w1_q3_a19_usng_pvt_def + w1_q3_a20_concntratng_def + w1_q3_a21_learning_nw_tsk_def + w1_q3_a22_joining_cmmnty_def)/22


/**************************************************************
Direct loneliness 
**************************************************************/

gen B_often_lonely = 0 if B_q5_f16_feel_lonely==2 
replace B_often_lonely = 1 if B_q5_f16_feel_lonely==1 

gen w1_often_lonely = 0 if w1_q5_f16_feel_lonely==2 
replace w1_often_lonely = 1 if w1_q5_f16_feel_lonely==1 

/**************************************************************
Nondurable consumption  
**************************************************************/
*Baseline 
*This is the per-capita daily expenditure on nondurables excluding medical expenses and rent as well as durable goods.
*We first want total spending so we can calcuate percent of spending on food, medical 
*So four calculations: total, nondurable (excluding medical and rent, durables), food, medical 

*First calculate number missing 
gen B_cons_missing = 0 if surveyed_BL==1
foreach var in B_e2_1_consume_rice B_e2_1_consume_wheat B_e2_1_consume_ragi B_e2_1_consume_oth_cerel B_e2_2_consume_lentils B_e2_2_consume_oth_puls B_e2_3_consume_milk B_e2_4_consume_milk_prdct B_e2_5_consume_edible_oil B_e2_6_consume_veg B_e2_7_consume_fruit B_e2_8_consume_egg_fish B_e2_9_consume_sugar B_e2_10_consume_salt_spice B_e2_11_consume_oth_food_item B_e2_12_consume_pan_tob B_e2_13_consume_fuel_light B_e2_14_consume_entertain B_e2_15_consume_person_care B_e2_16_consume_toilet_arti B_e2_17_consume_sundry_arti B_e2_18_consume_excl_convey B_e2_19_consume_conveyce B_e2_20_consume_rent B_e2_21_consume_taxes B_e2_22_medical_exp B_e2_24_medical B_e2_25_tution_fees B_e2_26_sch_books B_e2_27_cloth_bedding B_e2_28_footwear B_e2_29_furniture B_e2_30_crokery B_e2_31_cook_hh_appliance B_e2_32_recreation_goods B_e2_33_jewellery B_e2_34_personal_transport B_e2_35_therapeutic_appl B_e2_36_oth_pers_goods B_e2_37_repair_maintain {
	replace B_cons_missing = B_cons_missing+ 1 if `var'==. 
}

*For those with 23 or fewer missing, missings are counted as 0 spent. 
*Get all variables to per capita monthly hh spending if less than 24 missing 
*there is a cutoff at around 24 and more of 40 missing; those are exlcuded (about .5% of people)
*monthly 
foreach var in B_e2_1_consume_rice B_e2_1_consume_wheat B_e2_1_consume_ragi B_e2_1_consume_oth_cerel B_e2_2_consume_lentils B_e2_2_consume_oth_puls B_e2_3_consume_milk B_e2_4_consume_milk_prdct B_e2_5_consume_edible_oil B_e2_6_consume_veg B_e2_7_consume_fruit B_e2_8_consume_egg_fish B_e2_9_consume_sugar B_e2_10_consume_salt_spice B_e2_11_consume_oth_food_item B_e2_12_consume_pan_tob B_e2_13_consume_fuel_light B_e2_14_consume_entertain B_e2_15_consume_person_care B_e2_16_consume_toilet_arti B_e2_17_consume_sundry_arti B_e2_18_consume_excl_convey B_e2_19_consume_conveyce B_e2_20_consume_rent B_e2_21_consume_taxes B_e2_22_medical_exp  {
	gen `var'_pc = (`var'/30)/B_a1_people_live_hh if B_cons_missing<=23 & B_cons_missing!=. 
	replace `var'_pc = 0 if `var'_pc==. & B_cons_missing<=23 & B_cons_missing!=. 
}

*yearly 
foreach var in B_e2_24_medical B_e2_25_tution_fees B_e2_26_sch_books B_e2_27_cloth_bedding B_e2_28_footwear B_e2_29_furniture B_e2_30_crokery B_e2_31_cook_hh_appliance B_e2_32_recreation_goods B_e2_33_jewellery B_e2_34_personal_transport B_e2_35_therapeutic_appl B_e2_36_oth_pers_goods B_e2_37_repair_maintain  {
	gen `var'_pc = (`var'/365)/B_a1_people_live_hh if B_cons_missing<=23 & B_cons_missing!=. 
	replace `var'_pc = 0 if `var'_pc==. & B_cons_missing<=23 & B_cons_missing!=. 
}

*calculate and winsor at 98 pctile 
egen B_total_pc_cons = rowtotal(B_e2_1_consume_rice_pc B_e2_1_consume_wheat_pc B_e2_1_consume_ragi_pc B_e2_1_consume_oth_cerel_pc B_e2_2_consume_lentils_pc B_e2_2_consume_oth_puls_pc B_e2_3_consume_milk_pc B_e2_4_consume_milk_prdct_pc B_e2_5_consume_edible_oil_pc B_e2_6_consume_veg_pc B_e2_7_consume_fruit_pc B_e2_8_consume_egg_fish_pc B_e2_9_consume_sugar_pc B_e2_10_consume_salt_spice_pc B_e2_11_consume_oth_food_item_pc B_e2_12_consume_pan_tob_pc B_e2_13_consume_fuel_light_pc B_e2_14_consume_entertain_pc B_e2_15_consume_person_care_pc B_e2_16_consume_toilet_arti_pc B_e2_17_consume_sundry_arti_pc B_e2_18_consume_excl_convey_pc B_e2_19_consume_conveyce_pc B_e2_20_consume_rent_pc B_e2_21_consume_taxes_pc B_e2_22_medical_exp_pc B_e2_24_medical_pc B_e2_25_tution_fees_pc B_e2_26_sch_books_pc B_e2_27_cloth_bedding_pc B_e2_28_footwear_pc B_e2_29_furniture_pc B_e2_30_crokery_pc B_e2_31_cook_hh_appliance_pc B_e2_32_recreation_goods_pc B_e2_33_jewellery_pc B_e2_34_personal_transport_pc B_e2_35_therapeutic_appl_pc B_e2_36_oth_pers_goods_pc B_e2_37_repair_maintain_pc)
winsor2 B_total_pc_cons, replace cuts(0 99)

egen B_nondur_pc_cons = rowtotal(B_e2_1_consume_rice_pc B_e2_1_consume_wheat_pc B_e2_1_consume_ragi_pc B_e2_1_consume_oth_cerel_pc B_e2_2_consume_lentils_pc B_e2_2_consume_oth_puls_pc B_e2_3_consume_milk_pc B_e2_4_consume_milk_prdct_pc B_e2_5_consume_edible_oil_pc B_e2_6_consume_veg_pc B_e2_7_consume_fruit_pc B_e2_8_consume_egg_fish_pc B_e2_9_consume_sugar_pc B_e2_10_consume_salt_spice_pc B_e2_11_consume_oth_food_item_pc B_e2_12_consume_pan_tob_pc B_e2_13_consume_fuel_light_pc B_e2_14_consume_entertain_pc B_e2_15_consume_person_care_pc B_e2_16_consume_toilet_arti_pc B_e2_17_consume_sundry_arti_pc B_e2_18_consume_excl_convey_pc B_e2_19_consume_conveyce_pc B_e2_21_consume_taxes_pc B_e2_25_tution_fees_pc B_e2_26_sch_books_pc B_e2_27_cloth_bedding_pc B_e2_28_footwear_pc B_e2_33_jewellery_pc B_e2_35_therapeutic_appl_pc  B_e2_37_repair_maintain_pc)
winsor2 B_nondur_pc_cons, replace cuts(0 99)

egen B_food_pc_cons = rowtotal(B_e2_1_consume_rice_pc B_e2_1_consume_wheat_pc B_e2_1_consume_ragi_pc B_e2_1_consume_oth_cerel_pc B_e2_2_consume_lentils_pc B_e2_2_consume_oth_puls_pc B_e2_3_consume_milk_pc B_e2_4_consume_milk_prdct_pc B_e2_5_consume_edible_oil_pc B_e2_6_consume_veg_pc B_e2_7_consume_fruit_pc B_e2_8_consume_egg_fish_pc B_e2_9_consume_sugar_pc B_e2_10_consume_salt_spice_pc B_e2_11_consume_oth_food_item_pc)
winsor2 B_food_pc_cons, replace cuts(0 99)

egen B_med_pc_cons = rowtotal(B_e2_22_medical_exp_pc B_e2_24_medical_pc)
winsor2 B_med_pc_cons, replace cuts(0 99)

*Calculate share of spending on food and medical for food security measures 
gen B_med_exp_share = B_food_pc_cons/B_total_pc_cons
gen B_food_exp_share = B_med_pc_cons/B_total_pc_cons

*Calculate percent below poverty line 
*The 2019 WB extreme poverty line was 38 rupees per day PPP. The low-middle income poverty line was 64 rupees per day PPP. We use these as thresholds for the 2019 baseline survey and then convert the wave 1 prices to 2019 PPP using the OECD statistics, scaling by 23.138/21.073 (the 2021 and 2019 PPPs to the USD respectively). 
gen B_below_ext_pov = 0 if B_nondur_pc_cons!=. 
replace B_below_ext_pov = 1 if B_nondur_pc_cons>=0 & B_nondur_pc_cons<=38 

gen B_below_lowmid_pov = 0 if B_nondur_pc_cons!=. 
replace B_below_lowmid_pov = 1 if B_nondur_pc_cons>=0 & B_nondur_pc_cons<=64


*Wave 1
*This is the per-capita daily expenditure on nondurables excluding medical expenses and rent as well as durable goods.
*We first want total spending so we can calcuate percent of spending on food, medical 
*So four calculations: total, nondurable (excluding medical and rent, durables), food, medical 
rename w1_e2_11_consume_oth_food_item w1_e2_11_cons_oth_food_item
*First calculate number missing 
gen w1_cons_missing = 0 if surveyed_w1==1
foreach var in w1_e2_1_consume_rice w1_e2_1_consume_wheat w1_e2_1_consume_ragi w1_e2_1_consume_oth_cerel w1_e2_2_consume_lentils w1_e2_2_consume_oth_puls w1_e2_3_consume_milk w1_e2_4_consume_milk_prdct w1_e2_5_consume_edible_oil w1_e2_6_consume_veg w1_e2_7_consume_fruit w1_e2_8_consume_egg_fish w1_e2_9_consume_sugar w1_e2_10_consume_salt_spice w1_e2_11_cons_oth_food_item w1_e2_12_consume_pan_tob w1_e2_13_consume_fuel_light w1_e2_14_consume_entertain w1_e2_15_consume_person_care w1_e2_16_consume_toilet_arti w1_e2_17_consume_sundry_arti w1_e2_18_consume_excl_convey w1_e2_19_consume_conveyce w1_e2_20_consume_rent w1_e2_21_consume_taxes w1_e2_22_medical_exp w1_e2_24_medical w1_e2_25_tution_fees w1_e2_26_sch_books w1_e2_27_cloth_bedding w1_e2_28_footwear w1_e2_29_furniture w1_e2_30_crokery w1_e2_31_cook_hh_appliance w1_e2_32_recreation_goods w1_e2_33_jewellery w1_e2_34_personal_transport w1_e2_35_therapeutic_appl w1_e2_36_oth_pers_goods w1_e2_37_repair_maintain {
	replace w1_cons_missing = w1_cons_missing+ 1 if `var'==. 
}

*For those with 23 or fewer missing, missings are counted as 0 spent. 
*Get all variables to per capita monthly hh spending if less than 24 missing 
*there is a cutoff at around 24 and more of 40 missing; those are exlcuded (about .5% of people)
*monthly 
foreach var in w1_e2_1_consume_rice w1_e2_1_consume_wheat w1_e2_1_consume_ragi w1_e2_1_consume_oth_cerel w1_e2_2_consume_lentils w1_e2_2_consume_oth_puls w1_e2_3_consume_milk w1_e2_4_consume_milk_prdct w1_e2_5_consume_edible_oil w1_e2_6_consume_veg w1_e2_7_consume_fruit w1_e2_8_consume_egg_fish w1_e2_9_consume_sugar w1_e2_10_consume_salt_spice w1_e2_11_cons_oth_food_item w1_e2_12_consume_pan_tob w1_e2_13_consume_fuel_light w1_e2_14_consume_entertain w1_e2_15_consume_person_care w1_e2_16_consume_toilet_arti w1_e2_17_consume_sundry_arti w1_e2_18_consume_excl_convey w1_e2_19_consume_conveyce w1_e2_20_consume_rent w1_e2_21_consume_taxes w1_e2_22_medical_exp  {
	gen `var'_pc = (`var'/30)/w1_a1_people_live_hh if w1_cons_missing<=23 & w1_cons_missing!=. 
	replace `var'_pc = 0 if `var'_pc==. & w1_cons_missing<=23 & w1_cons_missing!=. 
}

*yearly 
foreach var in w1_e2_24_medical w1_e2_25_tution_fees w1_e2_26_sch_books w1_e2_27_cloth_bedding w1_e2_28_footwear w1_e2_29_furniture w1_e2_30_crokery w1_e2_31_cook_hh_appliance w1_e2_32_recreation_goods w1_e2_33_jewellery w1_e2_34_personal_transport w1_e2_35_therapeutic_appl w1_e2_36_oth_pers_goods w1_e2_37_repair_maintain  {
	gen `var'_pc = (`var'/365)/w1_a1_people_live_hh if w1_cons_missing<=23 & w1_cons_missing!=. 
	replace `var'_pc = 0 if `var'_pc==. & w1_cons_missing<=23 & w1_cons_missing!=. 
}

*calculate and winsor at 98 pctile 
egen w1_total_pc_cons = rowtotal(w1_e2_1_consume_rice_pc w1_e2_1_consume_wheat_pc w1_e2_1_consume_ragi_pc w1_e2_1_consume_oth_cerel_pc w1_e2_2_consume_lentils_pc w1_e2_2_consume_oth_puls_pc w1_e2_3_consume_milk_pc w1_e2_4_consume_milk_prdct_pc w1_e2_5_consume_edible_oil_pc w1_e2_6_consume_veg_pc w1_e2_7_consume_fruit_pc w1_e2_8_consume_egg_fish_pc w1_e2_9_consume_sugar_pc w1_e2_10_consume_salt_spice_pc w1_e2_11_cons_oth_food_item w1_e2_12_consume_pan_tob_pc w1_e2_13_consume_fuel_light_pc w1_e2_14_consume_entertain_pc w1_e2_15_consume_person_care_pc w1_e2_16_consume_toilet_arti_pc w1_e2_17_consume_sundry_arti_pc w1_e2_18_consume_excl_convey_pc w1_e2_19_consume_conveyce_pc w1_e2_20_consume_rent_pc w1_e2_21_consume_taxes_pc w1_e2_22_medical_exp_pc w1_e2_24_medical_pc w1_e2_25_tution_fees_pc w1_e2_26_sch_books_pc w1_e2_27_cloth_bedding_pc w1_e2_28_footwear_pc w1_e2_29_furniture_pc w1_e2_30_crokery_pc w1_e2_31_cook_hh_appliance_pc w1_e2_32_recreation_goods_pc w1_e2_33_jewellery_pc w1_e2_34_personal_transport_pc w1_e2_35_therapeutic_appl_pc w1_e2_36_oth_pers_goods_pc w1_e2_37_repair_maintain_pc)
winsor2 w1_total_pc_cons, replace cuts(0 99)

egen w1_nondur_pc_cons = rowtotal(w1_e2_1_consume_rice_pc w1_e2_1_consume_wheat_pc w1_e2_1_consume_ragi_pc w1_e2_1_consume_oth_cerel_pc w1_e2_2_consume_lentils_pc w1_e2_2_consume_oth_puls_pc w1_e2_3_consume_milk_pc w1_e2_4_consume_milk_prdct_pc w1_e2_5_consume_edible_oil_pc w1_e2_6_consume_veg_pc w1_e2_7_consume_fruit_pc w1_e2_8_consume_egg_fish_pc w1_e2_9_consume_sugar_pc w1_e2_10_consume_salt_spice_pc w1_e2_11_cons_oth_food_item w1_e2_12_consume_pan_tob_pc w1_e2_13_consume_fuel_light_pc w1_e2_14_consume_entertain_pc w1_e2_15_consume_person_care_pc w1_e2_16_consume_toilet_arti_pc w1_e2_17_consume_sundry_arti_pc w1_e2_18_consume_excl_convey_pc w1_e2_19_consume_conveyce_pc w1_e2_21_consume_taxes_pc w1_e2_25_tution_fees_pc w1_e2_26_sch_books_pc w1_e2_27_cloth_bedding_pc w1_e2_28_footwear_pc w1_e2_33_jewellery_pc w1_e2_35_therapeutic_appl_pc  w1_e2_37_repair_maintain_pc)
winsor2 w1_nondur_pc_cons, replace cuts(0 99)

egen w1_food_pc_cons = rowtotal(w1_e2_1_consume_rice_pc w1_e2_1_consume_wheat_pc w1_e2_1_consume_ragi_pc w1_e2_1_consume_oth_cerel_pc w1_e2_2_consume_lentils_pc w1_e2_2_consume_oth_puls_pc w1_e2_3_consume_milk_pc w1_e2_4_consume_milk_prdct_pc w1_e2_5_consume_edible_oil_pc w1_e2_6_consume_veg_pc w1_e2_7_consume_fruit_pc w1_e2_8_consume_egg_fish_pc w1_e2_9_consume_sugar_pc w1_e2_10_consume_salt_spice_pc w1_e2_11_cons_oth_food_item)
winsor2 w1_food_pc_cons, replace cuts(0 99)

egen w1_med_pc_cons = rowtotal(w1_e2_22_medical_exp_pc w1_e2_24_medical_pc)
winsor2 w1_med_pc_cons, replace cuts(0 99)

*Calculate share of spending on food and medical for food security measures 
gen w1_med_exp_share = w1_food_pc_cons/w1_total_pc_cons
gen w1_food_exp_share = w1_med_pc_cons/w1_total_pc_cons

*Calculate percent below poverty line 
*The 2019 WB extreme poverty line was 38 rupees per day PPP. The low-middle income poverty line was 64 rupees per day PPP. We use these as thresholds for the 2019 baseline survey and then convert the wave 1 prices to 2019 PPP using the OECD statistics, scaling by 23.138/21.073 (the 2021 and 2019 PPPs to the USD respectively). 
gen w1_below_ext_pov = 0 if w1_nondur_pc_cons!=. 
replace w1_below_ext_pov = 1 if w1_nondur_pc_cons>=0 & w1_nondur_pc_cons<=38 *(23.138/21.073)

gen w1_below_lowmid_pov = 0 if w1_nondur_pc_cons!=. 
replace w1_below_lowmid_pov = 1 if w1_nondur_pc_cons>=0 & w1_nondur_pc_cons<=64*(23.138/21.073)


/**************************************************************
Self-rated financial status 
**************************************************************/
*BL 
gen B_self_fin = B_f6_1_person_know_benef

gen w1_self_fin = w1_f6_1_person_know_benef if w1_f6_1_person_know_benef>=1 & w1_f6_1_person_know_benef<=10 

/**************************************************************
Food and financial security 
**************************************************************/

*no bank account 
gen B_no_bank_acct = 1 if B_b1_bank_ac==2 | B_q8_c1_bank_account==2 
replace B_no_bank_acct=0 if B_b1_bank_ac==1 | B_q8_c1_bank_account==1

gen w1_no_bank_acct = 1 if w1_b1_bank_ac==2 | w1_q8_c1_bank_account==2 
replace w1_no_bank_acct=0 if w1_b1_bank_ac==1 | w1_q8_c1_bank_account==1

*no insurance 
gen B_no_insur = 1 if B_b2_insu_policy==2 | B_q8_c2_insurance_policy==2 
replace B_no_insur = 0 if B_b2_insu_policy==1 | B_q8_c2_insurance_policy==1

gen w1_no_insur = 1 if w1_b2_insu_policy==2 | w1_q8_c2_insurance_policy==2 
replace w1_no_insur = 0 if w1_b2_insu_policy==1 | w1_q8_c2_insurance_policy==1

*no health insurance 
gen B_no_health_ins = 1 if B_q5_d4_health_ins==2 | B_q8_k3_health_insurance==2 
replace B_no_health_ins = 0 if B_q5_d4_health_ins==1 | B_q8_k3_health_insurance==1

gen w1_no_health_ins = 1 if w1_q5_d4_health_ins==2 | w1_q8_k3_health_insurance==2 
replace w1_no_health_ins = 0 if w1_q5_d4_health_ins==1 | w1_q8_k3_health_insurance==1

*skipped meals in last 12 months 
gen B_skip_meals_12mo = 1 if B_q5_e11_meals_cut==1 
replace B_skip_meals_12mo = 0 if B_q5_e11_meals_cut==2 

gen w1_skip_meals_2mo = 1 if w1_q5_e14_meals_cut==1 
replace w1_skip_meals_2mo = 0 if w1_q5_e14_meals_cut==2

*does not have enough food 
gen B_not_enough_food = 1 if B_q5_e12_enough_food==2 | B_q5_e12_enough_food==3 
replace B_not_enough_food = 0 if B_q5_e12_enough_food==1 

gen w1_not_enough_food = 1 if w1_q5_e11_enough_food==2 | w1_q5_e11_enough_food==3 
replace w1_not_enough_food = 0 if w1_q5_e11_enough_food==1 

*eats less than 3 meals per day 
gen B_less_3_meals = 0 if B_q5_e14_hw_many_meals==3 | B_q8_l11_meals_day==3 
replace B_less_3_meals = 1 if B_q5_e14_hw_many_meals==1 | B_q8_l11_meals_day==1 | B_q5_e14_hw_many_meals==2 | B_q8_l11_meals_day==2

gen w1_less_3_meals = 0 if w1_q5_e13_hw_many_meals==3 | w1_q5_e13_hw_many_meals==3 
replace w1_less_3_meals = 1 if w1_q5_e13_hw_many_meals==1 | w1_q5_e13_hw_many_meals==1 | w1_q5_e13_hw_many_meals==2 | w1_q5_e13_hw_many_meals==2

*lost more than 5kg unintentionally 
gen B_lost_5kg = 1 if B_q5_e10_weight_issue==2 
replace B_lost_5kg = 0 if B_q5_e10_weight_issue==1 | B_q5_e10_weight_issue==3 | B_q5_e10_weight_issue==4 

gen w1_lost_5kg = 1 if w1_q5_e10_weight_issue==2 
replace w1_lost_5kg = 0 if w1_q5_e10_weight_issue==1 | w1_q5_e10_weight_issue==3 | w1_q5_e10_weight_issue==4 

/**************************************************************
Asset ownership 
**************************************************************/
*BL
*bicycle
gen B_own_bicycle = (B_c5_hh_posses_1==1)
*scooter
gen B_own_scooter = (B_c5_hh_posses_2==1)
*car
gen B_own_car = (B_c5_hh_posses_3==1)
*hh phone (landline or mobile)
gen B_own_hh_phone = (B_c5_hh_posses_5==1 | B_c5_hh_posses_6==1)
*computer 
gen B_own_comput = (B_c5_hh_posses_16==1)
*internet
gen B_own_inter = (B_c5_hh_posses_17==1)
*TV
gen B_own_tv = (B_c5_hh_posses_12==1)
*personal cell phone 
gen B_own_pers_cell = 0 if B_b5_mobile_no==2 
replace B_own_pers_cell = 1 if B_b5_mobile_no==1 

*wave 1
*bicycle
gen w1_own_bicycle = (w1_c5_hh_posses_1==1)
*scooter
gen w1_own_scooter = (w1_c5_hh_posses_2==1)
*car
gen w1_own_car = (w1_c5_hh_posses_3==1)
*hh phone (landline or mobile)
gen w1_own_hh_phone = (w1_c5_hh_posses_5==1 | w1_c5_hh_posses_6==1)
*computer 
gen w1_own_comput = (w1_c5_hh_posses_16==1)
*internet
gen w1_own_inter = (w1_c5_hh_posses_17==1)
*TV
gen w1_own_tv = (w1_c5_hh_posses_12==1)
*personal cell phone 
gen w1_own_pers_cell = 0 if w1_b5_mobile_no==2 
replace w1_own_pers_cell = 1 if w1_b5_mobile_no==1 

/**************************************************************
Social outcomes 
**************************************************************/
*BL 
*had conversation in last day 
gen B_convo_in_day = 0 if B_q5_f17_lst_time_conv>=2 & B_q5_f17_lst_time_conv<=6 
replace B_convo_in_day = 1 if B_q5_f17_lst_time_conv==1 

*had meaningful conversation in last day 
gen B_meaning_conv_in_day = 0 if B_q5_f18_meaningful_conv>=2 & B_q5_f18_meaningful_conv<=6 
replace B_meaning_conv_in_day = 1 if B_q5_f18_meaningful_conv==1 

*can make phone calls 
gen B_can_call = 1 if B_b8_make_calls==1 
replace B_can_call = 0 if B_b8_make_calls==2 | B_b8_make_calls==3 

*talks on phone weekly 
gen B_phones_weekly = 1 if B_q5_g7_5_ph_talk==4 | B_q5_g7_5_ph_talk==5 
replace B_phones_weekly = 0 if B_q5_g7_5_ph_talk==1 | B_q5_g7_5_ph_talk==2 | B_q5_g7_5_ph_talk==3 

*had a visit in the last week 
gen B_visit_last_week = 0 if B_q5_g1_visit==2 | B_q5_g3_visit==2 | B_q8_m1_lst_week_visit_house==2 | B_q8_m3_lst_week_vist_name==2 
replace B_visit_last_week= 1 if B_q5_g1_visit==1 | B_q5_g3_visit==1 | B_q8_m1_lst_week_visit_house==1 | B_q8_m3_lst_week_vist_name==1

*can borrow money if needed 
gen B_can_borrow = 0 if B_q5_g6_borrow==2
replace B_can_borrow = 1 if B_q5_g6_borrow==1

*can call someone in medical emergency 
gen B_call_emergen = 0 if B_q5_g5_medical_emergency==2 
replace B_call_emergen = 1 if B_q5_g5_medical_emergency==1

*feels respected in community 
gen B_respected_commun = 0 if B_q5_g11_people_vill==3 
replace B_respected_commun = 1 if B_q5_g11_people_vill==1 | B_q5_g11_people_vill==2

*trusts neighbors 
gen B_trusts_neighb = 1 if B_q5_g10_trust_neighbor==1 | B_q5_g10_trust_neighbor==2 
replace B_trusts_neighb = 0 if  B_q5_g10_trust_neighbor==3 | B_q5_g10_trust_neighbor==4 | B_q5_g10_trust_neighbor==5

*Wave 1 
*had conversation in last day 
gen w1_convo_in_day = 0 if w1_q5_f17_lst_time_conv>=2 & w1_q5_f17_lst_time_conv<=6 
replace w1_convo_in_day = 1 if w1_q5_f17_lst_time_conv==1 

*had meaningful conversation in last day 
gen w1_meaning_conv_in_day = 0 if w1_q5_f18_meaningful_conv>=2 & w1_q5_f18_meaningful_conv<=6 
replace w1_meaning_conv_in_day = 1 if w1_q5_f18_meaningful_conv==1 

*can make phone calls 
gen w1_can_call = 1 if w1_b8_make_calls==1 
replace w1_can_call = 0 if w1_b8_make_calls==2 | w1_b8_make_calls==3 

*talks on phone weekly 
gen w1_phones_weekly = 1 if w1_q5_g7_5_ph_talk==4 | w1_q5_g7_5_ph_talk==5 
replace w1_phones_weekly = 0 if w1_q5_g7_5_ph_talk==1 | w1_q5_g7_5_ph_talk==2 | w1_q5_g7_5_ph_talk==3 

*had a visit in the last week 
gen w1_visit_last_week = 0 if w1_q5_g1_visit==2 | w1_q5_g3_visit==2 | w1_q8_m1_lst_week_visit_house==2 | w1_q8_m3_lst_week_vist_name==2 
replace w1_visit_last_week= 1 if w1_q5_g1_visit==1 | w1_q5_g3_visit==1 | w1_q8_m1_lst_week_visit_house==1 | w1_q8_m3_lst_week_vist_name==1

*can borrow money if needed 
gen w1_can_borrow = 0 if w1_q5_g6_borrow==2
replace w1_can_borrow = 1 if w1_q5_g6_borrow==1

*can call someone in medical emergency 
gen w1_call_emergen = 0 if w1_q5_g5_medical_emergency==2 
replace w1_call_emergen = 1 if w1_q5_g5_medical_emergency==1

*trusts neighbors 
gen w1_trusts_neighb = 1 if  w1_q5_g10_trust_neighbor==1 | w1_q5_g10_trust_neighbor==2 
replace w1_trusts_neighb = 0 if  w1_q5_g10_trust_neighbor==3 | w1_q5_g10_trust_neighbor==4 | w1_q5_g10_trust_neighbor==5

/**************************************************************
Health data 
**************************************************************/
*BL 
*Joint self-reported and measured health outcomes: we pull data from both the individual survey and the health measurements to create the following categories of outcomes: objective disease prevalence (taken just from measured data), self-reported disease prevalence (taken from the individual data), and disease targeting, eg. whether the individual is addressing the disease with a medical treatment or change in behavior (taken from the individual data). 

*********Arthritis 
*objective prevalence 
gen B_has_arthrit = 0 if B_q7_4_c_creative!=. 
replace B_has_arthrit = 1 if B_q7_4_c_creative>=10 & B_has_arthrit!=. 

*self-reported
gen B_rep_arthrit = 0 if B_q8_j1_diagonsed_health_proff==2 | B_q5_c36_diagnosed==2 
replace B_rep_arthrit = 1 if B_q8_j1_diagonsed_health_proff==1 | B_q5_c36_diagnosed==1 

*getting treatment for arthritis 
gen B_treat_arthrit = 0 if B_rep_arthrit!=. 
replace B_treat_arthrit =1 if B_q5_c4_tkng_medicatins==1 | B_q5_c5_surgery==1 | B_q8_j2_medications==1 | B_q8_j3_lst_2yr_surgery==1 

*discrepancies in having and reporting; treating 
gen B_has_arth_not_rep = 0 if B_has_arthrit!=. & B_rep_arthrit!=. 
replace B_has_arth_not_rep = 1 if B_has_arthrit==1 & B_rep_arthrit==0 

gen B_has_arth_not_tre = 0 if B_has_arthrit!=. & B_treat_arthrit!=. 
replace B_has_arth_not_tre = 1 if B_has_arthrit==1 & B_treat_arthrit==0 

*********Lung/heart disease 
*objective prevalence 
gen B_has_lung_heart = 0 if B_q3_4_spo2_entry!=. 
replace B_q3_4_spo2_entry = . if B_q3_4_spo2_entry<82 //signifies error with machine 
replace B_q3_3_rep_rate=. if B_q3_3_rep_rate==40 // also signifies error 
replace B_has_lung_heart = 1 if B_q3_4_spo2_entry<94 & B_q3_4_spo2_entry!=. 
replace B_has_lung_heart = 1 if B_q3_a9_takecare_hh==1 & B_q3_a10_movng_around==1 & B_q3_3_rep_rate>18 & B_q3_3_rep_rate!=. 
replace B_has_lung_heart = 1 if ((B_q3_a9_takecare_hh>1 & B_q3_a9_takecare_hh!=.) | (B_q3_a10_movng_around>1 & B_q3_a10_movng_around!=.)) & B_q3_3_rep_rate>25 & B_q3_3_rep_rate!=. 

*self-reported 
gen B_rep_heart_lung = 0 if B_q8_j11_diag_heart_pbrlm==2 | B_q5_c14_diagnosed==2 | B_q5_c40_diagnosed==2 | B_q8_j36_diag_lung==2 | B_q5_c48_diagnsd_tb==2 | B_q8_j44_diag_tuberculosis==2 
replace B_rep_heart_lung = 1 if B_q8_j11_diag_heart_pbrlm==1 | B_q5_c14_diagnosed==1 | B_q5_c40_diagnosed==1 | B_q8_j36_diag_lung==1 | B_q5_c48_diagnsd_tb==1 | B_q8_j44_diag_tuberculosis==1 

*getting treatment for lung/heart disease 
gen B_treat_lung_heart = 0 if B_rep_heart_lung!=. 
replace B_treat_lung_heart = 1 if B_rep_heart_lung==1 & (B_q8_j13_recv_any_treat!=. | B_q8_j14_taking_medication==1 | B_q8_j39_take_diagonsed==1 | B_q8_j46_long_medi_taken!=. | B_q5_c43_medicatns==1 | (B_q5_c50_medfctn_tb>=1 & B_q5_c50_medfctn_tb<=6) | B_q5_c15_1receivd_treatmnt_1==1 | B_q5_c15_1receivd_treatmnt_2==1 | B_q5_c15_1receivd_treatmnt_3==1 | B_q5_c16_medicatins==1 | B_q5_c17_dctr==1 )

*discrepancies in having and reporting; treating 
gen B_has_lung_not_rep = 0 if B_has_lung_heart!=. & B_rep_heart_lung!=. 
replace B_has_lung_not_rep = 1 if B_has_lung_heart==1 & B_rep_heart_lung==0 

gen B_has_lung_not_tre = 0 if B_has_lung_heart!=. & B_treat_lung_heart!=. 
replace B_has_lung_not_tre = 1 if B_has_lung_heart==1 & B_treat_lung_heart==0 

*********Kidney disease 
*objective prevalence 
gen B_has_kidney = 0 if B_q7_3_serum!=. 
replace B_has_kidney = 1 if B_q7_3_serum>1.2 & gender==2 & B_q7_3_serum!=. 
replace B_has_kidney = 1 if B_q7_3_serum>1.4 & gender==1 & B_q7_3_serum!=. 

*self-reported 
gen B_rep_kidney = 0 if B_q5_c60_kidney_disease==2 | B_q8_j55_health_prof_kidney==2 
replace B_rep_kidney = 1 if B_q5_c60_kidney_disease==1 | B_q8_j55_health_prof_kidney==1

*getting treatment for kidney disease 
gen B_treat_kidney = 0 if B_rep_kidney!=. 
replace B_treat_kidney = 1 if B_q8_j56_recv_dialysis==2 | B_q8_j56_recv_dialysis==3 | B_q8_j58_kidney_transplent==1 | B_q8_j59_take_medi_kidney==1 | B_q5_c61_dialysis==2 | B_q5_c61_dialysis==1 | B_q5_c63_kidney_transplnt==1 | B_q5_c64_oth_medicatns==1 

*discrepancies in having and reporting; treating 
gen B_has_kid_not_rep = 0 if B_has_kidney!=. & B_rep_kidney!=. 
replace B_has_kid_not_rep = 1 if B_has_kidney==1 & B_rep_kidney==0 

gen B_has_kid_not_tre = 0 if B_has_kidney!=. & B_treat_kidney!=. 
replace B_has_kid_not_tre = 1 if B_has_kidney==1 & B_treat_kidney==0 

*********Hearing impairment 
*objective prevalence 
gen B_has_hearimp = 0 if B_q4_1_hearngloss_leftear==2 | B_q4_1_hearngloss_rightear==2 | B_q4_1_1_hearngaid_leftear==2 | B_q4_1_1_hearngaid_rightear==2 | B_q4_2_earexam_leftear==3 | B_q4_2_earexam_rightear==3
replace B_has_hearimp = 1 if B_q4_1_hearngloss_leftear==1 | B_q4_1_hearngloss_rightear==1 | B_q4_1_1_hearngaid_leftear==1 | B_q4_1_1_hearngaid_rightear==1 | B_q4_2_earexam_leftear==1 | B_q4_2_earexam_leftear==2 | B_q4_2_earexam_rightear==1| B_q4_2_earexam_rightear==2 | B_q4_3_1_rinnetest_leftear==2 | B_q4_3_1_rinnetest_leftear==3 | B_q4_3_1_rinnetest_rightear==2 | B_q4_3_1_rinnetest_rightear==3 | B_q4_3_2_webertest_leftear==2 | B_q4_3_2_webertest_leftear==3 | B_q4_3_2_webertest_rightear==2 | B_q4_3_2_webertest_rightear==3 | B_q4_4_patient_refrd==1

*self-reported 
gen B_rep_hearimp = 0 if B_q8_g2_curr_wear_hear_aid==2 | B_q8_g5_normal_voice==1 | B_q5_b10_hearing_aid==2 | B_q5_b12_difficulty==1 
replace B_rep_hearimp = 1 if B_q8_g2_curr_wear_hear_aid==1 | B_q5_b10_hearing_aid==1 | (B_q8_g5_normal_voice>=2 & B_q8_g5_normal_voice<=5) | (B_q5_b12_difficulty>=2 & B_q5_b12_difficulty<=5)

*getting treatment for hearing  
gen B_treat_hearimp = 0 if B_rep_hearimp!=. 
replace B_treat_hearimp = 1 if B_rep_hearimp==1 & ((B_q8_g1_hear_pbrlm>=1 & B_q8_g1_hear_pbrlm<=4) | (B_q8_g3_hearing_aid>=1 & B_q8_g3_hearing_aid<=3) | (B_q5_b9_lst_tm_hearing>=1 & B_q5_b9_lst_tm_hearing<=4) | (B_q5_b11_hearing_aid_wear>=1 & B_q5_b11_hearing_aid_wear<=3))

*discrepancies in having and reporting; treating 
gen B_has_hear_not_rep = 0 if B_has_hearimp!=. & B_rep_hearimp!=. 
replace B_has_hear_not_rep = 1 if B_has_hearimp==1 & B_rep_hearimp==0 

gen B_has_hear_not_treat = 0 if B_has_hearimp!=. & B_treat_hearimp!=. 
replace B_has_hear_not_treat = 1 if B_has_hearimp==1 & B_treat_hearimp==0 


*********Cataract 
*objective prevalence 
gen B_has_cataract = 0 if B_q5_7_cataract_lefteye==2 | B_q5_7_cataract_righteye==2 
replace B_has_cataract = 1 if B_q5_7_cataract_lefteye==1 | B_q5_7_cataract_righteye==1

*self-reported 
gen B_rep_cataract = 0 if B_q8_f3_lst_5yrs_eye_pbrlm_1 ==0 | B_q5_b4_eye_prblm_diagnosd_1==0
replace B_rep_cataract = 1 if B_q8_f3_lst_5yrs_eye_pbrlm_1 ==1 | B_q5_b4_eye_prblm_diagnosd_1==1

*treatment 
gen B_treat_cataract= 0 if B_rep_cataract!=. 
replace B_treat_cataract = 1 if B_q8_f4_lst_5yrs_eye_surgery==1 | B_q5_b5_eye_surgery==1

*discrepancies in having and reporting; treating 
gen B_has_cat_not_rep = 0 if B_has_cataract!=. & B_rep_cataract!=. 
replace B_has_cat_not_rep = 1 if B_has_cataract==1 & B_rep_cataract==0 

gen B_has_cat_not_treat = 0 if B_has_cataract!=. & B_treat_cataract!=. 
replace B_has_cat_not_treat = 1 if B_has_cataract==1 & B_treat_cataract==0 

*********Diabetes 
*objective prevalence 
gen B_has_diab = 0 if B_q7_2_hba1c!=. 
replace B_has_diab = 1 if B_q7_2_hba1c>=5.7 & B_q7_2_hba1c!=. 

*self-reported 
gen B_rep_diab = 0 if B_q5_c28_diagnosed==2 | B_q8_j25_ever_diag_diabete==2 | B_q5_c27_diabetes_tested==2 | B_q8_j24_tested_diabets==2
replace B_rep_diab = 1 if B_q5_c28_diagnosed==1 | B_q8_j25_ever_diag_diabete==1 

*treatment 
gen B_treat_diab = 0 if B_rep_diab!=. 
replace B_treat_diab = 1 if B_rep_diab==1 & (B_q5_c30_insulin==1 | B_q5_c32_dietary_changes== 1 | B_q5_c33_physcl_actvty==1 | B_q8_j27_take_insulin==1 | B_q8_j28_dietry_chngs==1 | B_q8_j29_physcl_actvty==1)

*discrepancies in having and reporting; treating 
gen B_has_diab_not_rep = 0 if B_has_diab!=. & B_rep_diab!=. 
replace B_has_diab_not_rep = 1 if B_has_diab==1 & B_rep_diab==0 

gen B_has_diab_not_treat = 0 if B_has_diab!=. & B_treat_diab!=. 
replace B_has_diab_not_treat = 1 if B_has_diab==1 & B_treat_diab==0 


*********Hypertension  
*objective prevalence 
gen B_has_hypert = 0 if B_q3_1_bp_entry_hg!=. 
replace B_has_hypert = 1 if (B_q3_1_bp_entry_hg>=80 | B_q3_1_bp_entry_mm>=130) & B_q3_1_bp_entry_hg!=.

*self-reported 
gen B_rep_hypert = 0 if B_q5_c21_diagnosed!=. | B_q8_j18_ever_diagonsed_bp!=. 
replace B_rep_hypert = 1 if B_q5_c22_high_bp==1 | B_q8_j19_diagonsed_hbp==1 

*treatment 
gen B_treat_hypert = 0 if B_rep_hypert!=. 
replace B_treat_hypert = 1 if B_rep_hypert==1 & (B_q5_c23_medicaitons==1 | B_q5_c24_dietary_changes==1 | B_q5_c25_physical_actvty==1 | B_q8_i20_medications_lst12m==1 | B_q8_j21_dietery==1 | B_q8_j22_physical_activity==1)

*discrepancies in having and reporting; treating 
gen B_has_hyp_not_rep = 0 if B_has_hypert!=. & B_rep_hypert!=. 
replace B_has_hyp_not_rep = 1 if B_has_hypert==1 & B_rep_hypert==0 

gen B_has_hyp_not_treat = 0 if B_has_hypert!=. & B_treat_hypert!=. 
replace B_has_hyp_not_treat = 1 if B_has_hypert==1 & B_treat_hypert==0 

/**************************************************************
Household type: 
**************************************************************/

preserve 
use "$user/Tamil Nadu Aging/Data/Baseline/2. Final Cleaned Data/DES_Ind_Profile_Matched.dta", clear 
rename q010_1_elder_id elder_id
rename a3_5_marital_status_ B_a3_5_marital_status_
tempfile maritalstat
save `maritalstat'
restore 

merge 1:1 elder_id using `maritalstat'
drop _merge 

*then merge in ages of people in hh 
preserve 
use "$user/Tamil Nadu Aging/Data/Baseline/2. Final Cleaned Data/HH_Completed.dta", clear
rename q0_8_1_hh_id hh_id
keep a3_1_age_* a3_2_person_apprx_age_* hh_id
tempfile hh_ages
save `hh_ages'
restore

merge m:1 hh_id using `hh_ages'
drop if _merge==2 
drop _merge


*gen elders num in hh
gen B_hh_children=0 
forvalues i = 1/14 {
	replace B_hh_children= 1 if a3_1_age_`i'>=1 & a3_1_age_`i'<=20
	replace B_hh_children = 1 if a3_2_person_apprx_age_`i'==1 | a3_2_person_apprx_age_`i'==1==2
}

tab B_hh_children
gen B_hh_type = "ELA" if ELA_at_BL==1 
replace B_hh_type = "Spouse only" if B_a3_5_marital_status_==1 & B_a1_people_live_hh==2 
replace B_hh_type = "Spouse + others, no children" if B_a3_5_marital_status_==1 & B_a1_people_live_hh>2
replace B_hh_type = "Spouse + others, children" if B_a3_5_marital_status_==1 & B_a1_people_live_hh>2 & B_hh_children==1
replace B_hh_type = "No spouse but others, no children" if B_a3_5_marital_status_!=1 & B_a1_people_live_hh>1
replace B_hh_type = "No spouse but others, children" if B_a3_5_marital_status_!=1 & B_a1_people_live_hh>1  & B_hh_children==1
tab B_hh_type
/**************************************************************
Save 
**************************************************************/

save "$user/Tamil Nadu Aging/Data/General Panel/merged_panel_official.dta", replace 


