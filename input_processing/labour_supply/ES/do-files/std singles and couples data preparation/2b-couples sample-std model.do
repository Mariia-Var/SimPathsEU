*************************************************************************
* 			Project: Simpaths EU 
*			Labour supply estimation-get sample for couples and generate the vbls needed for ls (std couples)
*************************************************************************

global file_log="${log}/couples_sample-std model"

cd "$local_data"

capture log close
log using "$file_log", replace
pwd
clear all
set seed 1																//same seed gives same results	

*version 15

*estimation of labour supply-loop through :wage1, wage2; hours of work estimation  (double loop)
foreach i in 1 2{   //loop begin for wage imputation method 
//local i=1 
use "individuals_output_wage`i'",clear

*use individuals_output_wage2,clear //note that temp_idorigperson2 and other temp vbls are not in the EM output file

merge 1:1 idperson using "temp_file.dta"				//add additional information
assert _merge==3
drop _merge

duplicates report temp_idorigperson2 if temp_couples==1 //count how many unique individuals there are
di r(unique_value)

*******************************
* Household disposable income *
*******************************
bysort idhh: egen hhcon=sum(ils_dispy) //hh income, should be done before keeping only the target sample
//assert hhcon==. if sim_flag==1
label variable hhcon "household disposable income"

* Log income: captures diminishing marginal utility of income.
* Defined only for positive income; observations with income <= 0 are missing.
gen lnhhcon = ln(hhcon) if hhcon > 0
label variable lnhhcon "Log household disposable income"

* IHS income: allows for zero and negative income while providing
* a transformation similar to the log for large positive values.Defined for positive, zero and negative income; approximates a log transformation for large positive income.
gen ihshhcon = asinh(hhcon)
label variable ihshhcon "IHS household disposable income"

//target sample: flexible couples
keep if temp_couples==1 &temp_choicehh!=. 
//check data structure
bysort temp_idorigperson2: egen double mean_choicehh=mean(temp_choicehh)  //compute the mean of flag of hh choice for the same individual
assert mean_choicehh==1/($n_choices^2) //for an individual in flexible couples, 1 option is chosen from ($n_choices)^2 options
assert lhw!=. & yem!=. & yse!=. if temp_couples==1 //make sure lhw, yse, yse are not missing for sample to be included in labour supply estimation


************
* Leisure  *
************
gen leisure=24*7-lhw	
replace leisure=0 if leisure<0 																//define leisure for utility function		
label variable leisure "male leisure"

//generation of male leisure squared
gen leisure2=leisure^2
label variable leisure2 "male leisure^2"

************************
* fixed costs dummies  *
************************

//fixed cost for labour (participation dummy) 
gen fixed_cost=(lhw>0)																//define a fixed-cost of work (dummy)
label variable fixed_cost "male fixed cost for labour"

//gen full-time fixed cost
gen full_fixed_cost=(lhw>=40)
label variable full_fixed_cost "male fixed cost for full-time work"

//gen part-time fixed cost
gen part_fixed_cost=(lhw<40 &lhw>0)   //full-time work is 40 hours per week
label variable part_fixed_cost "male fixed cost for part-time work"

// gen 40 hours dummy 
gen fixed_cost40 = (lhw == 40)
label variable fixed_cost40 "male fixed cost for 40 hours work"

// gen 50+ hours dummy 
gen fixed_cost50 = (lhw > 40)
label variable fixed_cost50 "male fixed cost for overtime work"

********************************
* Generation of hhcon squared  *
********************************
		foreach var in hhcon {
			gen `var'2=(`var'^2) 
			label variable `var'2 "`var'^2"
		}
		
//rescale hhcon and hhcon^2
gen hhcon_100=hhcon/100
label variable hhcon_100 "income/100"

gen hhcon2_10000= hhcon2/10000
label variable hhcon2_10000 "income^2/10000"	
	
**********************
* partners' mean age *
**********************
add_partner_variables "dag" 
rename partner_* sp_*  //just to make the names shorter      

gen temp_mean_age=(dag+sp_dag)/2   
label variable temp_mean_age "partners' mean age"

gen temp_mean_age2=temp_mean_age^2  //partners' mean age squared
label variable temp_mean_age2 "partners' mean age^2"

//rescale partners' mean age and age^2
gen mean_age_100=temp_mean_age/100
label variable mean_age_100 "partners' mean age/100"

gen mean_age2_10000=temp_mean_age2/10000
label variable mean_age2_10000 "partners' mean age^2/10000"
		
//rescale male age and age^2
gen age_100=dag/100
label variable age_100 "male age/100"

gen age2_10000= temp_age2/10000
label variable age2_10000 "male age^2/10000"

**************************************************
*generation of interactions with household income*
**************************************************
global incomex "mean_age_100 mean_age2_10000 temp_n_ch temp_d_ch2 temp_hhsize temp_dhe_1  temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5" 
foreach x of varlist $incomex{
gen hhcon_100_`x'=hhcon_100*`x'
local varlabel : var label `x'
label variable hhcon_100_`x' "income/100#`varlabel'"
}

************************************************************
*generation of interactions with male fixed cost for labour*
************************************************************
*global fixedcostx "temp_n_ch temp_d_ch2 temp_d_ch6 temp_d_ch12 temp_d_ch17 temp_d_deh_L temp_d_deh_M temp_d_deh_H temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6 temp_region7 temp_dhe_1  temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5" 
#delimit ;

global fixedcostx "temp_n_ch temp_d_ch2 temp_d_ch6 temp_d_ch12 temp_d_ch17
temp_d_deh_L temp_d_deh_M temp_d_deh_H
temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6 temp_region7
temp_dhe_1 temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5" ;

#delimit cr

foreach x of varlist $fixedcostx{
gen fixc_`x'=fixed_cost*`x'
local varlabel : var label `x'
label variable fixc_`x' "male fixed cost for labour#`varlabel'"
}

************************************************
*generation of interactions with male leisure  *
************************************************
*global lx "hhcon_100 age_100 age2_10000 temp_n_ch temp_d_ch2 temp_d_deh_L temp_d_deh_M temp_d_deh_H temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6 temp_region7 temp_hhsize temp_dhe_1 temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5" 
#delimit ;

global lx "hhcon_100 age_100 age2_10000 temp_n_ch
temp_d_ch2 temp_d_deh_L temp_d_deh_M temp_d_deh_H
temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6 temp_region7
temp_hhsize temp_dhe_1 temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5" ;

#delimit cr

foreach x of varlist $lx{
gen lei_`x'=leisure*`x'
local varlabel : var label `x'
label variable lei_`x' "male leisure#`varlabel'"
}

***********************
* experience variable *
***********************
//gen liwwh_0 = (liwwh==0) //zero experience 
gen liwwh_1 = (liwwh>=0 & liwwh<1) //less than a year experience  
gen liwwh_2 = (liwwh>=1 & liwwh<5) //1 to 5 years experience 
gen liwwh_3 = (liwwh>=5) //5+ years experience 
//lab var liwwh_0 "no experience"
lab var liwwh_1 "0-1 years (new entrants)"
lab var liwwh_2 "1-5 years (some experience)"
lab var liwwh_3 "5+ years (highly experienced)"

gen ln_liwwh = ln(liwwh + 1)

foreach var in liwwh  {
			gen `var'2=(`var'^2) 
			label variable `var'2 "`var'^2"
		}
		
************************	
*add_partner_variables *
************************
#delimit ;

add_partner_variables "full_fixed_cost part_fixed_cost fixed_cost40 fixed_cost50
liwwh_1 liwwh_2 liwwh_3 ln_liwwh liwwh liwwh2 dgn ils_dispy lhw leisure leisure2
lei_hhcon_100 lei_age_100 lei_age2_10000 lei_temp_n_ch lei_temp_d_ch2
lei_temp_d_deh_L lei_temp_d_deh_M lei_temp_d_deh_H
lei_temp_region1 lei_temp_region2 lei_temp_region3 lei_temp_region4
lei_temp_region5 lei_temp_region6 lei_temp_region7 lei_temp_hhsize
fixed_cost
fixc_temp_n_ch fixc_temp_d_ch2 fixc_temp_d_ch6 fixc_temp_d_ch12 fixc_temp_d_ch17
fixc_temp_d_deh_L fixc_temp_d_deh_M fixc_temp_d_deh_H
fixc_temp_region1 fixc_temp_region2 fixc_temp_region3 fixc_temp_region4
fixc_temp_region5 fixc_temp_region6 fixc_temp_region7
temp_d_deh_L temp_d_deh_M temp_d_deh_H
age_100 age2_10000 dhe
temp_dhe_1 temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5
temp_dhe3_1 temp_dhe3_2 temp_dhe3_3
lei_temp_dhe_1 lei_temp_dhe_2 lei_temp_dhe_3 lei_temp_dhe_4 lei_temp_dhe_5
fixc_temp_dhe_1 fixc_temp_dhe_2 fixc_temp_dhe_3 fixc_temp_dhe_4 fixc_temp_dhe_5"
;

#delimit cr

rename partner_* sp_*  //just to make the names shorter      

label variable ils_dispy "male disposable income"

*change labels for the female partners ("male"-> "female")
/*foreach x of varlist full_fixed_cost part_fixed_cost fixed_cost40 fixed_cost50 liwwh_1 liwwh_2 liwwh_3 ln_liwwh liwwh liwwh2 dgn ils_dispy lhw leisure leisure2 lei_* fixed_cost fixc_* temp_d_deh_L temp_d_deh_M temp_d_deh_H age_100 age2_10000 dhe  temp_dhe_1 temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5 temp_dhe3_1 temp_dhe3_2 temp_dhe3_3  { //
local varlabel : var label `x'
label variable sp_`x' "fe`varlabel'"
}*/

#delimit ;

local partner_vars "
full_fixed_cost
part_fixed_cost
fixed_cost40
fixed_cost50
liwwh_1
liwwh_2
liwwh_3
ln_liwwh
liwwh
liwwh2
dgn
ils_dispy
lhw
leisure
leisure2
lei_*
fixed_cost
fixc_*
temp_d_deh_L
temp_d_deh_M
temp_d_deh_H
age_100
age2_10000
dhe
temp_dhe_1
temp_dhe_2
temp_dhe_3
temp_dhe_4
temp_dhe_5
temp_dhe3_1
temp_dhe3_2
temp_dhe3_3" ;

#delimit cr

foreach x of varlist `partner_vars' {
    local varlabel : var label `x'
    label variable sp_`x' "fe`varlabel'"
}


//generating interaction of leisure and sp_leisure
gen lei_sp_lei=leisure*sp_leisure
label variable lei_sp_lei "male leisure#female leisure"   
 
  
* Labels

* Work history
label variable liwwh    "male work history in years"
label variable sp_liwwh "female work history in years"

* Female leisure interactions
label variable sp_lei_age_100 "female leisure#female age/100"
label variable sp_lei_age2_10000 "female leisure#female age^2/10000"


* Female fixed costs
label variable sp_fixed_cost ///
    "female fixed cost of work"
label variable sp_full_fixed_cost ///
    "female fixed cost of full-time work"
label variable sp_part_fixed_cost ///
    "female fixed cost if part-time work"
label variable sp_fixed_cost40 ///
    "female fixed cost for 40 hours work"
label variable sp_fixed_cost50 ///
    "female fixed cost for overtime work"

* Male leisure interactions by education
label variable lei_temp_d_deh_L ///
    "male leisure#male low education (up to lower secondary School; deh = 0-1)"
label variable lei_temp_d_deh_M ///
    "male leisure#male middle education (up to post secondary school; deh = 2-4)"
label variable lei_temp_d_deh_H ///
    "male leisure#male high education (higher education; deh = 5-6)"

* Female leisure interactions by education
label variable sp_lei_temp_d_deh_L ///
    "female leisure#female low education (up to lower secondary School; deh = 0-1)"
label variable sp_lei_temp_d_deh_M ///
    "female leisure#female middle education (up to post secondary school; deh = 2-4)"
label variable sp_lei_temp_d_deh_H ///
    "female leisure#female high education (higher education; deh = 5-6)"

* Children
label variable lei_temp_d_ch2  "male leisure#1(children aged 0-2)"
label variable lei_temp_n_ch   "male leisure#number of children aged 0-17"
label variable sp_lei_temp_d_ch2 "female leisure#1(children aged 0-2)"	
label variable sp_lei_temp_n_ch  "female leisure#number of children aged 0-17"

 
*-------------------------------------------------------------------------------------------------------------
*couples working regimes: lhw*sp_lhw (4*4=16 choices)
*-------------------------------------------------------------------------------------------------------------	
gsort temp_idorigperson2 lhw sp_lhw //Place observations in ascending order of lhw sp_lhw within ascending order of person
bysort temp_idorigperson2:egen temp_hh_alt=seq() //give each working regime a label for the purpose
//label var temp_hh_alt "household working regimes"
label var temp_hh_alt "weekly hours worked"

/*
label define temp_lab_hh_alt 1 "(0,0)" 2 "(0,30)" 3 "(0,40)" 4 "(0,50)" ///
                             5 "(30,0)" 6 "(30,30)" 7 "(30,40)" 8 "(30,50)" ///
                             9 "(40,0)" 10 "(40,30)" 11 "(40,40)" 12 "(40,50)" ///
                            13 "(50,0)" 14 "(50,30)" 15 "(50,40)" 16 "(50,50)" 


label define temp_lab_hh_alt ///
    1  "(0,0)"   2  "(0,25)"  3  "(0,35)"  4  "(0,40)"  5  "(0,50)" ///
    6  "(20,0)"  7  "(20,25)" 8  "(20,35)" 9  "(20,40)" 10 "(20,50)" ///
    11 "(35,0)" 12 "(35,25)" 13 "(35,35)" 14 "(35,40)" 15 "(35,50)" ///
    16 "(40,0)" 17 "(40,25)" 18 "(40,35)" 19 "(40,40)" 20 "(40,50)" ///
    21 "(50,0)" 22 "(50,25)" 23 "(50,35)" 24 "(50,40)" 25 "(50,50)"
*/

label define temp_lab_hh_alt ///
     1 "(0,0)"    2 "(0,20)"   3 "(0,30)"   4 "(0,37)"   5 "(0,40)"   6 "(0,50)" ///
     7 "(20,0)"   8 "(20,20)"  9 "(20,30)" 10 "(20,37)" 11 "(20,40)" 12 "(20,50)" ///
    13 "(37,0)"  14 "(37,20)" 15 "(37,30)" 16 "(37,37)" 17 "(37,40)" 18 "(37,50)" ///
    19 "(40,0)"  20 "(40,20)" 21 "(40,30)" 22 "(40,37)" 23 "(40,40)" 24 "(40,50)" ///
    25 "(50,0)"  26 "(50,20)" 27 "(50,30)" 28 "(50,37)" 29 "(50,40)" 30 "(50,50)" ///
    31 "(60,0)"  32 "(60,20)" 33 "(60,30)" 34 "(60,37)" 35 "(60,40)" 36 "(60,50)"
	
label values temp_hh_alt temp_lab_hh_alt

keep if dgn==1
duplicates report temp_idorigperson2 if temp_couples==1 //count how many unique individuals there are
di r(unique_value)

drop if sp_dgn==.
duplicates report temp_idorigperson2 if temp_couples==1 //count how many unique individuals there are
di r(unique_value)

drop if sp_dgn==1  
duplicates report temp_idorigperson2 if temp_couples==1 //count how many unique individuals there are
di r(unique_value)

assert dgn==1 &sp_dgn==0 //assert partners are of different genders
bysort temp_idorigperson2: egen min_hhcon=min(hhcon)
drop if min_hhcon<=0                        //consumption is not allowed to be 0 or negative for lslogit

duplicates report temp_idorigperson2 if temp_couples==1 //count how many unique individuals there are
di r(unique_value)

gen sim_flag=0  //new in v8


save couples_wage`i',replace
}  //loop end for wage imputation method

log close
