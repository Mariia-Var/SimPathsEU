/**************************************************************************************************
* PROJECT:         Project: Simpaths_EU   
* DO-FILE:         Labour supply EUROMOD input and output data generation
*
* PURPOSE:
*   - Prepare EUROMOD input/output data for labour supply estimation.
**************************************************************************************************/

/**************************************************************************************************
* FILE DESCRIPTION
**************************************************************************************************

This .do file prepares data for labour supply estimation and generates EUROMOD input & output data.

(1) Household composition adjustment
(2) Definition of temp_singles, temp_couples, temp_not_flexible
(3) Wage estimation using Heckman selectivity model; predicted wages assigned in two ways:
        • wage1 – to everyone
        • wage2 – only to non-workers
(4) Expansion to labour supply alternatives
(5) Benefit counterfactual allocation adjustments
(6) Run EUROMOD for disposable income
(7) Split sample for estimation: singles vs couples

==========================
DATA FILTER – "SINGLES"
==========================
Singles are individuals who:
1. Have no partner (idpartner == 0), OR have a partner who is:
      - a student, OR
      - sick/disabled, OR
      - outside working age (<16 or >75), OR
      - a pensioner.
AND who themselves satisfy:
2. Working age (16 ≤ dag ≤ 75)
3. Not student (les != 6), not disabled/sick (les != 8), not pensioner (les != 4).

==========================
DATA FILTER – "COUPLES"
==========================
Both partners satisfy the flexible worker conditions above.

==========================
DATA FILTER – "NOT FLEXIBLE"
==========================
All individuals who are neither singles nor couples according to above definitions.

---------------------------
BENEFITS COUNTERFACTUALS
---------------------------
ASSUMPTION #1:
For singles with student/disabled partners: partner’s benefits are held constant across choices.

ASSUMPTION #2(A):
Simulated benefits – EUROMOD calculates correctly.

ASSUMPTION #2(B1):
Not simulated, compatible with work, depend on YEM/LHW → set to zero.

ASSUMPTION #2(B2):
Not simulated, NOT compatible with work, do not depend on YEM/LHW → set to observed amount.

ASSUMPTION #2(B3):
Not simulated, NOT work-compatible, received in observed state → individual excluded from sample.

---------------------------
INCOME COUNTERFACTUALS
---------------------------
Workers: assume income equals major source (yem or yse).
If yem == yse: use yem.
Non-workers: assume income = employed income.

---------------------------
WAGE IMPUTATION METHODS
---------------------------
wage1 – predicted wages for everyone  
wage2 – predicted wages only for non-workers
*/

global file_log      "Input_output_data"

/**************************************************************************************************
* IMPORT DATA
**************************************************************************************************/

cd "$local_data"
pwd

capture log close
log using "$file_log", replace

clear all
set seed 1                                             // ensure replicability across runs
/*
run "${do_files}/add_original_SILC_vars.do"
*/

// capture confirm file "$em_original/$file_input.txt"     // original confirmation step (kept)
import delimited "$em_original/$file_input.txt", clear delim(tab)   // import raw SILC-based file

drop *_f                                  // important! They will mess up the ls alternatives if not dropped here

*=======================================================================
*                           CORRECT ANOMALIES
*=======================================================================

// individuals aged < 18 in couples
tab dag if dag < 18 & idpartner > 0
replace dag = 18 if dag < 18 & idpartner > 0    /* (3 real changes made) */
                                                // Ensures no minor is recorded as part of a couple
                                                // (required for microsim consistency)


*----------------------------------------------------------------------------------------------------------------
*   NUMBER OF CHILDREN IN HOUSEHOLD & DUMMIES FOR CHILDREN BY AGE GROUP
*----------------------------------------------------------------------------------------------------------------

// RMK: these flag names do not follow convention but variables are then dropped
gen byte ch    = (dag < 18)                      // child indicator, 0–17 inclusive
gen byte ch2   = (dag <= 2)                      // children aged 0–2
gen byte ch6   = (dag >= 3 & dag <= 6)           // children aged 3–6
gen byte ch12  = (dag >= 7 & dag <= 12)          // children aged 7–12
gen byte ch17  = (dag >= 13 & dag <= 17)         // children aged 13–17

sum ch*                                          // check plausibility of distribution of flags

sort idhh idperson
tempfile input                                   // create temporary storage of current dataset
save `input'


foreach childgr of varlist ch* {

    noi di "Children age group: `childgr'", _newline

    keep if `childgr' == 1                       // keep only children in this age group
    keep idhh idmother idfather dag              // keep identifiers and age for checks

    gen long temp_parent = idmother              // assign idmother as primary parent
    replace temp_parent = idfather if temp_parent==0  
                                                  // if mother missing, fallback to father
                                                  // !!! ISSUE: if both are 0 → temp_parent remains 0
                                                  //            This creates a pseudo-parent with id=0
                                                  //            Later dropped, but confirm intended behaviour.

    rename temp_parent idperson                  // parent becomes the “person” to whom child is assigned

    bysort idperson: gen int temp_n_`childgr' = _N   // count children in this age group per parent
    bysort idperson: gen int temp_d_`childgr' = (temp_n_`childgr' > 0)
                                                      // dummy: parent has ≥1 children in this group

    duplicates drop idperson, force                 // !!! FORCE deletes information without inspection  
                                                     //     Should check number dropped to avoid data loss

    drop dag idmother idfather                      // clean temporary dataset
    sort idhh idperson

    merge m:1 idhh idperson using `input'           // attach parent back to full dataset

    drop if _merge == 1                             // drop rows created artificially (idperson==0)
                                                     // but check counts in case of unintended loss
    drop _merge

    recode temp_n_`childgr' (. = 0)                 // set missing counts to zero
    recode temp_d_`childgr' (. = 0)                 // set missing dummies to zero

    save `input', replace                           // update working dataset for next iteration

}   // foreach childgr


drop ch*                                            // drop temporary raw child flags

label variable temp_d_ch    "1(children aged 0-17)"
label variable temp_d_ch2   "1(children aged 0-2)"
label variable temp_d_ch6   "1(children aged 3-6)"
label variable temp_d_ch12  "1(children aged 7-12)"
label variable temp_d_ch17  "1(children aged 13-17)"

label variable temp_n_ch    "number of children aged 0-17"
label variable temp_n_ch2   "number of children aged 0-2"
label variable temp_n_ch6   "number of children aged 3-6"
label variable temp_n_ch12  "number of children aged 7-12"
label variable temp_n_ch17  "number of children aged 13-17"

sum temp_d_ch* temp_n_ch*                          // quick sanity check of result

*----------------------------------------------------------------------------------
*     ASSIGN TO EACH PARTNER THE SUM OF HIS/HER CHILDREN & PARTNER'S CHILDREN
*     CREATE CHILDREN DUMMIES BY AGE GROUP
*----------------------------------------------------------------------------------

// Problem 1: children variables are attributed only to one parent
// Problem 2: partners might have different children variables

// Attribute the same values of children variables to the partner
foreach var of varlist temp_n_ch* temp_d_ch* {
    rename `var' partner_`var'                     // rename own child variables to partner_* to prepare for merge
}

keep idhh idpartner partner_temp_n_ch* partner_temp_d_ch*
rename idpartner idperson                         // !!! Replaces idperson with partner’s id
                                                  //     OK if idpartner=0 already dropped later
sort idhh idperson

// Merge the new dataset with the old one. Now each person has values for own kids and partner's kids
merge m:1 idhh idperson using `input'

drop if _merge == 1                                // individuals without partner (idpartner==0)
drop _merge


foreach var of varlist temp_n_ch* temp_d_ch* {

    assert `var' != .                              // ensures own child vars have no missing
                                                   // !!! may break if a parent genuinely has missing parent link

    recode partner_`var' (. = 0)                   // partners without children get a zero

    replace `var' = `var' + partner_`var'          // combine counts: own + partner's
                                                   // !!! POTENTIAL DOUBLE-COUNTING:
                                                   //     if the dataset incorrectly lists a child twice,
                                                   //     both parents might already have counted them
}

drop partner_temp_n_ch* partner_temp_d_ch*

egen test = rowtotal(temp_n_ch?*)                  // compute total children across age groups
noi di in y "Check number of children: these variables should be equal"
noi compare test temp_n_ch
assert test == temp_n_ch                           // ensures that age-specific counts sum to total
drop test

assert temp_d_ch != .                              // ensures no missing in dummies
                                                   // !!! If dataset contains no children at all,
                                                   //     this will still pass, but good to double check


*--------------------------------------------------------------------------------------------------------------------------
* Economic status
* 
*--------------------------------------------------------------------------------------------------------------------------
label var les "economic status"
label define temp_lab_les 0 " 0 - Pre-school" 1 " 1 - Farmer" 2 "2 - Employer or self-employed" 3 "3 - Employee" ///
4 "4 - Pensioner" 5 "5 - Unemployed" 6 "6 - Student" 7 "7 - Inactive" 8 "8 - Sick or disabled" 9 "9 - Other"
label values les temp_lab_les

*------------------------------------------------------------
*   Education
*------------------------------------------------------------

label define temp_lab_deh 0 "Not completed Primary" 1 "Primary" 2 "Lower Secondary" 3 "Upper Secondary" 4 "Post Secondary" 5 "Tertiary"
label values deh temp_lab_deh

gen byte temp_d_deh_L = (deh == 0 | deh == 1 | deh == 2)
label variable temp_d_deh_L "1(low education (up to lower secondary School; deh = 0-2))"

gen byte temp_d_deh_M = (deh == 3 | deh == 4)
label variable temp_d_deh_M "1(middle education (up to post secondary school; deh = 3-4))"

gen byte temp_d_deh_H = (deh == 5)
label variable temp_d_deh_H "1(high education (tertiary school; deh = 5))"

//add interactions of education with age 
gen temp_int_dehH_dag = temp_d_deh_H*dag 
gen temp_int_dehM_dag = temp_d_deh_M*dag 
gen temp_int_dehL_dag = temp_d_deh_L*dag 
lab var temp_int_dehH_dag "high education*age"
lab var temp_int_dehM_dag "medium education*age"
lab var temp_int_dehL_dag "low education*age"
	

*--------------------------------------------------------------------------------------------------------------------------
* Occupational class=A collapsed versin of ISCO = skill level 
* 
*--------------------------------------------------------------------------------------------------------------------------
//Add 
/*LABOUR MARKET : Occupation (ISCO 1-Digit)
 0 Armed forces
 1 Senior officials and managers
 2 Professionals
 3 Technicians and associate professionals
 4 Clerks
 5 Service and sales workers
 6 Skilled agricultural
 7 Craft and trades workers
 8 Plant and machine operators
 9 Elementary  occupations
 -1 Not Applicable*/
recode loc (1/2 = 4) (3=3) (4/8=2) (9=1) (0=0) (10=0) (-1=0), gen(loc2)
lab var loc2 "Occupation (skill level) - 4 categories + never worked" 
cap label define loc2  4 "level 4" 3 "level 3" 2 "level 2" 1 "level 1" 0 "never worked"
label values loc2 loc2 
fre loc2
gen temp_loc2_0 =(loc2==0)	
gen temp_loc2_1 =(loc2==1)
gen temp_loc2_2 =(loc2==2)	
gen temp_loc2_3 =(loc2==3)	
gen temp_loc2_4 =(loc2==4)
//replace temp_lnwage=. if loc2==0	
lab var temp_loc2_1 "skill level 1 (ISCO 9)"
lab var temp_loc2_2 "skill level 2 (ISCO 4-8)"
lab var temp_loc2_3 "skill level 3 (ISCO 3)"
lab var temp_loc2_4 "skill level 4 (ISCO 1-2)"


*--------------------------------------------------------------------------------------------------------------------------
* Marital status
* 
*--------------------------------------------------------------------------------------------------------------------------
//DP: dms is useful to distinguish singles and previously partnered, otherwise living with a partner should prevail over civil status  
label var dms "marital status"
label def lab_dms 1 "single" 2 "married" 3 "separated" 4 "divorced" 5 "widowed"
label val dms lab_dms
*marital status dummies
tab dms   
gen partnered=(idpartner>0)
tab2 dms partnered

//Single never married 
gen temp_single=((dms==1) & idpartner==0) //define dummy of single
//gen temp_married=(dms==2)             //define dummy of married (this is not useful when the target is singles)
//gen temp_separated=(dms==3)                //define dummy of separated
//gen temp_divorced=(dms==4)             //define dummy of divorced
//gen temp_widowed=(dms==5)                //define dummy of widowed

//labels
label variable temp_single "single"
//label variable temp_married "married"
//label variable temp_separated "separated"
//label variable temp_divorced "divorced"
//label variable temp_widowed "widowed"


//Cohabiting/married
gen temp_partnered=( idpartner>0)     //(include all those who have a partner in hh)
label variable temp_partnered "partnered (married & partner in hh)"


//Separated / Divorced / Widowed to Previously partnered 
gen temp_pre_partnered=((dms==2|dms==3|dms==4|dms==5) & idpartner==0) //define dummy of previously partnered (this is not useful when the target is singles)
label variable temp_pre_partnered "previously partnered"

tab2 temp_single temp_partnered
tab2 temp_single temp_pre_partnered
tab2 temp_partnered temp_pre_partnered

*--------------------------------------------------------------------------------------------------------------------------
* Regions
* 
*--------------------------------------------------------------------------------------------------------------------------
/*
NUTS 1 regions in EUROMOD:
gen drgn1 = 1 if db040 == "ES11" | db040 == "ES12" | db040 == "ES13" 
replace drgn1 = 2 if db040 == "ES21" | db040 == "ES22" | db040 == "ES23" | db040 == "ES24" 
replace drgn1 = 3 if db040 == "ES30"
replace drgn1 = 4 if db040 == "ES41" | db040 == "ES42" | db040 == "ES43" 
replace drgn1 = 5 if db040 == "ES51" | db040 == "ES52" | db040 == "ES53" 
replace drgn1 = 6 if db040 == "ES61" | db040 == "ES62" | db040 == "ES63" | db040 == "ES64" 
replace drgn1 = 7 if db040 == "ES70"


. fre drgn1

drgn1
-----------------------------------------------------------
              |      Freq.    Percent      Valid       Cum.
--------------+--------------------------------------------
Valid   1     |       8374      11.52      11.52      11.52
        2     |      10129      13.93      13.93      25.45
        3     |       7594      10.45      10.45      35.90
        4     |       9709      13.35      13.35      49.25
        5     |      21799      29.98      29.98      79.23
        6     |      12657      17.41      17.41      96.64
        7     |       2440       3.36       3.36     100.00
        Total |      72702     100.00     100.00           
-----------------------------------------------------------
*/

lab var drgn1 "Region"
lab define drgn1 ///
	1 "Noroeste" ///
	2 "Noreste" ///
	3 "Madrid" ///
	4 "Centro" ///
	5 "Este" ///
	6 "Sur" ///
	7 "Canarias" 
	
lab values drgn1 drgn1

tab drgn1, gen(temp_region)

label variable temp_region1	"Noroeste"
label variable temp_region2	"Noreste" 
label variable temp_region3	"Madrid"
label variable temp_region4	"Centro"
label variable temp_region5	"Este" 
label variable temp_region6	"Sur"
label variable temp_region7	"Canarias"


*--------------------------------------------------------------------------------------------------------------------------
* Health status 
* 
*-------------------------------------------------------------------------------------------------------------------------
merge 1:1 idhh idperson using "temp_dhe.dta"
lab var dhe "Health status - imputed" 
fre dhe 
drop _merge 

*impute missing values
gen dagsq = dag^2
fre dag if missing(dhe) 

*ordered probit model
recode dgn dag dagsq drgn1 (-9=.) , gen (dgn2 dag2 dagsq2 drgn12)
fre dgn2 dag2 dagsq2 drgn12
xi: oprobit dhe i.dgn2 dag2 dagsq ib3.drgn12 if dhe < ., vce(robust)
predict pred_probs1 pred_probs2 pred_probs3 pred_probs4 pred_probs5, pr

*Identify the category with the highest predicted probability
egen max_prob = rowmax(pred_probs1 pred_probs2 pred_probs3 pred_probs4 pred_probs5)
*Impute missing values of dhe based on predicted probabilities
gen imp_dhe = .
replace imp_dhe = 1 if max_prob == pred_probs1
replace imp_dhe = 2 if max_prob == pred_probs2
replace imp_dhe = 3 if max_prob == pred_probs3
replace imp_dhe = 4 if max_prob == pred_probs4
replace imp_dhe = 5 if max_prob == pred_probs5

sum imp_dhe if missing(dhe) & dag>0 & dag<16
sum imp_dhe if !missing(dhe) & dag>0 & dag<16
sum imp_dhe if missing(dhe) & dag>=16
sum imp_dhe if !missing(dhe) & dag>=16

gen dhe_flag = missing(dhe)
lab var dhe_flag "=1 if dhe is imputed"
replace dhe = round(imp_dhe) if missing(dhe)

bys dhe_flag: fre dhe if dag<=16
bys dhe_flag: fre dhe if dag>16 

drop dgn2 dag2 dagsq2 drgn12 _Idgn2_1 pred_probs* max_prob imp_dhe

//health status dummies
tab dhe, gen (temp_dhe_)

* 3 category vesrion 
gen dhe3 = .
replace dhe3 = 1 if inlist(dhe, 1, 2)
replace dhe3 = 2 if dhe == 3
replace dhe3 = 3 if inlist(dhe, 4, 5)

label define dhe3_lbl 1 "Poor/fair" 2 "Good" 3 "Very good/excellent"
label values dhe3 dhe3_lbl

//health status dummies
tab dhe3, gen (temp_dhe3_)

/***************************** ADULT CHILD FLAG *******************************/
/*
Decision 24/10/25: Agreed that to be an adult child the following conditions 
have to hold: 
    - 18+ years old
    - Not in a partnership 
    - Lives with at least one parent
    - Is at least 15 years younger than both of their parents
    - At least one parent in the hh is working age and not retired. 
*/

/* Retirement status */
gen retired = (les == 4)
fre retired

/* Statutory retirement age (66 years for both sexes in 2023) */
gen dagpns = 0
replace dagpns = 1 if dgn == 1 & dag >= 66
replace dagpns = 1 if dgn == 0 & dag >= 66
fre dagpns

/* Merge in mother/father information */
add_mother_variables "retired dagpns dag"
add_father_variables "retired dagpns dag"

/* NEW variable name */
gen temp_adultchildflag = 0

/* Adult child basic definition */
replace temp_adultchildflag = 1 if (idmother > 0 | idfather > 0) ///
    & dag >= 17 & idpartner <= 0    

/* Exclude if both parents retired or at statutory retirement age */
replace temp_adultchildflag = 0 if mother_dagpns == 1 & father_dagpns == .
replace temp_adultchildflag = 0 if mother_dagpns == . & father_dagpns == 1
replace temp_adultchildflag = 0 if mother_dagpns == 1 & father_dagpns == 1

replace temp_adultchildflag = 0 if mother_retired == 1 & father_retired == .
replace temp_adultchildflag = 0 if mother_retired == . & father_retired == 1
replace temp_adultchildflag = 0 if mother_retired == 1 & father_retired == 1

replace temp_adultchildflag = 0 if mother_retired == 1 & father_dagpns == 1
replace temp_adultchildflag = 0 if father_retired == 1 & mother_dagpns == 1

/* Exclude if both parents < 15 years older than child */
replace temp_adultchildflag = 0 if father_dag - dag <= 15 & mother_dag == .
replace temp_adultchildflag = 0 if father_dag == . & mother_dag - dag <= 15
replace temp_adultchildflag = 0 if father_dag - dag <= 15 & mother_dag - dag <= 15

* Age cap of 45
replace temp_adultchildflag = 0 if dag > ${adult_child_age_cap} 

//fre temp_adultchildflag 

*--------------------------------------------------------------------------------------------------------------------------
* work history
* 
*--------------------------------------------------------------------------------------------------------------------------
/* liwwh： LABOUR MARKET : In work : Work history (length of time in months) Number of months spent in employment*/
replace liwwh =liwwh /12 
label variable liwwh "work history (length of time in years)"


*------------------------------------------------------------
* Hours worked
*------------------------------------------------------------
label variable lhw "labour market : hours worked per week"
fre lhw 
replace lhw = $max_lhw if lhw > $max_lhw //ensure lhw doesn't go above weekly max 168 minus 42=(6*7) hours of sleep.
//(0 real changes made)
fre lhw 

histogram lhw, percent bin(20)
histogram lhw if dgn==1, percent bin(20)
histogram lhw if dgn==0, percent bin(20)

/*check categories 
gen lhw_cat = .
replace lhw_cat = 1 if lhw == 0
replace lhw_cat = 2 if lhw > 0  & lhw < 30
replace lhw_cat = 3 if lhw >= 30 & lhw <= 35
replace lhw_cat = 4 if lhw >= 36 & lhw <= 40
replace lhw_cat = 5 if lhw >= 41

label define lhw_cat_lbl ///
    1 "0 hours" ///
    2 "1-29 hours" ///
    3 "30-35 hours" ///
    4 "36-40 hours" ///
    5 "41+ hours"

label values lhw_cat lhw_cat_lbl

bys dgn: fre lhw_cat 

gen lhw_cat2 = .
replace lhw_cat2 = 1 if lhw >=0 & lhw <=5
replace lhw_cat2 = 2 if lhw >= 6  & lhw <= 25
replace lhw_cat2 = 3 if lhw >= 26 & lhw <= 35
replace lhw_cat2 = 4 if lhw >= 36 & lhw <= 40
replace lhw_cat2 = 5 if lhw >= 41

label define lhw_cat2_lbl ///
    1 "0-5 hours" ///
    2 "6-25 hours" ///
    3 "26-35 hours" ///
    4 "36-40 hours" ///
    5 "41+ hours"

label values lhw_cat2 lhw_cat2_lbl

*check the modes 
* Women
tab lhw if lhw_cat2 == 1 & dgn == 0, sort
tab lhw if lhw_cat2 == 2 & dgn == 0, sort
tab lhw if lhw_cat2 == 3 & dgn == 0, sort
tab lhw if lhw_cat2 == 4 & dgn == 0, sort
tab lhw if lhw_cat2 == 5 & dgn == 0, sort

* Men
tab lhw if lhw_cat2 == 1 & dgn == 1, sort
tab lhw if lhw_cat2 == 2 & dgn == 1, sort
tab lhw if lhw_cat2 == 3 & dgn == 1, sort
tab lhw if lhw_cat2 == 4 & dgn == 1, sort
tab lhw if lhw_cat2 == 5 & dgn == 1, sort
*/


 
*------------------------------------------------------------
* ln(hourly wage)
*------------------------------------------------------------
//v6: define discritized hours of work as median hours in the choice category 
//update in v7: define discritized hours of work as a particular no. (close to mid-point)
*Update in v6: discritize lhw before generating hourly wages, in order to reduce the "division bias"
* wages	

/*update 2/2/2021: Note: we do not know the divide of lhw between employment income and self-employed income
//gen temp_obs_wage=temp_y/(lhw*4.3)    //observed wages
replace temp_y=temp_y*12/yemmy if yem>0  //this adjustment magnifies the original total monthly income if yemmy<12 & yem>0
gen temp_obs_wage=temp_y/(lhw*4.3)    //observed wages
*/ 

*------------------------------------------------------------
* Separate employment and self-employment income
*------------------------------------------------------------
gen temp_yem = yem  // monthly employment income
gen temp_yse = yse  // monthly self-employment income

sum temp_yem if temp_yem < 0    
sum temp_yse if temp_yse < 0    
//replace temp_yse=0 if temp_yse<0 
*------------------------------------------------------------
* Adjust income to an annual-equivalent based on months worked
*------------------------------------------------------------
* note that in EUROMOD annual wages are divided by 12 so we need to multiply by 12 to get back to annual wages 
* This adjustment magnifies the income if yemmy < 12
replace temp_yem = temp_yem * 12 / yemmy if temp_yem > 0

* Same for self-employment income
replace temp_yse = temp_yse * 12 / ysemy if temp_yse > 0

* Combine adjusted income
gen temp_y = temp_yem + temp_yse

sum temp_y if temp_y < 0


************************************************
* Adressing contradictions/missing information *
************************************************
/*added on 7 Sep 2026*/

* Investigate number of cases with issues (individual level)

count if lhw == . 	// no missing obs from the beginning 
count if temp_y == . 	// no missing values 



* 1/ Negative monthly labour income 
*  ==> to drop 
gen to_drop = 0

count if temp_y < 0	//201 obs 
replace to_drop = 1 if temp_y < 0	 
 
* 2/ No income but positive hours worked 
* ==> keep these observations because we use imputed wages in the analysis 
count if temp_y<=0 & lhw >5  & !missing(lhw) //391 obs 

* 3/ No hours but positive income, not reported as employed 
* ==> set income to zero  
count if ((lhw < 6 | missing(lhw)) & temp_y > 0 & (les!=2 & les!=3)) //37 obs 
replace temp_y = 0  if ((lhw < 6 | missing(lhw)) & temp_y > 0 & (les!=2 & les!=3)) 

* No hours but positive income,  reported as employed 
count if ((lhw < 6 | missing(lhw)) & temp_y > 0 & (les==2 | les==3)) //43 obs 
//replace to_drop = 1 if ((lhw < 6 | missing(lhw)) & temp_y > 0 & (les==2 | les==3)) 

* Flag real observations requiring hours imputation
gen byte temp_imp_lhw = ((lhw <=0  | missing(lhw)) & temp_y > 0 & (les==2 | les==3))
label var temp_imp_lhw ///
	"Hours imputed: positive labour income, employed but zero hours"
count if temp_imp_lhw == 1 //0 cases unless we treat hours<6 as 0 hours so no imputation is needed 


* Drop full households of the individuals with contradictory/missing information 
bysort idhh (to_drop): replace to_drop = 1 if to_drop[_N] == 1 //(355 real changes made)
drop if to_drop == 1 //(556 observations deleted)
drop to_drop 

* Check consistency with the reported labour market status 
/*added on 13 Oct 2026*/
fre lhw if temp_y>0 //all positive 
fre lhw if temp_y==0 //some obs with positive hours but we agreed to keep them because we use imputed wages for everyone
fre temp_y if lhw==0 //no such cases 

fre les if lhw>0 

/*
les -- economic status
-------------------------------------------------------------------------------------
                                        |      Freq.    Percent      Valid       Cum.
----------------------------------------+--------------------------------------------
Valid   2 2 - Employer or self-employed |       4738      12.35      12.35      12.35
        3 3 - Employee                  |      25931      67.59      67.59      79.94
        4 4 - Pensioner                 |       1951       5.09       5.09      85.03
        5 5 - Unemployed                |       2909       7.58       7.58      92.61
        6 6 - Student                   |       1839       4.79       4.79      97.40
        7 7 - Inactive                  |        297       0.77       0.77      98.18
        8 8 - Sick or disabled          |        273       0.71       0.71      98.89
        9 9 - Other                     |        427       1.11       1.11     100.00
        Total                           |      38365     100.00     100.00           
-------------------------------------------------------------------------------------
*/

fre les if lhw==0 
/*
les -- economic status
-------------------------------------------------------------------------------------
                                        |      Freq.    Percent      Valid       Cum.
----------------------------------------+--------------------------------------------
Valid   0 0 - Pre-school                |       2923       8.65       8.65       8.65
        2 2 - Employer or self-employed |          7       0.02       0.02       8.67
        3 3 - Employee                  |          2       0.01       0.01       8.68
        4 4 - Pensioner                 |      10090      29.87      29.87      38.55
        5 5 - Unemployed                |       2539       7.52       7.52      46.06
        6 6 - Student                   |      11767      34.83      34.83      80.90
        7 7 - Inactive                  |        615       1.82       1.82      82.72
        8 8 - Sick or disabled          |       1523       4.51       4.51      87.23
        9 9 - Other                     |       4315      12.77      12.77     100.00
        Total                           |      33781     100.00     100.00           
-------------------------------------------------------------------------------------
*/

* 4/ Make sure that only those with les==2 or 3 have positive hours and earnings
count if (lhw>0 | temp_y > 0) & (les != 2 & les != 3) //7,696 ==> set hours and earnings to zero for those not reported as employed
replace lhw = 0 if les != 2 & les != 3
replace temp_y = 0 if les != 2 & les != 3

* 5/ drop those with les==2 or 3 but zero working hours  
// Flag individuals with employment status but zero hours
gen byte to_drop = (les==2 | les==3) & lhw==0  
count if to_drop==1 //9 obs 

// Flag entire households
bysort idhh: egen byte hh_drop = max(to_drop)
// Count observations and households to be dropped
count if hh_drop==1 //25 obs 
egen byte tag_hh = tag(idhh) if hh_drop==1
count if tag_hh==1 
// Drop entire households
drop if hh_drop==1 
drop to_drop hh_drop tag_hh


// Check that only employed/self-employed have positive income and hours 
assert (les==2 | les==3 ) if lhw>0 
assert (les==2 | les==3 ) if temp_y>0 

*-----------------------------------------------------------------------------------------------
* part-time hours (as defined in panel SILC) 
*----------------------------------------------------------------------------------------------- 

gen temp_pt = (lhw> 0 & lhw<.) * (lhw<=25)
lab var temp_pt "part-time employed (<=25 hours per week)"

*full-time or more hours  
gen temp_ft = (lhw>0 & lhw<.) * (lhw>25)
lab var temp_ft "full-time employed (>25 hours per week)"
 

*-----------------------------------------------------------------------------------------------
* lhw discretisation 
*-----------------------------------------------------------------------------------------------

/*4 alternatives 

* chosen hrs bracket

* female hrs bracket
gen byte temp_bracket_0 = 0
replace temp_bracket_0 = 1 if lhw >= $min_hours_1_0 & dgn==0
replace temp_bracket_0 = 2 if lhw >= $min_hours_2_0 & dgn==0
replace temp_bracket_0 = 3 if lhw >= $min_hours_3_0 & dgn==0

* male hrs bracket
gen byte temp_bracket_1 = 0
replace temp_bracket_1 = 1 if lhw >= $min_hours_1_1 & dgn==1
replace temp_bracket_1 = 2 if lhw >= $min_hours_2_1 & dgn==1
replace temp_bracket_1 = 3 if lhw >= $min_hours_3_1 & dgn==1

* female discretised hrs 
gen temp_lhw_dobs_0 = 0
replace temp_lhw_dobs_0 = $hours_1_0 if temp_bracket_0 == 1
replace temp_lhw_dobs_0 = $hours_2_0 if temp_bracket_0 == 2
replace temp_lhw_dobs_0 = $hours_3_0 if temp_bracket_0 == 3

* male discretised hrs 
gen temp_lhw_dobs_1 = 0
replace temp_lhw_dobs_1 = $hours_1_1 if temp_bracket_1 == 1
replace temp_lhw_dobs_1 = $hours_2_1 if temp_bracket_1 == 2
replace temp_lhw_dobs_1 = $hours_3_1 if temp_bracket_1 == 3

* check
fre lhw temp_lhw_dobs_0 if dgn==0
fre lhw temp_lhw_dobs_1 if dgn==1


*5 alternatives 

* chosen hrs bracket
*female hrs bracket
gen byte temp_bracket_0 = 0
replace temp_bracket_0 = 1 if lhw >= $min_hours_1_0 & dgn==0
replace temp_bracket_0 = 2 if lhw >= $min_hours_2_0 & dgn==0
replace temp_bracket_0 = 3 if lhw >= $min_hours_3_0 & dgn==0
replace temp_bracket_0 = 4 if lhw >= $min_hours_4_0 & dgn==0

*male hrs bracket
gen byte temp_bracket_1 = 0
replace temp_bracket_1 = 1 if lhw >= $min_hours_1_1 & dgn==1
replace temp_bracket_1 = 2 if lhw >= $min_hours_2_1 & dgn==1
replace temp_bracket_1 = 3 if lhw >= $min_hours_3_1 & dgn==1
replace temp_bracket_1 = 4 if lhw >= $min_hours_4_1 & dgn==1

* female discretised hrs 
gen temp_lhw_dobs_0 = 0
replace temp_lhw_dobs_0 = $hours_1_0 if temp_bracket_0 == 1
replace temp_lhw_dobs_0 = $hours_2_0 if temp_bracket_0 == 2
replace temp_lhw_dobs_0 = $hours_3_0 if temp_bracket_0 == 3
replace temp_lhw_dobs_0 = $hours_4_0 if temp_bracket_0 == 4

* male discretised hrs 
gen temp_lhw_dobs_1 = 0
replace temp_lhw_dobs_1 = $hours_1_1 if temp_bracket_1 == 1
replace temp_lhw_dobs_1 = $hours_2_1 if temp_bracket_1 == 2
replace temp_lhw_dobs_1 = $hours_3_1 if temp_bracket_1 == 3
replace temp_lhw_dobs_1 = $hours_4_1 if temp_bracket_1 == 4

*check 
fre lhw temp_lhw_dobs_0 if dgn==0
fre lhw temp_lhw_dobs_1 if dgn==1
*/

* 6 alternatives

* Chosen hours bracket

* Female hours bracket
gen byte temp_bracket_0 = 0
replace temp_bracket_0 = 1 if lhw >= $min_hours_1_0 & dgn == 0
replace temp_bracket_0 = 2 if lhw >= $min_hours_2_0 & dgn == 0
replace temp_bracket_0 = 3 if lhw >= $min_hours_3_0 & dgn == 0
replace temp_bracket_0 = 4 if lhw >= $min_hours_4_0 & dgn == 0
replace temp_bracket_0 = 5 if lhw >= $min_hours_5_0 & dgn == 0

* Male hours bracket
gen byte temp_bracket_1 = 0
replace temp_bracket_1 = 1 if lhw >= $min_hours_1_1 & dgn == 1
replace temp_bracket_1 = 2 if lhw >= $min_hours_2_1 & dgn == 1
replace temp_bracket_1 = 3 if lhw >= $min_hours_3_1 & dgn == 1
replace temp_bracket_1 = 4 if lhw >= $min_hours_4_1 & dgn == 1
replace temp_bracket_1 = 5 if lhw >= $min_hours_5_1 & dgn == 1

* Female discretised hours
gen temp_lhw_dobs_0 = 0
replace temp_lhw_dobs_0 = $hours_1_0 if temp_bracket_0 == 1
replace temp_lhw_dobs_0 = $hours_2_0 if temp_bracket_0 == 2
replace temp_lhw_dobs_0 = $hours_3_0 if temp_bracket_0 == 3
replace temp_lhw_dobs_0 = $hours_4_0 if temp_bracket_0 == 4
replace temp_lhw_dobs_0 = $hours_5_0 if temp_bracket_0 == 5

* Male discretised hours
gen temp_lhw_dobs_1 = 0
replace temp_lhw_dobs_1 = $hours_1_1 if temp_bracket_1 == 1
replace temp_lhw_dobs_1 = $hours_2_1 if temp_bracket_1 == 2
replace temp_lhw_dobs_1 = $hours_3_1 if temp_bracket_1 == 3
replace temp_lhw_dobs_1 = $hours_4_1 if temp_bracket_1 == 4
replace temp_lhw_dobs_1 = $hours_5_1 if temp_bracket_1 == 5


 
*-----------------------------------------------------------------------------------------------
* Calculate observed hourly wage 
*----------------------------------------------------------------------------------------------- 

gen temp_obs_wage=temp_y/(lhw*4.3)   

drop temp_yem temp_yse

*------------------------------------------------------------
* remove outliers of wages (1% and 99% percentiles)
*------------------------------------------------------------	
count if temp_obs_wage==0 &lhw>0 //207 obs , we keep them as we'll be using imputed wage for everyone 

duplicates report idperson  //count how many unique individuals there are
su temp_obs_wage if lhw>0 

/*Trim wages 
su temp_obs_wage if lhw>0, detail 
gen keepwage=(inrange(temp_obs_wage, r(p1), r(p99)))   //dummy of temp_obs_wage within 1st-99th percentiles
keep if keepwage==1 |lhw==0   //keep workers with wage within 1st-99th percentiles and non-workers
drop keepwage

* Winsorise observed wages at the 1st and 99th percentiles
centile temp_obs_wage if lhw>0,  centile(1 2 3 4 5 95 96 97 98 99)  
return list
replace temp_obs_wage = `r(c_1)' if temp_obs_wage <= `r(c_1)' & lhw>0
replace temp_obs_wage = `r(c_10)' if temp_obs_wage >= `r(c_10)' & temp_obs_wage != . & lhw>0
 
su temp_obs_wage if lhw>0 
/*winsorised 375 observations at each tail, rather than dropping them.*/
*/

/*
In 2023, the average gross monthly wage in Spain was approximately 2,273.00 EUR. 
Given that full-time employees typically work around 160 hours per month, 
this translates to an average gross hourly wage of about 14.21 EUR. 
The minimum gross monthly wage in 2023 was 1,080 EUR (paid over 14 payments), 
equating to approximately 7.88 EUR per hour when expressed on a 12-month-equivalent basis. */

//Now restore temp_y using trimmed version of hourly wage 
replace temp_y = temp_obs_wage * lhw * 4.3
sum temp_y if temp_y>0

/*
.	sum temp_y	if	temp_y>0

	Variable		Obs	Mean	Std. Dev.	Min	Max
							
	temp_y		30,458	2638.549	2359.354	.1725	78662.4

*/

//female ln(wage)
gen temp_lnwage=log(temp_y/(temp_lhw_dobs_0*4.3))	if temp_y>0	&dgn==0	//logarithm of hourly wage (yem: monthly employment income; temp_lhw_dobs: discritized Hours worked per week) 4.3=365/(7*12) 
//male ln(wage)
replace temp_lnwage=log(temp_y/(temp_lhw_dobs_1*4.3))	if temp_y>0	&dgn==1	//logarithm of hourly wage (yem: monthly employment income; temp_lhw_dobs: discritized Hours worked per week) 4.3=365/(7*12) 
label variable temp_lnwage "log(hourly wage)"
sum temp_obs_wage

/*
. sum temp_obs_wage

Variable         Obs	Mean	Std. Dev.	Min	Max
				
temp_obs_w~e      30,665	15.81495	13.57746	0	316.1331

*/

sum temp_lnwage

//CHECK
assert lhw>0 if temp_y<.
su lhw if lhw<=0 &temp_y>0 //no obs 

*------------------------------------------------------------*
* Statutory minimum wage floor
* 2024 SILC cross-sectional data refer to income year 2023
* SMI is expressed as monthly wage paid over 14 payments
*------------------------------------------------------------*

capture drop smi_monthly
gen smi_monthly = .
replace smi_monthly = 1080.00 
label variable smi_monthly ///
    "Spanish statutory minimum monthly wage"

*  Convert SMI to hourly minimum wage
*
* SMI is paid over 14 payments.
* Assuming a 40-hour working week:
*
* annual minimum wage = monthly SMI * 14
* annual working hours = 52 * 40

capture drop mw_hour
gen mw_hour = smi_monthly * 14 / (52 * 40)
label variable mw_hour ///
    "Statutory minimum hourly wage"

*Checks
sum smi_monthly 
sum mw_hour
/*
. sum smi_monthly 

    Variable |        Obs        Mean    Std. Dev.       Min        Max
-------------+---------------------------------------------------------
 smi_monthly |     71,936        1080           0       1080       1080

. sum mw_hour

    Variable |        Obs        Mean    Std. Dev.       Min        Max
-------------+---------------------------------------------------------
     mw_hour |     71,936    7.269231           0   7.269231   7.269231
*/

*------------------------------------------------------------
* participation (binary: work and not work)
*------------------------------------------------------------	

gen temp_work=1 if temp_y<. //worker, either employed or self-employed
replace temp_work=0 if temp_y==.   //non-worder
fre temp_work 

*------------------------------------------------------------
* age squared
*------------------------------------------------------------
label variable dag "age"
	
gen temp_age2=dag^2 
label variable temp_age2 "age^2"

*------------------------------------------------------------
* household size
*------------------------------------------------------------
gen sizecount=1
bysort idhh:egen temp_hhsize=total(sizecount)
label variable temp_hhsize "household size"
drop sizecount



*=======================================================================
*           Target samples classification
*           
*=======================================================================
*keep working age people only (aged 16-75)
gen temp_workage=(dag>=${age_seek_employment} & dag <=${age_force_retire})   		//dummy of working age (aged 16 to 75)
count if temp_workage==1

//@@@ DATA FILTER -"singles" @@@
add_partner_variables "les temp_workage dag" 
sum partner_*

gen temp_p_student=(partner_les==6) //dummy of having a student partner
label variable temp_p_student "1(with a student partner)"

gen temp_p_sick_dis=(partner_les==8) //dummy of having a sick or disabled partner
label variable temp_p_sick_dis "1(with a sick or disabled partner)"

gen temp_p_pensioner=(partner_les==4) //dummy of having partner being a pensioner (updated 3 July 2020)
label variable temp_p_sick_dis "1(with a pensioner partner)"

gen temp_p_workage=(partner_temp_workage==1) //dummy of having a partner with working age (aged 16-75)

gen temp_p_elderly=(partner_dag>=70) //dummy of having a partner aged 70 or above
label variable temp_p_elderly "1(with partner aged 70+)"

drop partner_les partner_temp_workage partner_dag

*--------------------------------------------------------------------------------------------------------------------------
* Inclusion in the "singles" sample: single member in the household, working age, not student (les!=6),  not sick or disabled (les!=8), not pensioner (les!=4)
* Note: temp_singles includes two mutually exclulsive groups: temp_singles_indep and temp_singles_dep
*--------------------------------------------------------------------------------------------------------------------------
//(updated 3 July 2020):les!=4 (not pensioner)
//update 16/2/2021 (idpartner>0&(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0|temp_p_pensioner==1))
gen byte temp_singles = ((idpartner==0|(idpartner>0&(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0|temp_p_pensioner==1))) & temp_workage == 1  & les != 6 & les != 8 & les != 4)  //dummy of target sample
//gen byte temp_singles = ((idpartner==0|temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0|temp_p_pensioner==1) & temp_workage == 1  & les != 6 & les != 8 & les != 4)  //dummy of target sample

label variable temp_singles "flag: Heckman sample (singles, working age, not student, not sick or disabled, not pensioner )"

tab les temp_singles
qui count if temp_singles==1
noi di in y "Target sample singles: number of observations, i.e  singles at working age, not student (les!=6), not sick or disabled (les!=8), not pensioner (les!=4): " r(N)  //Notice they can be of any marital status

*Note that here the definition of "singles" is either those with no partners (not the same as marital status), or with a student partner or sick or disabled partner or out-of-working-age partner
tab les if temp_singles==1

*--------------------------------------------------------------------------------------------------------------------------
* Inclusion in the "singles_indep" sample: single member in the household, working age, not student (les!=6),  not sick or disabled (les!=8), not pensioner (les!=4)
* 
*--------------------------------------------------------------------------------------------------------------------------
gen temp_singles_indep=(idpartner==0 & temp_workage == 1  & les != 6 & les != 8 & les != 4)
label variable temp_singles "flag: Heckman sample (singles, working age, not student, not sick or disabled, not pensioner )"
duplicates report idperson  //count how many unique individuals there are


*--------------------------------------------------------------------------------------------------------------------------
* Inclusion in the "singles_dep" sample: within work age, not student (les!=6),  not sick or disabled (les!=8), not pensioner (les!=4),
*                                      with a partner who is student, sick or disabled, or out of working age 
* 
*--------------------------------------------------------------------------------------------------------------------------
//gen temp_singles_dep=(idpartner>0&(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0) & temp_workage == 1  & les != 6 & les != 8 & les != 4)
gen temp_singles_dep=(idpartner>0&(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0|temp_p_pensioner==1) & temp_workage == 1  & les != 6 & les != 8 & les != 4)  //update 16/2/2021
label variable temp_singles "flag: Heckman sample (with non-flexible partner, working age, not student, not sick or disabled, not pensioner )"
tab les if temp_singles_dep==1
//double check temp_singles includes two mutually exclulsive groups: temp_singles_indep and temp_singles_dep
assert temp_singles==temp_singles_indep+temp_singles_dep


//@@@ DATA FILTER -"couples" @@@
*--------------------------------------------------------------------------------------------------------------------------
* Inclusion in the sample: individuals in couples with both partners at working age, not student (les!=6),  not sick or disabled (les!=8)
* (Both partners are flexible in labour supply)
*--------------------------------------------------------------------------------------------------------------------------
//(updated 3 July 2020):les!=4 (not pensioner)
gen byte temp_couples = (idpartner>0 & temp_p_student==0 & temp_p_sick_dis==0 & temp_p_workage==1 &temp_p_pensioner==0 & temp_workage == 1  & les != 6 & les != 8& les != 4)  //dummy of target sample for "couples"
label variable temp_couples "flag: Heckman sample (couples, working age, not student, sick or disabled, not pensioner)"
tab les temp_couples
qui count if temp_couples==1
noi di in y "Target sample couples: number of observations, i.e  couples at working age, not student (les!=6), not sick or disabled (les!=8), not pensioner (les!=4): " r(N)  //Notice they can be of any marital status
tab les if temp_couples==1
tab dms	if temp_couples==1


//@@@ DATA FILTER -"not_flexible" @@@
gen temp_not_flexible=(temp_singles==0 &temp_couples==0)

tab lhw if temp_not_flexible==1
assert temp_singles+temp_couples+temp_not_flexible==1  //check the 3 categories are exclusive
su temp_singles_indep temp_singles_dep temp_couples temp_not_flexible
duplicates report idperson  //count how many unique individuals there are


//check hours of work 
fre temp_lhw_dobs_0 if dgn==0 & temp_couples ==1 //16.30 % with zero hours 
fre temp_lhw_dobs_1 if dgn==1 & temp_couples ==1 // 4.20 % with zero hours

fre temp_lhw_dobs_0 if dgn==0 & temp_singles_indep==1 //17.72 % with zero hours 
fre temp_lhw_dobs_1 if dgn==1 & temp_singles_indep==1 //10.63 % with zero hours

fre temp_lhw_dobs_0 if dgn==0 & temp_singles_dep==1 //54.13 % with zero hours 
fre temp_lhw_dobs_1 if dgn==1 & temp_singles_dep==1 // 10.04 % with zero hours
/*In 2024, Spain's economic inactivity rates among individuals aged 15 to 64 were as follows:
Women: 29%
Men: 21%
*/

/*
bys dgn: fre lhw_cat if temp_couples ==1
bys dgn: fre lhw_cat if temp_singles_indep ==1
bys dgn: fre lhw_cat if temp_singles_dep ==1

bys dgn: fre lhw_cat2 if temp_couples ==1
bys dgn: fre lhw_cat2 if temp_singles_indep ==1
bys dgn: fre lhw_cat2 if temp_singles_dep ==1
*/

save beforeheckman,replace

*------------------------------------------------------------
* Heckman wage equations for male and female, respectively
*------------------------------------------------------------	
use beforeheckman,clear
duplicates report idperson  //count how many unique individuals there are

cap gen temp_y2020=0
cap gen temp_y2021=0

display "$income_year"
gen temp_real_wage_growth_lag = .
replace temp_real_wage_growth_lag = 103.41975 if $income_year == 2010
replace temp_real_wage_growth_lag = 100.03401 if $income_year == 2011
replace temp_real_wage_growth_lag = 98.191032 if $income_year == 2012
replace temp_real_wage_growth_lag = 97.354123 if $income_year == 2013
replace temp_real_wage_growth_lag = 98.729356 if $income_year == 2014
replace temp_real_wage_growth_lag = 100       if $income_year == 2015
replace temp_real_wage_growth_lag = 100.77507 if $income_year == 2016
replace temp_real_wage_growth_lag = 100.03907 if $income_year == 2017
replace temp_real_wage_growth_lag = 100.62643 if $income_year == 2018
replace temp_real_wage_growth_lag = 103.69088 if $income_year == 2019
replace temp_real_wage_growth_lag = 104.35226 if $income_year == 2020
replace temp_real_wage_growth_lag = 104.43179 if $income_year == 2021
replace temp_real_wage_growth_lag = 101.16196 if $income_year == 2022
replace temp_real_wage_growth_lag = 101.80503 if $income_year == 2023
sum temp_real_wage_growth_lag


//////////////////////////////////////////// 
/*Run wage regression for the whole sample*/
////////////////////////////////////////////
* 0=female 
* 1=male 

	
foreach gender in 0 1{ //beginning of gender loop 
//local gender=1 //for debugging
capture drop temp_lnw_`gender' 
capture drop temp_heckman_`gender'
capture drop temp_u_`gender'
capture drop temp_wage_`gender'

*****************************************************************************************************************************************************
	local covariates "dag temp_age2 temp_d_deh_M temp_d_deh_L temp_int_dehM_dag temp_int_dehL_dag temp_pt  liwwh temp_region2 temp_region3 temp_region4 temp_region5 temp_region6 temp_region7  temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5" 
	local selection  "dag temp_age2 temp_d_deh_M temp_d_deh_L temp_int_dehM_dag temp_int_dehL_dag  liwwh temp_partnered temp_d_ch temp_region2 temp_region3 temp_region4 temp_region5 temp_region6 temp_region7 temp_dhe_2 temp_dhe_3 temp_dhe_4 temp_dhe_5" 
	
heckman temp_lnwage `covariates' if dgn==`gender' & temp_not_flexible==0,	///
select(`selection')  twostep
*******************************************************************************************************************************************************

****************
*output tables *
****************
version 13																

matrix results = r(table)
matrix results = results[1..6,1...]'   //extract the first six rows of results, and then transpose results
if (`gender' == 0){
putexcel set "$results_wi/all/wage", sheet("female wage") replace
}
else{
putexcel set "$results_wi/all/wage", sheet("male wage") modify
}
*putexcel set gender`gender'_wages, replace
putexcel A3 = matrix(results, names) //names nformat(number_d2)  //write estimates in Excel from cell A3 (Stata 13)
//putexcel A3 = matrix(results), names nformat(number_d2)  //write in Excel from cell A3 (Stata 15)
putexcel A45=("sigma")
putexcel B45=(e(sigma))

putexcel A46=("rho")
putexcel B46=(e(rho))

//predicted log wage
predict temp_lnw_`gender', ycon                //predict logwage (ycon option: expected value of the dependent variable conditional on the dependent variable being observed)
gen temp_heckman_`gender'=( e(sample)==1)
			                    
sum temp_lnwage temp_lnw_`gender' if e(sample) & temp_lnwage != . // RMK: average predicted on observed only 
sum temp_lnwage temp_lnw_`gender' if e(sample) // RMK: average predicted on all 
			                    
sum temp_lnwage temp_lnw_`gender' if e(sample) & temp_lnwage != . // RMK: average predicted on observed only 
sum temp_lnwage temp_lnw_`gender' if e(sample) // RMK: average predicted on all 

//R^2
predict temp_lnw2_`gender' if e(sample), ycon
corr temp_lnwage temp_lnw2_`gender' if e(sample)
putexcel A48=("R^2")  
putexcel B48=(r(rho)^2)  //R^2 of wage eqn
gen temp_R2_lnwage_`gender'=r(rho)^2  //store this variable for writing to tex later
 
//RMSE of wage eqn
gen double temp_u_`gender' = temp_lnwage - temp_lnw_`gender' if e(sample)
sum temp_u_`gender'

putexcel A47=("RMSE of wage eqn")  
putexcel B47=(r(sd))  //sd of the residuals of wage eqn

global heckmanwage "`covariates'"
global heckmanselection "`covariates' temp_single temp_pre_partnered  temp_n_ch temp_d_ch2"

macro list heckmanwage
//display labels for covariates of wage eqn & label for the dependent variable temp_lnwage (log(hourly wage))
global n_wagevars: word count $heckmanwage   //count the number of vars in list $heckmanwage

local row = 4
foreach x of varlist $heckmanwage{
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")
describe temp_lnwage
local ylabel: var label temp_lnwage
putexcel A`row' = ("`ylabel'")
local row = `row'+1
}
//for _cons
describe temp_lnwage
local ylabel: var label temp_lnwage
local n_wagevars=4+$n_wagevars
putexcel A`n_wagevars'= ("`ylabel'")


//display labels for covariates of selection eqn
macro list heckmanselection
local row = 4+$n_wagevars+1  //"+1" because need to leave a cell for _cons for the wage eqn
foreach x of varlist $heckmanselection {
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")

local row = `row'+1
}

//put in variance-covariance matrix of heckman
matrix results=e(V)
if (`gender' == 0){
putexcel set "$results_wi/all/wage_eV", sheet("female wage e(V)") replace
}
else{
putexcel set "$results_wi/all/wage_eV", sheet("male wage e(V)") modify
}
putexcel A3 = matrix(results, names) //names nformat(number_d2)  //write e(V) in Excel from cell A3 (Stata 13)

//display labels for e(V) matrix 
//Labels on the Excel rows (for e(V))
//-labels of covariates for wage eqn
local row = 5
foreach x of varlist $heckmanwage {
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")
local ylabel: var label temp_lnwage
putexcel A`row' = ("`ylabel'")
local row = `row'+1
}
//-(put the label of "temp_lnwage" for _cons in wage eqn)
local ylabel: var label temp_lnwage
local row=5+$n_wagevars
putexcel A`row'= ("`ylabel'")

//-labels of covariates for selection eqn
local row = 5+$n_wagevars+1  //"+1" because need to leave a cell for _cons for the wage eqn
foreach x of varlist $heckmanselection {
describe `x'
local varlabel : var label `x'
putexcel B`row' = ("`varlabel'")
local row = `row'+1
}

//Labels on the Excel columns (for e(V))
//-labels of covariates for wage eqn

local col=3
foreach x of varlist $heckmanwage {
describe `x'
local varlabel : var label `x'
excelcol `col'   //Convert a column index into a name of an Excel column (e.g. 3->C)
local colname `r(column)'    //`colname'is now the name of Excel column
putexcel B`row' = ("`varlabel'")
local ylabel: var label temp_lnwage
putexcel `colname'3 = ("`ylabel'")
putexcel `colname'4 = ("`varlabel'")
local col = `col'+1
}
//-(put the label of "temp_lnwage" for _cons in wage eqn)
local ylabel: var label temp_lnwage
local col=3+$n_wagevars
excelcol `col'   //Convert a column index into a name of an Excel column (e.g. 3->C)
local colname `r(column)'    //`colname'is now the name of Excel column
putexcel `colname'3= ("`ylabel'")
//-labels of covariates for selection eqn

local col=3+$n_wagevars+1  //"+1" because need to leave a cell for _cons for the wage eqn
foreach x of varlist $heckmanselection {
describe `x'
local varlabel : var label `x'
excelcol `col'   //Convert a column index into a name of an Excel column (e.g. 3->C)
local colname `r(column)'    //`colname'is now the name of Excel column
putexcel `colname'4 = ("`varlabel'")
local col = `col'+1
}
//for e(v) matrix row, put "_cons" as the last covariate for selection eqn (strangely, without this, the last covariate label will be the last covariate of the wage eqn, in this case "Northern Ireland". this does not happen in column labels)
//Also strangely, the following commands do not work if I put them before displaying labels for e(V) columns
if (`gender' == 0){
putexcel set "$results_wi/all/wage_eV", sheet("female wage e(V)") modify
}
else{
putexcel set "$results_wi/all/wage_eV", sheet("male wage e(V)") modify
}
global n_selectionvars: word count $heckmanselection   //count the number of vars in list $heckmanselection
local n_selectionvars=5+$n_wagevars+1+$n_selectionvars
putexcel B`n_selectionvars'= ("_cons")
estimates save "$results_wi/all/heckman_`gender'",replace  //to save .ster files
eststo heckman_`gender'
estadd scalar R2=temp_R2_lnwage_`gender'
//esttab heckman_`gender' using s_heckman_`gender'.csv, replace  label cells(b(fmt(20)) t(par fmt(2))) plain   //for simulation (plain, including all digits)
esttab heckman_`gender' using "$results_wi/all/heckman_`gender'.csv", replace label cells(b(star fmt(3)) t(par fmt(2))) stats(R2 N) //for writing csv (including at least three non-zero digits)
if (`gender' == 0){
esttab heckman_`gender' using "$results_wi/all/heckman_women.tex", replace label cells(b(star fmt(3)) t(par fmt(2))) stats(R2 N) ///
title(Determinants of hourly wages, women aged 16-75. Source: Our elaboration on EUROMOD 2019 input data for Poland (EU-SILC)\label{tab:wage-F}) //for writing tex(including at least three non-zero digits)
}
else{
esttab heckman_`gender' using "$results_wi/all/heckman_men.tex", replace label cells(b(star fmt(3)) t(par fmt(2))) stats(R2 N) ///
title(Determinants of hourly wages, men aged 16-75. Source: Our elaboration on EUROMOD 2019 input data for Poland (EU-SILC)\label{tab:wage-M}) //for writing tex(including at least three non-zero digits)
}

//capture drop R2
*anti-log transformation
//	gen double temp_u_`gender' = temp_lnwage - temp_lnw_`gender' if e(sample)  //this line was moved forward when entering Excel of RMSE
sum temp_u_`gender'

gen temp_wage_`gender' = exp(temp_lnw_`gender' + rnormal(0,r(sd)))  // to avoid retransformation bias


} //end of gender loop


esttab  heckman_1 heckman_0 using "$results_wi/all/heckman_10.tex", replace label cells(b(star fmt(3))) stats(R2 N) nonumbers mtitles("Men" "Women") ///
collabels(none) ///
title(Determinants of hourly wages, men and women aged 16-75. Source: Our elaboration on EUROMOD 2019 input data for Poland ///
\label{tab:wage-MF}) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing tex including female and male(including at least three non-zero digits)

esttab  heckman_1 heckman_0 using "$results_wi/all/heckman_10.csv", replace label cells(b(star fmt(3))) stats(R2 N) nonumbers mtitles("Men" "Women") ///
title(Determinants of hourly wages, men and women aged 16-75. Source: Our elaboration on EUROMOD 2019 input data for Poland ///
\label{tab:wage-MF}) ///
collabels(none) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing csv including female and male(including at least three non-zero digits)

gen temp_heckman=temp_heckman_0  //dummy of being included in the Heckman sample for female
replace temp_heckman=temp_heckman_1 if dgn==1  //dummy of being included in the Heckman sample for male

*=======================================================================
*           wage imputations
*=======================================================================

*------------------------------------------------------------
* // @@@ WAGE IMPUTATION METHOD #wage1 @@@
* make predicted wage=yivwg for everyone
*------------------------------------------------------------	

replace yivwg=temp_wage_0 if dgn==0   	     //For female, make predicted wage=yivwg (yivwg: name for predicted hourly wage in Euromod)
replace yivwg=temp_wage_1 if dgn==1   	     //For male, make predicted wage=yivwg (yivwg: name for predicted hourly wage in Euromod)

recode yivwg (.=-1)												//not-wages as -1

su temp_obs_wage yivwg if temp_work==1 & temp_heckman==1& yivwg!=-1
bysort dgn:su temp_obs_wage yivwg if temp_work==1 & temp_heckman==1 & yivwg!=-1

bysort dgn:su temp_obs_wage yivwg if temp_work==1 & temp_heckman==1 & yivwg!=-1 & temp_obs_wage<14 



*********************************************
* Graph of predicted wage vs. observed wage *
*********************************************
**************
*scatterplot *
**************
foreach gender in 0 1 { //beginning of gender loop 
    twoway ///
        (scatter yivwg temp_obs_wage ///
            if dgn==`gender' & yivwg!=. ///
            & temp_obs_wage!=.) ///
        (line temp_obs_wage temp_obs_wage ///
            if dgn==`gender' & yivwg!=. ///
            & temp_obs_wage!=.), ///
        title("Gross Hourly Wage") ///
        xtitle("Observed wage, Euros") ///
        ytitle("EUROMOD-predicted wage, Euros")

    graph export ///
        "$results_wi/all/wages_scatter_`gender'.png", ///
        as(png) replace
	
************
* histogram *
************

if (`gender' == 0) {
    twoway ///
    (histogram temp_obs_wage if dgn==`gender' & temp_heckman_`gender'==1 ///
        & temp_obs_wage != . & temp_obs_wage > 0 & temp_obs_wage < 60, ///
        width(0.5) lcolor(gs12) fcolor(gs12)) ///
    (histogram yivwg if dgn==`gender' & temp_heckman_`gender'==1 ///
        & yivwg != . & yivwg > 0 & yivwg < 60, ///
        width(0.5) fcolor(none) lcolor(red)) ///
    , legend(order(1 "EUROMOD input data" 2 "Prediction")) ///
      title("Gross Hourly Wage (Level)") ///
      subtitle("Women") ///
      xtitle("Euros") ///
      xlabel(0(5)60) ///
      xscale(range(0 60))
}
else {
    twoway ///
    (histogram temp_obs_wage if dgn==`gender' & temp_heckman_`gender'==1 ///
        & temp_obs_wage != . & temp_obs_wage > 0 & temp_obs_wage < 60, ///
        width(0.5) lcolor(gs12) fcolor(gs12)) ///
    (histogram yivwg if dgn==`gender' & temp_heckman_`gender'==1 ///
        & yivwg != . & yivwg > 0 & yivwg < 60, ///
        width(0.5) fcolor(none) lcolor(red)) ///
    , legend(order(1 "EUROMOD input data" 2 "Prediction")) ///
      title("Gross Hourly Wage (Level)") ///
      subtitle("Men") ///
      xtitle("Euros") ///
      xlabel(0(5)60) ///
      xscale(range(0 60))
}

graph export "$results_wi/all/obs_wage_`gender'.png", as(png) replace

} // end of gender loop



*====================================================================*
* PANEL EU-SILC WAGE IMPUTATION IN EUROMOD
*====================================================================*
/*
The original EUROMOD wage estimation and imputation is completed above.

The following block uses the coefficients estimated from the Panel
EU-SILC Heckman models to predict log hourly wages in EUROMOD.

Female: temp_silc_lnw_0
Male:   temp_silc_lnw_1

Wage imputation
EU-SILC Heckman estimation: The Mills ratio corrects the wage coefficients for the fact that wages are only observed for people who work.
After estimation: The wage coefficients are already adjusted for this selection.
Wage imputation in EUROMOD: I want to estimate a person's potential wage if they worked, including people who are currently inactive or unemployed.

Therefore, I do not add the Mills ratio to the imputed wage. It would make the prediction conditional on being selected into employment, which is not the objective.
*/
*====================================================================*
* FEMALES
*====================================================================*

preserve

use "${path}/regression estimates/temp_heckman_female.dta", clear

* Keep wage equation only
keep if equation == "wage"

* Put coefficients into locals
quietly summarize coefficient if term == "dag"
local b_dag = r(mean)

quietly summarize coefficient if term == "dagsq"
local b_dagsq = r(mean)

quietly summarize coefficient if term == "2.deh_c4"
local b_dehM = r(mean)

quietly summarize coefficient if term == "3.deh_c4"
local b_dehL = r(mean)

quietly summarize coefficient if term == "2.deh_c4#c.dag"
local b_dehM_dag = r(mean)

quietly summarize coefficient if term == "3.deh_c4#c.dag"
local b_dehL_dag = r(mean)

quietly summarize coefficient if term == "1.pt"
local b_pt = r(mean)

quietly summarize coefficient if term == "liwwh"
local b_liwwh = r(mean)

quietly summarize coefficient if term == "2.drgn1"
local b_region2 = r(mean)

quietly summarize coefficient if term == "3.drgn1"
local b_region3 = r(mean)

quietly summarize coefficient if term == "4.drgn1"
local b_region4 = r(mean)

quietly summarize coefficient if term == "5.drgn1"
local b_region5 = r(mean)

quietly summarize coefficient if term == "6.drgn1"
local b_region6 = r(mean)

quietly summarize coefficient if term == "7.drgn1"
local b_region7 = r(mean)


quietly summarize coefficient if term == "2.dhe"
local b_dhe2 = r(mean)

quietly summarize coefficient if term == "3.dhe"
local b_dhe3 = r(mean)

quietly summarize coefficient if term == "4.dhe"
local b_dhe4 = r(mean)

quietly summarize coefficient if term == "5.dhe"
local b_dhe5 = r(mean)


quietly summarize coefficient if term == "real_wage_growth_lag"
local b_real_wage_growth_lag = r(mean)

quietly summarize coefficient if term == "y2020"
local b_y2020 = r(mean)

quietly summarize coefficient if term == "y2021"
local b_y2021 = r(mean)

quietly summarize coefficient if term == "_cons"
local b_cons = r(mean)

restore


* Construct Panel EU-SILC predicted log hourly wage

gen temp_silc_lnw_0 = ///
      `b_cons' ///
    + `b_dag'       * dag ///
    + `b_dagsq'     * temp_age2 ///
    + `b_dehM'      * temp_d_deh_M ///
    + `b_dehL'      * temp_d_deh_L ///
    + `b_dehM_dag'  * temp_int_dehM_dag ///
    + `b_dehL_dag'  * temp_int_dehL_dag ///
    + `b_pt'        * temp_pt ///
    + `b_liwwh'     * liwwh ///
    + `b_region2'   * temp_region2 ///
    + `b_region3'   * temp_region3 ///
    + `b_region4'   * temp_region4 ///
    + `b_region5'   * temp_region5 ///
    + `b_region6'   * temp_region6 ///
    + `b_region7'   * temp_region7  ///
	+ `b_dhe2'   * temp_dhe_2 ///
    + `b_dhe3'   * temp_dhe_3 ///
    + `b_dhe4'   * temp_dhe_4 ///
    + `b_dhe5'   * temp_dhe_5 ///
	+ `b_real_wage_growth_lag' * temp_real_wage_growth_lag ///
	+ `b_y2020'     * temp_y2020 ///
    + `b_y2021'     * temp_y2021 ///
	if dgn == 0
	/*
 */
	

label variable temp_silc_lnw_0 ///
    "Panel EU-SILC predicted log hourly wage, females"


*====================================================================*
* MALES
*====================================================================*

preserve

use "${path}/regression estimates/temp_heckman_male.dta", clear

* Keep wage equation only
keep if equation == "wage"

* Put coefficients into locals
quietly summarize coefficient if term == "dag"
local b_dag = r(mean)

quietly summarize coefficient if term == "dagsq"
local b_dagsq = r(mean)

quietly summarize coefficient if term == "2.deh_c4"
local b_dehM = r(mean)

quietly summarize coefficient if term == "3.deh_c4"
local b_dehL = r(mean)

quietly summarize coefficient if term == "2.deh_c4#c.dag"
local b_dehM_dag = r(mean)

quietly summarize coefficient if term == "3.deh_c4#c.dag"
local b_dehL_dag = r(mean)

quietly summarize coefficient if term == "1.pt"
local b_pt = r(mean)

quietly summarize coefficient if term == "liwwh"
local b_liwwh = r(mean)

quietly summarize coefficient if term == "2.drgn1"
local b_region2 = r(mean)

quietly summarize coefficient if term == "3.drgn1"
local b_region3 = r(mean)

quietly summarize coefficient if term == "4.drgn1"
local b_region4 = r(mean)

quietly summarize coefficient if term == "5.drgn1"
local b_region5 = r(mean)

quietly summarize coefficient if term == "6.drgn1"
local b_region6 = r(mean)

quietly summarize coefficient if term == "7.drgn1"
local b_region7 = r(mean)


quietly summarize coefficient if term == "2.dhe"
local b_dhe2 = r(mean)

quietly summarize coefficient if term == "3.dhe"
local b_dhe3 = r(mean)

quietly summarize coefficient if term == "4.dhe"
local b_dhe4 = r(mean)

quietly summarize coefficient if term == "5.dhe"
local b_dhe5 = r(mean)


quietly summarize coefficient if term == "real_wage_growth_lag"
local b_real_wage_growth_lag = r(mean)

quietly summarize coefficient if term == "y2020"
local b_y2020 = r(mean)

quietly summarize coefficient if term == "y2021"
local b_y2021 = r(mean)

quietly summarize coefficient if term == "_cons"
local b_cons = r(mean)

restore


* Construct Panel EU-SILC predicted log hourly wage

gen temp_silc_lnw_1 = ///
      `b_cons' ///
    + `b_dag'       * dag ///
    + `b_dagsq'     * temp_age2 ///
    + `b_dehM'      * temp_d_deh_M ///
    + `b_dehL'      * temp_d_deh_L ///
    + `b_dehM_dag'  * temp_int_dehM_dag ///
    + `b_dehL_dag'  * temp_int_dehL_dag ///
    + `b_pt'        * temp_pt ///
    + `b_liwwh'     * liwwh ///
    + `b_region2'   * temp_region2 ///
    + `b_region3'   * temp_region3 ///
    + `b_region4'   * temp_region4 ///
    + `b_region5'   * temp_region5 ///
    + `b_region6'   * temp_region6 ///
    + `b_region7'   * temp_region7 ///
	+ `b_dhe2'   * temp_dhe_2 ///
    + `b_dhe3'   * temp_dhe_3 ///
    + `b_dhe4'   * temp_dhe_4 ///
    + `b_dhe5'   * temp_dhe_5 ///
	+ `b_real_wage_growth_lag' * temp_real_wage_growth_lag  ///
	+ `b_y2020'     * temp_y2020 ///
    + `b_y2021'     * temp_y2021 ///
	if dgn == 1
	/* 
    */

label variable temp_silc_lnw_1 ///
    "Panel EU-SILC predicted log hourly wage, males"


*====================================================================*
* CHECK
*====================================================================*

sum temp_silc_lnw_0 temp_silc_lnw_1 

*====================================================================*
* WOMEN: STOCHASTIC WAGE PREDICTION
*====================================================================*

/*
What we are doing:

1. Obtain sigma from the female Panel EU-SILC wage equation.

2. Start from the deterministic predicted log wage:
       temp_silc_lnw_0

3. Draw a random wage error:
       u ~ N(0, sigma)

4. Calculate the initial stochastic hourly wage:
       wage = exp(predicted log wage + random error)

5. Redraw the random error whenever the predicted wage is:
       - below 0.5 * statutory minimum wage, or
       - above the 2023 EU-SILC 99th percentile (€47.86/hour).

6. Continue until all predictions fall within these bounds.

This is a rejection/redraw rule, NOT a minimum-wage floor or wage cap.
*/


*------------------------------------------------------------*
* 1. Obtain sigma from the female Panel EU-SILC wage model
*------------------------------------------------------------*

preserve

use "${path}/regression estimates/temp_heckman_female.dta", clear

summ coefficient if equation == "model" & term == "sigma", meanonly
local sigma_female = r(mean)

restore


*------------------------------------------------------------*
* 2. Set 2023 EU-SILC upper wage bound
*------------------------------------------------------------*

local max_wage = 47.86096


*------------------------------------------------------------*
* 3. Draw initial random wage error
*------------------------------------------------------------*

capture drop temp_silc_u_0

gen double temp_silc_u_0 = ///
    rnormal(0, `sigma_female') ///
    if dgn == 0 & temp_silc_lnw_0 != .

label variable temp_silc_u_0 ///
    "Random wage error from EU-SILC model, women"


*------------------------------------------------------------*
* 4. Calculate initial stochastic hourly wage
*------------------------------------------------------------*

capture drop temp_silc_wage_0

gen double temp_silc_wage_0 = ///
    exp(temp_silc_lnw_0 + temp_silc_u_0) ///
    if dgn == 0 & temp_silc_lnw_0 != .

label variable temp_silc_wage_0 ///
    "Stochastic hourly wage, women"


*------------------------------------------------------------*
* 5. Check initial draws
*------------------------------------------------------------*

* Total number of predicted wages
count if dgn == 0 ///
    & temp_silc_lnw_0 != .

local n_total = r(N)


* Number below 0.5 * minimum wage
count if dgn == 0 ///
    & temp_silc_lnw_0 != . ///
    & temp_silc_wage_0 < 0.5 * mw_hour

local n_below = r(N)


* Number above 2023 EU-SILC P99
count if dgn == 0 ///
    & temp_silc_lnw_0 != . ///
    & temp_silc_wage_0 > `max_wage'

local n_above = r(N)


* Total number outside the bounds
local n_outside = `n_below' + `n_above'


display "--------------------------------------------------"
display "Women: total predicted wages = `n_total'"
display "Women: initial draws below 0.5*MW = `n_below'"
display "Women: initial draws above EU-SILC P99 = `n_above'"
display "Women: initial draws outside bounds = `n_outside'"
display "Women: percentage below 0.5*MW = " 100 * `n_below' / `n_total'
display "Women: percentage above EU-SILC P99 = " 100 * `n_above' / `n_total'
display "Women: lower bound = 0.5*MW"
display "Women: upper bound = `max_wage' euros/hour"
display "--------------------------------------------------"


*------------------------------------------------------------*
* 6. Redraw until wage falls within both bounds
*------------------------------------------------------------*

local n_redraws = 0

while 1 {

    * Identify observations requiring a redraw
    capture drop _redraw

    gen byte _redraw = ///
        dgn == 0 ///
        & temp_silc_lnw_0 != . ///
        & (temp_silc_wage_0 < 0.5 * mw_hour ///
        | temp_silc_wage_0 > `max_wage')

    quietly count if _redraw
    local n = r(N)

    * Stop when no observations require a redraw
    if `n' == 0 {
        continue, break
    }

    * Add number of observations being redrawn
    local n_redraws = `n_redraws' + `n'

    * Draw a new random wage error
    replace temp_silc_u_0 = ///
        rnormal(0, `sigma_female') ///
        if _redraw

    * Recalculate the wage using the new random error
    replace temp_silc_wage_0 = ///
        exp(temp_silc_lnw_0 + temp_silc_u_0) ///
        if _redraw

    drop _redraw
}


*------------------------------------------------------------*
* 7. Final checks
*------------------------------------------------------------*

* Final number below 0.5 * minimum wage
count if dgn == 0 ///
    & temp_silc_lnw_0 != . ///
    & temp_silc_wage_0 < 0.5 * mw_hour

local n_final_below = r(N)


* Final number above EU-SILC P99
count if dgn == 0 ///
    & temp_silc_lnw_0 != . ///
    & temp_silc_wage_0 > `max_wage'

local n_final_above = r(N)


display "--------------------------------------------------"
display "Women: final draws below 0.5*MW = `n_final_below'"
display "Women: final draws above EU-SILC P99 = `n_final_above'"
display "Women: total number of redraws = `n_redraws'"
display "Women: upper bound = `max_wage' euros/hour"
display "--------------------------------------------------"

*====================================================================*
* MEN: STOCHASTIC WAGE PREDICTION
*====================================================================*

/*
What we are doing:

1. Obtain sigma from the male Panel EU-SILC wage equation.

2. Start from the deterministic predicted log wage:
       temp_silc_lnw_1

3. Draw a random wage error:
       u ~ N(0, sigma)

4. Calculate the initial stochastic hourly wage:
       wage = exp(predicted log wage + random error)

5. Redraw the random error whenever the predicted wage is:
       - below 0.5 * statutory minimum wage, or
       - above the 2023 EU-SILC 99th percentile (€47.86/hour).

6. Continue until all predictions fall within these bounds.

This is a rejection/redraw rule, NOT a minimum-wage floor or wage cap.
*/


*------------------------------------------------------------*
* 1. Obtain sigma from the male Panel EU-SILC wage model
*------------------------------------------------------------*

preserve

use "${path}/regression estimates/temp_heckman_male.dta", clear

summ coefficient if equation == "model" & term == "sigma", meanonly
local sigma_male = r(mean)

restore


*------------------------------------------------------------*
* 2. Set 2023 EU-SILC upper wage bound
*------------------------------------------------------------*

local max_wage = 47.86096


*------------------------------------------------------------*
* 3. Draw initial random wage error
*------------------------------------------------------------*

capture drop temp_silc_u_1

gen double temp_silc_u_1 = ///
    rnormal(0, `sigma_male') ///
    if dgn == 1 & temp_silc_lnw_1 != .

label variable temp_silc_u_1 ///
    "Random wage error from EU-SILC model, men"


*------------------------------------------------------------*
* 4. Calculate initial stochastic hourly wage
*------------------------------------------------------------*

capture drop temp_silc_wage_1

gen double temp_silc_wage_1 = ///
    exp(temp_silc_lnw_1 + temp_silc_u_1) ///
    if dgn == 1 & temp_silc_lnw_1 != .

label variable temp_silc_wage_1 ///
    "Stochastic hourly wage, men"


*------------------------------------------------------------*
* 5. Check initial draws
*------------------------------------------------------------*

* Total number of predicted wages
count if dgn == 1 ///
    & temp_silc_lnw_1 != .

local n_total = r(N)


* Number below 0.5 * minimum wage
count if dgn == 1 ///
    & temp_silc_lnw_1 != . ///
    & temp_silc_wage_1 < 0.5 * mw_hour

local n_below = r(N)


* Number above 2023 EU-SILC P99
count if dgn == 1 ///
    & temp_silc_lnw_1 != . ///
    & temp_silc_wage_1 > `max_wage'

local n_above = r(N)


* Total number outside the bounds
local n_outside = `n_below' + `n_above'


display "--------------------------------------------------"
display "Men: total predicted wages = `n_total'"
display "Men: initial draws below 0.5*MW = `n_below'"
display "Men: initial draws above EU-SILC P99 = `n_above'"
display "Men: initial draws outside bounds = `n_outside'"
display "Men: percentage below 0.5*MW = " ///
    100 * `n_below' / `n_total'
display "Men: percentage above EU-SILC P99 = " ///
    100 * `n_above' / `n_total'
display "Men: lower bound = 0.5*MW"
display "Men: upper bound = `max_wage' euros/hour"
display "--------------------------------------------------"


*------------------------------------------------------------*
* 6. Redraw until wage falls within both bounds
*------------------------------------------------------------*

local n_redraws = 0

while 1 {

    * Identify observations requiring a redraw
    capture drop _redraw

    gen byte _redraw = ///
        dgn == 1 ///
        & temp_silc_lnw_1 != . ///
        & (temp_silc_wage_1 < 0.5 * mw_hour ///
        | temp_silc_wage_1 > `max_wage')

    quietly count if _redraw
    local n = r(N)

    * Stop when no observations require a redraw
    if `n' == 0 {
        continue, break
    }

    * Add number of observations being redrawn
    local n_redraws = `n_redraws' + `n'

    * Draw a new random wage error
    replace temp_silc_u_1 = ///
        rnormal(0, `sigma_male') ///
        if _redraw

    * Recalculate the wage using the new random error
    replace temp_silc_wage_1 = ///
        exp(temp_silc_lnw_1 + temp_silc_u_1) ///
        if _redraw

    drop _redraw
}

*------------------------------------------------------------*
* 7. Final checks
*------------------------------------------------------------*

* Final number below 0.5 * minimum wage
count if dgn == 1 ///
    & temp_silc_lnw_1 != . ///
    & temp_silc_wage_1 < 0.5 * mw_hour

local n_final_below = r(N)


* Final number above EU-SILC P99
count if dgn == 1 ///
    & temp_silc_lnw_1 != . ///
    & temp_silc_wage_1 > `max_wage'

local n_final_above = r(N)


display "--------------------------------------------------"
display "Men: final draws below 0.5*MW = `n_final_below'"
display "Men: final draws above EU-SILC P99 = `n_final_above'"
display "Men: total number of redraws = `n_redraws'"
display "Men: upper bound = `max_wage' euros/hour"
display "--------------------------------------------------"


*============================================================*
* Wage checks
*============================================================*

* Residual SDs from the Heckman models
display "Female residual SD (log wages) = " %9.6f `sigma_female'
display "Male residual SD (log wages)   = " %9.6f `sigma_male'

* Deterministic predicted log wages: mean and SD
display "FEMALE: deterministic predicted log wages"
summarize temp_silc_lnw_0

display "MALE: deterministic predicted log wages"
summarize temp_silc_lnw_1

* Deterministic wages in euros
capture drop temp_silc_det_wage_0 temp_silc_det_wage_1

generate double temp_silc_det_wage_0 = exp(temp_silc_lnw_0) ///
    if !missing(temp_silc_lnw_0)

generate double temp_silc_det_wage_1 = exp(temp_silc_lnw_1) ///
    if !missing(temp_silc_lnw_1)

display "FEMALE: deterministic wages in euros"
summarize temp_silc_det_wage_0

display "MALE: deterministic wages in euros"
summarize temp_silc_det_wage_1

* Final stochastic wages in euros
display "FEMALE: final simulated wages in euros"
summarize temp_silc_wage_0

display "MALE: final simulated wages in euros"
summarize temp_silc_wage_1

*============================================================*
* Wage checks: export results to Excel
*============================================================*

* Deterministic predicted log wages
quietly summarize temp_silc_lnw_0
local det_log_sd_f = r(sd)

quietly summarize temp_silc_lnw_1
local det_log_sd_m = r(sd)

* Deterministic wages in euros
capture drop temp_silc_det_wage_0 temp_silc_det_wage_1

generate double temp_silc_det_wage_0 = exp(temp_silc_lnw_0) ///
    if !missing(temp_silc_lnw_0)

generate double temp_silc_det_wage_1 = exp(temp_silc_lnw_1) ///
    if !missing(temp_silc_lnw_1)

quietly summarize temp_silc_det_wage_0
local det_mean_f = r(mean)
local det_sd_f   = r(sd)

quietly summarize temp_silc_det_wage_1
local det_mean_m = r(mean)
local det_sd_m   = r(sd)

* Final stochastic wages in euros
quietly summarize temp_silc_wage_0
local stoch_mean_f = r(mean)
local stoch_sd_f   = r(sd)

quietly summarize temp_silc_wage_1
local stoch_mean_m = r(mean)
local stoch_sd_m   = r(sd)

*============================================================*
* Export table to Excel
*============================================================*

putexcel set "${results_wi}/wage_imputation_checks.xlsx", replace sheet("Wage checks")

putexcel A1 = ("Statistic") ///
         B1 = ("Women") ///
         C1 = ("Men")

* 1. Deterministic log-wage SD
putexcel A2 = ("Deterministic log-wage SD") ///
         B2 = (`det_log_sd_f') ///
         C2 = (`det_log_sd_m')

* 2. Residual SD
putexcel A3 = ("Residual SD (log-wage model)") ///
         B3 = (`sigma_female') ///
         C3 = (`sigma_male')

* 3. Deterministic wage SD
putexcel A4 = ("Deterministic wage SD (EUR)") ///
         B4 = (`det_sd_f') ///
         C4 = (`det_sd_m')

* 4. Final stochastic wage SD
putexcel A5 = ("Final stochastic wage SD (EUR)") ///
         B5 = (`stoch_sd_f') ///
         C5 = (`stoch_sd_m')

* 5. Deterministic wage mean
putexcel A6 = ("Deterministic wage mean (EUR)") ///
         B6 = (`det_mean_f') ///
         C6 = (`det_mean_m')

* 6. Final stochastic wage mean
putexcel A7 = ("Final stochastic wage mean (EUR)") ///
         B7 = (`stoch_mean_f') ///
         C7 = (`stoch_mean_m')

* Format numeric values
//putexcel B2:C7, nformat("0.000000")

display "Excel file saved: ${results_wi}/wage_imputation_checks.xlsx"


***********************************************
* Graph of SILC-predicted wage vs. observed wage
* Final stochastic predictions after redraws
***********************************************

sum temp_silc_wage_0
sum temp_silc_wage_1


foreach gender in 0 1 {

    ************************************************
    * Scatterplot: observed vs. SILC prediction
    ************************************************

    twoway ///
        (scatter temp_silc_wage_`gender' temp_obs_wage ///
            if dgn==`gender' & !missing(temp_silc_wage_`gender', temp_obs_wage)) ///
        (line temp_obs_wage temp_obs_wage ///
            if dgn==`gender' & !missing(temp_silc_wage_`gender', temp_obs_wage)), ///
        title("Gross Hourly Wage") ///
        xtitle("Observed wage, Euros") ///
        ytitle("SILC-predicted wage, Euros")

    graph export ///
    "$results_wi/all/wages_scatter_euromod_silc_`gender'.png", ///
    as(png) replace


    ************************************************
    * Histogram: observed vs. SILC prediction
    ************************************************

    local subtitle = cond(`gender'==0, "Women", "Men")

    twoway ///
        (histogram temp_obs_wage ///
            if dgn==`gender' & ///
            !missing(temp_obs_wage, temp_silc_wage_`gender') & ///
            temp_obs_wage<60, ///
            width(0.5) lcolor(gs12) fcolor(gs12)) ///
        (histogram temp_silc_wage_`gender' ///
            if dgn==`gender' & ///
            !missing(temp_obs_wage, temp_silc_wage_`gender') & ///
            temp_silc_wage_`gender'<60, ///
            width(0.5) fcolor(none) lcolor(red)), ///
        legend(order(1 "EUROMOD observed wage" ///
                     2 "Stochastic prediction using EU-SILC")) ///
        title("Gross Hourly Wage (Level)") ///
        subtitle("`subtitle'") ///
        xtitle("Euros")

   graph export ///
    "$results_wi/all/wages_hist_euromod_silc_`gender'.png", ///
    as(png) replace

} // end of gender loop



*=======================================================================
*           wage imputations
*=======================================================================

*------------------------------------------------------------
* // @@@ WAGE IMPUTATION METHOD #wage1 @@@
* make predicted wage=yivwg for everyone
*------------------------------------------------------------	
* we are using SILC based prediction with top floor 
replace yivwg=temp_silc_wage_0 if dgn==0   	     //For female, make predicted wage=yivwg (yivwg: name for predicted hourly wage in Euromod)
replace yivwg=temp_silc_wage_1 if dgn==1   	     //For male, make predicted wage=yivwg (yivwg: name for predicted hourly wage in Euromod)

recode yivwg (.=-1)												//not-wages as -1

su temp_obs_wage yivwg if temp_work==1 & temp_heckman==1& yivwg!=-1

bysort dgn:su temp_obs_wage yivwg if temp_work==1 & temp_heckman==1 & yivwg!=-1
bysort dgn:su temp_obs_wage yivwg if temp_work==1 & temp_heckman==1 & yivwg!=-1 & temp_obs_wage<14 

 
save afterheckman,replace


/*============================================================*
* DIAGNOSTIC: wages without random errors
* Does NOT permanently change the original simulated wages
*============================================================*

* Save the original simulated wages
tempvar wage_original_0 wage_original_1
generate double `wage_original_0' = temp_silc_wage_0
generate double `wage_original_1' = temp_silc_wage_1

* Create deterministic wages, respecting the existing bounds
generate double temp_test_wage_0 = exp(temp_silc_lnw_0)
generate double temp_test_wage_1 = exp(temp_silc_lnw_1)

replace temp_test_wage_0 = 0.5 * mw_hour ///
    if temp_test_wage_0 < 0.5 * mw_hour ///
    & !missing(temp_test_wage_0)

replace temp_test_wage_0 = `max_wage' ///
    if temp_test_wage_0 > `max_wage' ///
    & !missing(temp_test_wage_0)

replace temp_test_wage_1 = 0.5 * mw_hour ///
    if temp_test_wage_1 < 0.5 * mw_hour ///
    & !missing(temp_test_wage_1)

replace temp_test_wage_1 = `max_wage' ///
    if temp_test_wage_1 > `max_wage' ///
    & !missing(temp_test_wage_1)

* Compare wage distributions
display "Original female wages"
summarize `wage_original_0'

display "Deterministic female wages"
summarize temp_test_wage_0

display "Original male wages"
summarize `wage_original_1'

display "Deterministic male wages"
summarize temp_test_wage_1

*============================================================*
* END OF WAGE DIAGNOSTIC
*============================================================*
*/

*--------------------------------------------------------------------------------------------------------------------------
*Drop individuals outside of flexible households (in "singles"' or couples' households)
*For the ease of running EUROMOD
*--------------------------------------------------------------------------------------------------------------------------
/*We keep clean single households (exactly 1 flexible worker) and clean couple households (exactly 2 flexible workers), 
and drop anything that does not match this simple household structure*/

use afterheckman,clear
//already problematic with lhw_f vbl
duplicates report idperson  //count how many unique individuals there are
di r(unique_value) 

bysort idhh: egen temp_with_singles=total(temp_singles), missing  //missing as 0
replace temp_with_singles=(temp_with_singles>0)   //dummy of at least one family member is "singles"

bysort idhh: egen temp_with_couples=total(temp_couples), missing
replace temp_with_couples=(temp_with_couples>0)   //dummy of at least one family member is "couples"

count if temp_singles==1 & temp_n_ch>0 

//check whether a not flexible individual can have temp_with_couples=1 and temp_with_singles=1 at the same time 
su dag if temp_with_singles==1 &temp_with_couples==1 &temp_not_flexible==1  
tab les if temp_with_singles==1 &temp_with_couples==1 &temp_not_flexible==1  //they are either pre-school or student or pensioner or disabled 
***
su temp_singles temp_couples temp_not_flexible if temp_with_singles==1 &temp_with_couples==1  //this shows singles, couples, and not flexible individuals can all live together

count if temp_with_singles==1 &temp_with_couples==1  

//count if there are more than one flexible workers (lone parent+child aged between 16 and 18 and not student) in a "singles"' household
gen worker_count=(temp_not_flexible==0)
bysort idhh: egen number_workers_singleshh=total(worker_count) if temp_singles==1, missing
su number_workers_singles
count if number_workers_singleshh>1 & temp_singles==1   
duplicates report idhh if number_workers_singleshh>1 & temp_singles==1  

//check there are no more than TWO flexible workers in a "COUPLES"' household
bysort idhh: egen number_workers_coupleshh=total(worker_count) if temp_couples==1, missing
su number_workers_couples
count if number_workers_coupleshh>2 & temp_couples==1 
drop if number_workers_coupleshh>2 & temp_couples==1 
duplicates report idperson  //count how many unique individuals there are
di r(unique_value) 

count if number_workers_coupleshh<2 & temp_couples==1   //no such obs 
drop if number_workers_coupleshh<2 & temp_couples==1 
duplicates report idperson  //count how many unique individuals there are
di r(unique_value)  

//assert number_workers_coupleshh==2 if temp_couples==1
assert number_workers_coupleshh>=2 if temp_couples==1

//dropping mixed hholds with singles and couples 
count if temp_with_singles==1 &temp_with_couples==1 
drop if temp_with_singles==1 &temp_with_couples==1  //to remove "mixed hhs" (hhs who are flexible singles but live with flexible couples,
// or hhs who are flexible couples but live with flexible singles)
duplicates report idperson  //count how many unique individuals there are
di r(unique_value) 

*No. of hhs (lone parent+child aged between 16 and 18 and not student) 
drop if number_workers_singleshh>1 & temp_singles==1   //to remove hhs with multiple ls flexible singles living together
//(2,983 observations deleted)
duplicates report idperson  //count how many unique individuals there are
di r(unique_value) 

assert number_workers_singles==1 if temp_singles==1

gen temp_alt_n=(temp_with_singles==1 & temp_with_couples==0) //dummy of individuals that should have n alternatives
gen temp_alt_nsq=(temp_with_couples==1)   //dummy of individuals that should have n^2 alternatives
gen temp_drop=(temp_with_singles==0 & temp_with_couples==0)  //dummy of individuals that can be dropped from EUROMOD input data 
//because they are neither singles nor couples and do not live with singles or couples
assert temp_not_flexible==1 if temp_drop==1  //check that all individuals who will be dropped are not flexible
assert temp_alt_n+temp_alt_nsq+temp_drop==1

//check hours of work after all the drops 

fre temp_lhw_dobs_0 if dgn==0 & temp_couples ==1 //16.30 % with zero hours ==> 14.55  
fre temp_lhw_dobs_1 if dgn==1 & temp_couples ==1 // 4.20 % with zero hours ==>  3.81

fre temp_lhw_dobs_0 if dgn==0 & temp_singles_indep==1 //17.72 % with zero hours ==> 17.62
fre temp_lhw_dobs_1 if dgn==1 & temp_singles_indep==1 //10.63 % with zero hours ==> 9.08

fre temp_lhw_dobs_0 if dgn==0 & temp_singles_dep==1 //54.13 % with zero hours ==> 54.38
fre temp_lhw_dobs_1 if dgn==1 & temp_singles_dep==1 // 10.04 % with zero hours ==> 9.00


*=======================================================================
*           Labour supply alternatives
*=======================================================================
tab les if temp_drop==1
tab dag if temp_drop==1 &(les==2|les==3)

drop if temp_drop==1  //to reduce the burden of EUROMOD
duplicates report idperson  //count how many unique individuals there are
//(8,810 observations deleted) 29540 obs remain 

* create columns with imputed alternatives (same for everyone who is labour supply flexible)
foreach gender in 0 1{
local i = 0
levelsof temp_lhw_dobs_`gender', local(levels)
foreach l in `r(levels)' {
	gen byte temp_lhw_dobs_`gender'_`i' =  `l' if temp_not_flexible==0
	local i = `i' + 1
}  //loop end of ls alternatives `i'
}  //loop end of gender `gender'
sum temp_lhw_dobs_*


/*
forvalues i = 1 (1) $n_workchoices{
	assert lhw != .
	replace temp_bracket = `i' if lhw > $min_hours_`i'
}
*/

* choice set: generation of $n_choices^2 columns
// first index refers to male choice, second index refers to female choice
// note: couples (both partners flexible) have access to all $n_choices^2 options, 
// note: Although "singles" have access only to $n_choices options, I replicate these $n_choices across all choices of their partners.
// note: not flexible individuals' all options =0 hrs 
// Due to the way to construct fake id* to cheat EUROMOD, the treatment to "singles" and not flexible individuals is only for the purpose 
// of linking with flexible people in the same hh to provide info for EUROMOD.
forvalues m=0/$n_workchoices  {
	forvalues f=0/$n_workchoices  {
	
		capture drop lhw_`m'`f'
		gen byte lhw_`m'`f' = .
		replace lhw_`m'`f'=0 if temp_not_flexible==1  //both genders of not flexible individuals
		// males
		replace lhw_`m'`f' = temp_lhw_dobs_1_`m' if dgn == 1 & (temp_couples==1 |temp_singles==1) 		 //male partner in flexible couples	and male individuals in "singles"	 
		
		// females
		replace lhw_`m'`f' = temp_lhw_dobs_0_`f' if dgn == 0 & (temp_couples==1 |temp_singles==1)  		 //female partner in flexible couples and female individuals in "singles" 	 
	}
}

* choice conversion
// for flexible couples, flag for choice_`m'`f' is switched on only when the male partner chooses `m' and the female partner chooses `f'
// for second type of "singles", the inflexible partner always chooses 1st bracket (ie. 0 hours)
// for first type of "singles" (without a partner), we assume that their virtual partner chooses 1st bracket (ie. 0 hours).
// first index refers to male choice, second index refers to female choice

add_partner_variables "temp_bracket_0 temp_bracket_1 dgn" 
		replace partner_temp_bracket_0 = 0 if idpartner>0 &partner_dgn==0 &(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0) //second type of "singles"' partner must not work
		replace partner_temp_bracket_1 = 0 if idpartner>0 &partner_dgn==1 &(temp_p_student==1|temp_p_sick_dis==1|temp_p_workage==0) //second type of "singles"' partner must not work


forvalues m=0/$n_workchoices {
	forvalues f=0/$n_workchoices {
		gen byte temp_choicehh_`m'`f' = .
		// males
		replace temp_choicehh_`m'`f' = (temp_bracket_1 == `m' & partner_temp_bracket_0 == `f') 	if dgn == 1 & temp_couples==1  	 //male partner in flexible couples
		replace temp_choicehh_`m'`f' = (temp_bracket_1 == `m') 							if dgn == 1 & temp_singles==1 & `f' == 0   	//male "singles"
		// females
		replace temp_choicehh_`m'`f' = (temp_bracket_0 == `f' & partner_temp_bracket_1 == `m') 	if dgn == 0 & temp_couples==1  	 //female partner in flexible couples
		replace temp_choicehh_`m'`f' = (temp_bracket_0 == `f') 							if dgn == 0 & temp_singles==1 & `m' == 0   	//female "singles"
	}
}


drop partner_temp_bracket* 

*------------------------------------------------------------
* Earnings
*------------------------------------------------------------	

gen temp_em=(yem>yse |(yem==yse & yem!=0))  //assign income to be employed income or self-employed income depending on whether yem>=yse for workers
gen temp_se=(yse>yem)   //assign income to be employed income or self-employed income depending on whether yem>yse for workers

assert temp_em==(1-temp_se) if yem!=0|yse!=0 //checking that non-zero hours working regimes either belong to temp_em or temp_se category
gen temp_nonworker=(yem==0 & yse==0)
assert (temp_em+temp_se+temp_nonworker==1) //checking that all regimes belong to one of the following: temp_em, temp_se, temp_nonworker
//for workers' all states, assume all income are employed income or self-employed income depending which is their major income source in their actual state

forvalues m=0/$n_workchoices {
	forvalues f=0/$n_workchoices {
gen yem_`m'`f' = .
gen yse_`m'`f' = .

replace yem_`m'`f'=yivwg*lhw_`m'`f'*4.3 if temp_em==1		   
replace yse_`m'`f'=0 if temp_em==1 

replace yse_`m'`f'=yivwg*lhw_`m'`f'*4.3 if temp_se==1  
replace yem_`m'`f'=0 if temp_se==1 

// for non-workers' counterfacual states, assume all income are employed income
replace yem_`m'`f'=yivwg*lhw_`m'`f'*4.3 if temp_nonworker==1	
replace yse_`m'`f'=0 if temp_nonworker==1	

  }
}

gen temp_yem=yem
gen temp_yse=yse
drop yem yse
*NOTE: for both the actual and counter-factural states, yem and yse are computed using wage*discretised hours of work. This now holds automatically because wage is generated as income/discritized hours


*-----------------------------------------------------------------------------------
* Generation of new identifiers for each LS alternative
*-----------------------------------------------------------------------------------
/*
foreach var in idhh idperson idpartner idfather idmother {
	capture drop `var'*
}
*/
forvalues m=0/$n_workchoices {
	forvalues f=0/$n_workchoices {
		foreach var in idhh idperson idpartner idfather idmother  {
			gen double `var'_`m'`f' = `var' * 100 + `m'*10 + `f'  //fake id to cheat EUROMOD
			replace `var'_`m'`f' = 0 if `var' == 0
		}
	}
}

*check idperson identifies persons uniquely
duplicates r idperson
gen double temp_idorigperson2=idperson		 			//save original id. idorigperson (within hh id) already existed and not the same as idperson
gen temp_idorigpartner=idpartner
gen temp_idorighh=idhh
gen temp_idorigmother=idmother
gen temp_idorigfather=idfather
drop idperson idpartner idhh idmother idfather

format temp_id* %15.0g 
duplicates r temp_idorigperson2
di r(unique_value) 
/*
foreach var of varlist idhh idperson idpartner idfather idmother lhw yem yse {
	quietly rename `var' obs_`var'
}

*/

preserve
drop idhh_* idperson_* idpartner_* idfather_* idmother_*  lhw_* yem_* yse_* temp_choicehh_*
save full_info,replace
restore
save beforeReshape.dta,replace


*=======================================================================
*            Reshaping data 
*=======================================================================

use beforeReshape.dta, clear
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value) 

keep  temp_idorigperson2 idhh_* idperson_* idpartner_* idfather_* idmother_*  lhw_* yem_* yse_* temp_choicehh_*

local reshapevbles = "idhh_ idperson_ idpartner_ idfather_ idmother_  lhw_ yem_ yse_  temp_choicehh_"
reshape long `reshapevbles', i(temp_idorigperson2) j(temp_option) string


format id* %15.0g 
		foreach var in idhh idperson idpartner idfather idmother  lhw yem yse  temp_choicehh  {
		rename `var'_ `var'
}
duplicates report idperson	// no duplicates
duplicates report idhh		


merge m:1 temp_idorigperson2 using full_info
assert _merge==3
drop _merge
gen ind_option = substr(temp_option,1,1) if dgn==1  //alternative bracket for individual male
replace ind_option = substr(temp_option,2,1) if dgn==0 //alternative bracket for individual female
destring ind_option, force replace
gen temp_choice=(ind_option==temp_bracket_0) if dgn==0  //dummy for female individual choice
replace temp_choice=(ind_option==temp_bracket_1) if dgn==1  //dummy for male individual choice

drop ind_option

destring temp_option, force gen (temp_seq)

//check data structure 
gsort temp_idorigperson2 temp_seq //Place observations in ascending order of temp_seq within ascending order of original person id
bysort temp_idorigperson2:egen temp_seq2=seq() //give each working regime a label from 1 to $n_choice^2
replace lhw=0 if temp_not_flexible==1  //not flexible persons should have zero hours of work

bysort temp_idorigperson2: egen double mean_choicehh=mean(temp_choicehh)  //compute the mean of flag of hh choice for the same individual
assert mean_choicehh==1/($n_choices)^2 if temp_couples==1 //for an individual in a flexible couple, 1 option is chosen from ($n_choices)^2 options
assert mean_choicehh==1/($n_choices) if temp_singles==1  //for an individual in "singles", 1 option is chosen from $n_choices options
assert lhw!=. & yem!=. & yse!=. if temp_singles==1|temp_couples==1 //make sure lhw, yse, yse are not missing for sample to be included in labour supply estimation

drop mean_choicehh

assert temp_choicehh!=. if temp_couples==1  
assert temp_choicehh==. if temp_not_flexible==1
//note: for each individual in "singles", $n_choices out of $n_choices^2 temp_choicehh are non-missing

gen count=1 
bysort temp_idorigperson2: egen sum_option=total(count)  //compute the sum of options
assert sum_option==$n_choices^2   //up to this point, every individual has $n_choices^2 alternatives
drop count sum_option


//update in v8
drop if temp_choicehh==. & temp_singles==1   //drop invalid rows for singles
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value)


bysort idhh: egen temp_with_singles2=total(temp_singles)  //the previously generated temp_with_singles may not be useful because up to this point some singles are dropped already 
drop if temp_with_singles2==0 & temp_with_couples==0 & temp_not_flexible==1  //delete not flexible people with no singles or couples to attach to
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value) 

gen count=1
bysort temp_idorigperson2: egen sum_option=total(count)  //compute the sum of options

assert sum_option==$n_choices^2 if temp_alt_nsq==1  //yes
assert sum_option==$n_choices if temp_alt_n==1  
su temp_alt_nsq temp_with_singles temp_with_couples if temp_not_flexible==1
drop count sum_option
//check again
assert temp_choicehh!=. if temp_couples==1
assert temp_choicehh!=. if temp_singles==1  //this is new because now singles only have $n_choices kept, solved-contradiction: all aged 16,17,temp_alt_nsq==1, having 12 choices
assert temp_choicehh==. if temp_not_flexible==1

*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
* Correct values for benefits 
*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #2(A) @@@
/*SIMULATED BENEFITS:
Do not worry about them as EUROMOD calculates
the right amount in all choices, given other variables are set correctly.
*/


// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #2(B1) @@@
/*BENEFITS NOT SIMULATED, COMPATIBLE WITH A WORKING CONDITION BUT DEPEND ON YEM\LHW:
Set them to zero (Otherwise they are positive only in the observed choice and not modelled in the other choices, 
and this creates a bias in the estimates of the utility function).
*/ 
foreach var in bhl ysv bho { 
replace `var'=0 if temp_singles==1|temp_couples==1 
} 
 
// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #2(B2) @@@
/*BENEFITS NOT SIMULATED, NOT COMPATIBLE WITH A WORKING CONDITION AND DO NOT DEPEND ON YEM\LHW:
Set them equal to the amount in the observed choice.
Examples: scholarships */

cap drop mean_*
foreach var in bed { 
bysort temp_idorigperson2: egen mean_`var'=mean(`var')
//assert `var'==mean_`var'  //make sure `var' is equal to the amount in the observed choice
assert abs(`var' - mean_`var') <= 0.1 
drop mean_`var'
}


// @@@ BENEFITS COUNTERFACTUAL ALLOCATION: ASSUMPTION #2(B3) @@@
/*
BENEFITS NOT SIMULATED, NOT COMPATIBLE WITH A WORKING CONDITION AND AN INDIVIDUAL RECEIVES THEM IN THE OBSERVED CHOICE (E.G. A DISABILITY BENEFIT):
Exclude this individual from the sample used for labour supply estimates because it means that, in the observed choice, the individual
has some charateristics incompatible with a working condition
Examples: maternity/childcare leave, disability, unemployment */
foreach var in bma bunot pdicm pdinc pdi00 pdiot {
drop if (`var'>0)& lhw==0 & (temp_singles==1|temp_couples==1) 
} 


/////////////////////////////////////////////////////////////
//Now after benefit correction, check data structure again //
/////////////////////////////////////////////////////////////
gen d=1
bysort temp_idorigperson2: egen count=total(d)
su count
drop if count!=($n_choices)^2 &temp_alt_nsq==1
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value) 

drop if count!=($n_choices) &temp_alt_n==1
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value) 

drop d count
gsort temp_idorigperson2 temp_seq //Place observations in ascending order of temp_seq within ascending order of original person id
assert lhw==0 if temp_not_flexible==1  //not flexible persons should have zero hours of work

bysort temp_idorigperson2: egen double mean_choicehh=mean(temp_choicehh)  //compute the mean of flag of hh choice for the same individual
assert mean_choicehh==1/($n_choices)^2 if temp_couples==1 //for an individual in a flexible couple, 1 option is chosen from ($n_choices)^2 options
assert mean_choicehh==1/($n_choices) if temp_singles==1  //for an individual in "singles", 1 option is chosen from $n_choices options
assert lhw!=. & yem!=. & yse!=. if temp_singles==1|temp_couples==1 //make sure lhw, yse, yse are not missing for sample to be included in labour supply estimation

drop mean_choicehh


/*
@@@ tax compliance assumptions @@@
NO TCA add-on in ES
*/

*------------------------------------------------------------
* Store information not for EUROMOD for later use
*------------------------------------------------------------	
preserve
keep id* temp*
save temp_file.dta, replace
restore
duplicates report temp_idorigperson2  //count how many unique individuals there are
di r(unique_value) 
assert temp_singles_indep+temp_singles_dep+temp_couples+temp_not_flexible==1
count if temp_singles_indep==1&temp_choicehh==1 
count if temp_singles_dep==1 &temp_choicehh==1 
count if temp_couples==1 &temp_choicehh==1 
count if temp_not_flexible==1&temp_choicehh==1 

save individuals.dta,replace

*=======================================================================
*           create EUROMOD input data
*=======================================================================
*----------------------------------------------------------------------------------------------------
* singles_wage1.dta as input data(Predicted wage for everyone), but not in the EM input folder yet
*-----------------------------------------------------------------------------------------------------	
use individuals,clear
drop temp* xs*                                                //This is because as per EUROMOD conventions, some variables should not appear in the input database.
sort idhh idperson
drop number*  partner_dgn _est* //ratio*

save individuals_wage1.dta, replace

*-------------------------------------------------------------------------------------------------------------
* singles_wage2.dta as input data(Predicted wage for non-workers only), but not in the EM input folder yet
*-------------------------------------------------------------------------------------------------------------	
use individuals,clear
drop number*  partner_dgn _est* //ratio*

***************************************************
* // @@@ WAGE IMPUTATION METHOD #wage2@@@
* make predicted wage=yivwg only for non-workers 
*(before this yivwg=predicted wage for everyone)
****************************************************	
replace yivwg=temp_obs_wage if (temp_obs_wage<.) & (temp_em==1|temp_se==1) //for workers used for the Heckman estimation, wages=actual wages

//for workers' all states, assume all income are employed income or self-employed income depending which is their major income source in their actual state
replace yem=yivwg*lhw*4.3 if temp_em==1		   
replace yse=0 if temp_em==1 

replace yse=yivwg*lhw*4.3 if temp_se==1                     
replace yem=0 if temp_se==1 

// for non-workers' counterfacual states, assume all income are employed income
replace yem=yivwg*lhw*4.3 if temp_nonworker==1	&temp_choice==0  


drop temp* xs*    //This is because as per EUROMOD conventions, some variables should not appear in the input database.
sort idhh idperson

save individuals_wage2.dta, replace


************************************************************
*						Run EUROMOD with Stata
************************************************************

*loop through wage1, wage2:export as em input file, then run EM, then save output in the result folder for labour supply estimation, 
*named "individuals_output_wage`i'"

foreach i in 1 2{ 
//local i=2  //only do for wage1 
use individuals_wage`i',clear
export delimited "$em_input\$file_input.txt", replace nolabel delim(tab) //create input data for EUROMOD

//note that if input data is in nationla currency - but we want output is euros - this needs to be manually changed in model settings.
//ES data is in Euros 
*version 13
* Call EUROMOD 

capture erase "${em_output}\$file_output.txt"  //erase previous output file, this is done in case EUROMOD call from Stata fails, to be sure we are not opening an early run of the model

shell "${em_exe}" -emPath "${em_models}" -sys "${policy_year}" -data "${file_input}"  //-forceOutputInEuro call EUROMOD 1:Program to call 2: path for folder 3: system name 4: dataset to use

*import EUROMOD RUN

import delimited "${em_output}\${file_output}.txt", clear  //import data from txt file in output folder 

save individuals_output_wage`i',replace

}

log close
