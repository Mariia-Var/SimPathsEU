***************************************************************************************************
* 		Project: Simpaths EU 
*       Labour supply estimation-get sample for adult children and generate the vbls needed for ls 
**************************************************************************************************

global file_log="singles_sample-dropped sample"

cd "$local_data"

capture log close
log using "$file_log", replace
pwd
clear all
set seed 1																//same seed gives same results	

*version 15

//update 1/2/2021: at the end of the do file, divide this sample into two subsamples: singles_indep_wage`i'-dropped_sample and singles_dep_wage`i'-dropped_sample

*loop through wage1, wage2: hours of work estimation for each gender (triple loop)

//loop over wage1, wage2
foreach i in 1 2{   //loop begin for wage imputation method 
use "individuals_output_wage`i'-dropped_sample",clear

gen sim_flag=0  //needed because this should contain the same variables as in dataset to be appended

merge m:1 idperson using "temp_file-dropped_sample.dta"												//add additional information
assert _merge==3
drop _merge

duplicates report temp_idorigperson2  //count how many unique individuals there are
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


//target sample: "singles", and keep only $n_choices rows for each individual
keep if temp_singles==1 &temp_choicehh!=. 
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)

//check data structure
bysort temp_idorigperson2: egen double mean_choicehh=mean(temp_choicehh)  //compute the mean of flag of hh choice for the same individual
assert mean_choicehh==1/($n_choices) if temp_singles==1  //for an individual in "singles", 1 option is chosen from $n_choices options
assert lhw!=. & yem!=. & yse!=. if temp_singles==1 //make sure lhw, yse, yse are not missing for sample to be included in labour supply estimation

************
* Leisure  *
************
gen leisure=24*7-lhw																//define leisure for utility function		
label variable leisure "leisure"

************************
* fixed costs dummies  *
************************

// participation dummy	
gen fixed_cost = (lhw > 0)
label variable fixed_cost "fixed cost for labour"

// gen part-time fixed cost
gen part_fixed_cost = (lhw < 40 & lhw > 0)   // in HU full-time work is 40 hours per week
label variable part_fixed_cost "fixed cost for part-time work"

// gen full-time fixed cost
gen full_fixed_cost = (lhw >= 40)
label variable full_fixed_cost "fixed cost for full-time work"

// gen 40 hours dummy 
gen fixed_cost40 = (lhw == 40)
label variable fixed_cost40 "fixed cost for 40 hours work"

// gen 50+ hours dummy 
gen fixed_cost50 = (lhw > 40)
label variable fixed_cost50 "fixed cost for overtime work"


* interactions with gender 

// gen interaction of fixed cost with gender 
gen fixc_dgn = fixed_cost*dgn
lab var fixc_dgn "fixed cost for labour$\times$1(male)"

// gen interaction of full-time fixed cost with gender
gen full_fixc_dgn = full_fixed_cost*dgn
lab var full_fixc_dgn "full fixed cost for labour$\times$1(male)"

// gen interaction of part-time fixed cost with gender
gen part_fixc_dgn = part_fixed_cost*dgn
lab var part_fixc_dgn "part fixed cost for labour$\times$1(male)"

// gen interaction of 40 hours fixed cost with gender
gen fixc40_dgn = fixed_cost40*dgn
lab var fixc40_dgn "40-hour fixed cost$\times$1(male)"

// gen interaction of 50+ hours fixed cost with gender
gen fixc50_dgn = fixed_cost50*dgn
lab var fixc50_dgn "50-hour fixed cost$\times$1(male)"

***********************
* experience variable *
***********************
label variable liwwh "work history in years"
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

***********************************
* Generation of variables squared *
***********************************
		foreach var in leisure  hhcon {
			gen `var'2=(`var'^2) 
			label variable `var'2 "`var'^2"
		}

//rescale age and age^2
gen age_100=dag/100
label variable age_100 "age/100"

gen age2_10000= temp_age2/10000
label variable age2_10000 "age^2/10000"

//rescale hhcon and hhcon^2
gen hhcon_100=hhcon/100
label variable hhcon_100 "income/100"

gen hhcon2_10000= hhcon2/10000
label variable hhcon2_10000 "income^2/10000"

****************************************************
* generation of interactions with household income *
****************************************************
global incomex "age_100 age2_10000 temp_n_ch temp_d_ch2 temp_hhsize" //temp_dhe_1  temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5
foreach x of varlist $incomex{
gen hhcon_100_`x'=hhcon_100*`x'
local varlabel : var label `x'
label variable hhcon_100_`x' "income/100#`varlabel'"
}

********************************************************
*generation of interactions with fixed cost for labour *
********************************************************
#delimit ;

global fixedcostx "temp_n_ch temp_d_ch2 temp_p_sick_dis temp_p_student
temp_p_pensioner
temp_d_deh_L temp_d_deh_M temp_d_deh_H
temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6 temp_region7" ;
// temp_dhe_1 temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5

#delimit cr

foreach x of varlist $fixedcostx{
gen fixc_`x'=fixed_cost*`x'
local varlabel : var label `x'
label variable fixc_`x' "fixed cost for labour#`varlabel'"
}

******************************************
*generation of interactions with leisure *
******************************************
#delimit ;

global lx "hhcon_100 age_100 age2_10000 temp_n_ch temp_d_ch*
temp_d_deh_L temp_d_deh_M temp_d_deh_H
temp_region1 temp_region2 temp_region3 temp_region4 temp_region5 temp_region6 temp_region7
temp_hhsize" ;
// temp_dhe_1 temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5

#delimit cr

foreach x of varlist $lx{
gen lei_`x'=leisure*`x'
local varlabel : var label `x'
label variable lei_`x' "leisure#`varlabel'"
}

*estimate labour supply model and compute predicted choices
// LS model of choices (0,30,40,50). By default assumes quadratic utility. verbose shows more detail

bysort temp_idorigperson2: egen min_hhcon=min(hhcon)
drop if min_hhcon<=0                        //consumption is not allowed to be 0 or negative for lslogit
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)

//divide this sample into two subsamples:

/*DP: Added filter for adult children for consistency with simulations , 15 Nob 2025 */
//singles_indep_wage`i'-dropped_sample
preserve
keep if temp_singles_indep==1 & temp_adultchildflag==1 
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)

save singles_indep_wage`i'-dropped_sample,replace
restore

//singles_dep_wage`i'-dropped_sample
preserve
keep if temp_singles_dep==1
save singles_dep_wage`i'-dropped_sample,replace
restore

save singles_wage`i'-dropped_sample,replace //still save this as will be used in EM sample (1.1wage)

}  //loop end for wage imputation method
log close


