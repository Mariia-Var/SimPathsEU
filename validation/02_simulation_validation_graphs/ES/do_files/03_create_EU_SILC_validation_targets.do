
/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         03_create_EU_SILC_validation_targets.do
* DESCRIPTION:          Constructs EU-SILC variables for simulation validation.
* COUNTRY:              ES
* DATA:                 EU-SILC longitudinal panel (pooled initial populations)
* AUTHORS:              Patryk Bronka, Ashley Burdett, Daria Popova
* LAST UPDATE:          21 October 2026
********************************************************************************
* NOTES:
*
*   -----------------------------------------------------------------------
*    What this file does
*   -----------------------------------------------------------------------
*   This do-file prepares the observed EU-SILC variables required for
*   validation plots, using the pooled initial population dataset.
*
*   It constructs variables covering demographics, partnership status,
*   children, education, health, labour market outcomes, and income.
*   Variables are recoded and harmonised with the corresponding SimPaths
*   outputs to facilitate comparisons between observed and simulated data.
*
*   Personal income variables are converted from the inverse hyperbolic
*   sine (IHS) transformation to levels and from monthly to annual
*   amounts. Benefit-unit income measures are constructed by aggregating
*   individual incomes, and disposable income is equivalised using the
*   modified OECD equivalence scale.
*
*   The sample is restricted to the specified validation years, but
*   individuals of all ages are retained. Age restrictions are applied
*   separately by the individual plotting do-files.
*
*******************************************************************************/


* Load initial populations 
use "$dir_init_pop_data/${country}_pooled_ipop.dta", clear


** IDENTIFIERS
rename idhh idHh
rename idbenefitunit idBu
rename idperson idPers
rename idpartner idPartner
rename idmother idMother
rename idfather idFather
rename swv statCollectionWave


** TIME
fre stm
keep if stm <= $max_year
gen year = stm 


** DEMOGRAPHICS

* Gender 
rename dgn demMaleFlag

replace demMaleFlag = . if demMaleFlag < 0


* Age 
rename dag demAge

replace demAge = . if demAge < 0

*  Age groups
gen ageGroup = .
replace ageGroup = 0 if demAge >= 0 & demAge < 15
replace ageGroup = 1 if demAge >= 15 & demAge < 20
replace ageGroup = 2 if demAge >= 20 & demAge < 25
replace ageGroup = 3 if demAge >= 25 & demAge < 30
replace ageGroup = 4 if demAge >= 30 & demAge < 35
replace ageGroup = 5 if demAge >= 35 & demAge < 40
replace ageGroup = 6 if demAge >= 40 & demAge < 60
replace ageGroup = 7 if demAge >= 60 & demAge < 80
replace ageGroup = 8 if demAge >= 80 & demAge <= 100

label def ageGrouplb /// 
	0 "ageGroup_0_14" ///
	1 "ageGroup_15_19" ///
	2 "ageGroup_20_24" ///
	3 "ageGroup_25_29" ///
	4 "ageGroup_30_34" ///
	5 "ageGroup_35_39" ///
	6 "ageGroup_40_59" ///
	7 "ageGroup_60_79" ///
	8 "ageGroup_80_100" ///
	
label val ageGroup ageGrouplb
fre ageGroup

gen ageGroup2 = .
replace ageGroup2 = 0 if demAge >= 16 & demAge < 25
replace ageGroup2 = 1 if demAge >= 25 & demAge < 30
replace ageGroup2 = 2 if demAge >= 30 & demAge < 35
replace ageGroup2 = 3 if demAge >= 35 & demAge < 40
replace ageGroup2 = 4 if demAge >= 40 & demAge < 45
replace ageGroup2 = 5 if demAge >= 45 & demAge < 50
replace ageGroup2 = 6 if demAge >= 50 & demAge < 55
replace ageGroup2 = 7 if demAge >= 55 & demAge < 60
replace ageGroup2 = 8 if demAge >= 60 & demAge <= 65

label def ageGrouplb2 /// 
	0 "ageGroup_16_24" ///
	1 "ageGroup_25_29" ///
	2 "ageGroup_30_34" ///
	3 "ageGroup_35_39" ///
	4 "ageGroup_40_44" ///
	5 "ageGroup_45_49" ///
	6 "ageGroup_50_54" ///
	7 "ageGroup_55_59" ///
	8 "ageGroup_60_65" ///
	
label val ageGroup2 ageGrouplb2
fre ageGroup2


* Partnership status  
rename dcpst demPartnerStatus

gen valid_partnered = (demPartnerStatus == 1) 
gen valid_single = (demPartnerStatus == 2) 

replace valid_partnered = . if demPartnerStatus == . | demPartnerStatus < 0 
replace valid_single = . if demPartnerStatus == . | demPartnerStatus < 0 


* Number of children
rename dnc demNChild
rename dnc02 demNChild0to2

gen new_born = (demAge == 0 & demNChild0to2 != 0)
bysort idBu year (new_born): gen demNChild0 = (new_born[_N] == 1)

gen children_0 = (demNChild == 0)
gen children_1 = (demNChild == 1)
gen children_2 = (demNChild == 2)
gen children_3plus = (demNChild >= 3 & demNChild != .)

* Interaction of partnership status and number of children
foreach var1 in valid_partnered valid_single {
	
	foreach var2 in children_0 children_1 children_2 children_3plus {
	
		gen `var1'_`var2' = (`var1' & `var2')
	
	}

}

* Have a new born 
gen valid_new_born = (dchpd > 0 & dchpd != .) 

order valid_new_born dchpd


** EDUCATION
* Attainment dummies 
rename deh_c4 eduHighestC4

gen valid_edu_na = (eduHighestC4 == 0)
gen valid_edu_high = (eduHighestC4 == 1)
gen valid_edu_med = (eduHighestC4 == 2)
gen valid_edu_low = (eduHighestC4 == 3) 

gen deh_flag = ///
	(flag_deh_imp_mono == 1 | flag_deh_imp_reg == 1 | flag_dehsp_imp_reg == 1)
 
replace valid_edu_na = . if eduHighestC4 == . | eduHighestC4 < 0 | deh_flag == 1
replace valid_edu_high = . if eduHighestC4 == . | eduHighestC4 < 0 | ///
	deh_flag == 1
replace valid_edu_med = . if eduHighestC4 == . | eduHighestC4 < 0 | ///
	deh_flag == 1
replace valid_edu_low = . if eduHighestC4 == . | eduHighestC4 < 0 | ///
	deh_flag == 1
 
 
** HEALTH 
* Disabed / LT sick 
rename dlltsd healthDsblLongtermFlag

gen valid_healthDsblLongtermFlag = healthDsblLongtermFlag
replace valid_healthDsblLongtermFlag = . if valid_healthDsblLongtermFlag < 0 

* Self rated health
rename dhe valid_healthSelfRated 

replace valid_healthSelfRated = . if valid_healthSelfRated < 0 | ///
	flag_dhe_imp == 1 


** LABOUR MARKET
* Economic activity dummies
rename les_c3 labC3
rename les_c4 labC4

gen valid_employed = (labC4 == 1)
gen valid_student = (labC4 == 2)
gen valid_inactive = (labC4 == 3)
gen valid_retired = (labC4 == 4)

replace valid_employed = . if labC4 < 0 | labC4 == . 
replace valid_student = . if labC4 < 0 | labC4 == . 
replace valid_inactive = . if labC4 < 0 | labC4 == . 
replace valid_retired = . if labC4 < 0 | labC4 == . 

* Hours worked weekly (continuous)
rename lhw labHrsWorkWeek

gen valid_labHrsWorkWeek = labHrsWorkWeek


* Hours worked weekly (categories)
* Bands set in the master file to match the SimPaths categories

gen valid_labHrsWorkEnumWeek = "ZERO" 

* Females 
replace valid_labHrsWorkEnumWeek = "TWENTY" if ///
	labHrsWorkWeek >= ${hrs_cat1_lb_f} & labHrsWorkWeek <= ${hrs_cat1_ub_f} ///
	& demMaleFlag == 0 
replace valid_labHrsWorkEnumWeek = "THIRTY" if ///
	labHrsWorkWeek > ${hrs_cat1_ub_f} & labHrsWorkWeek <= ${hrs_cat2_ub_f} ///
	& demMaleFlag == 0 
replace valid_labHrsWorkEnumWeek = "THIRTY_SEVEN" if ///
	labHrsWorkWeek > ${hrs_cat2_ub_f} & labHrsWorkWeek <= ${hrs_cat3_ub_f} ///
	& demMaleFlag == 0 	
replace valid_labHrsWorkEnumWeek = "FORTY" if ///
	labHrsWorkWeek > ${hrs_cat3_ub_f} & labHrsWorkWeek <= ${hrs_cat4_ub_f} ///
	& demMaleFlag == 0 	
replace valid_labHrsWorkEnumWeek = "FIFTY" if ///
	labHrsWorkWeek > ${hrs_cat4_ub_f} & !missing(labHrsWorkWeek) ///
	& demMaleFlag == 0 	
	
* Males 
replace valid_labHrsWorkEnumWeek = "TWENTY" if ///
	labHrsWorkWeek >= ${hrs_cat1_lb_m} & labHrsWorkWeek <= ${hrs_cat1_ub_m} ///
	& demMaleFlag == 1 
replace valid_labHrsWorkEnumWeek = "THIRTY_SEVEN" if ///
	labHrsWorkWeek > ${hrs_cat1_ub_m} & labHrsWorkWeek <= ${hrs_cat2_ub_m} ///
	& demMaleFlag == 1 
replace valid_labHrsWorkEnumWeek = "FORTY" if ///
	labHrsWorkWeek > ${hrs_cat2_ub_m} & labHrsWorkWeek <= ${hrs_cat3_ub_m} ///
	& demMaleFlag == 1 	
replace valid_labHrsWorkEnumWeek = "FIFTY" if ///
	labHrsWorkWeek > ${hrs_cat3_ub_m} & labHrsWorkWeek <= ${hrs_cat4_ub_m} ///
	& demMaleFlag == 1 	
replace valid_labHrsWorkEnumWeek = "SIXTY" if ///
	labHrsWorkWeek > ${hrs_cat4_ub_m} & !missing(labHrsWorkWeek) ///
	& demMaleFlag == 1 	
	

gen valid_labHrsWorkEnum_no = .
replace valid_labHrsWorkEnum_no = 0 if valid_labHrsWorkEnumWeek == "ZERO" 
replace valid_labHrsWorkEnum_no = 20 if valid_labHrsWorkEnumWeek == "TWENTY" 
replace valid_labHrsWorkEnum_no = 30 if valid_labHrsWorkEnumWeek == "THIRTY" 
replace valid_labHrsWorkEnum_no = 37 if ///
	valid_labHrsWorkEnumWeek == "THIRTY_SEVEN" 
replace valid_labHrsWorkEnum_no = 40 if valid_labHrsWorkEnumWeek == "FORTY" 
replace valid_labHrsWorkEnum_no = 50 if valid_labHrsWorkEnumWeek == "FIFTY" 
replace valid_labHrsWorkEnum_no = 60 if valid_labHrsWorkEnumWeek == "SIXTY" 	
	
* Categorical variable 
gen valid_cat_hours = .

* Females 
replace valid_cat_hours = 1 if valid_labHrsWorkEnumWeek == "ZERO" & ///
	demMaleFlag == 0
replace valid_cat_hours = 2 if valid_labHrsWorkEnumWeek == "TWENTY" & ///
	demMaleFlag == 0
replace valid_cat_hours = 3 if valid_labHrsWorkEnumWeek == "THIRTY" & ///
	demMaleFlag == 0
replace valid_cat_hours = 4 if valid_labHrsWorkEnumWeek == "THIRTY_SEVEN" & ///
	demMaleFlag == 0
replace valid_cat_hours = 5 if valid_labHrsWorkEnumWeek == "FORTY" & ///
	demMaleFlag == 0
replace valid_cat_hours = 6 if valid_labHrsWorkEnumWeek == "FIFTY" & ///
	demMaleFlag == 0

* Males 
replace valid_cat_hours = 1 if valid_labHrsWorkEnumWeek == "ZERO" & ///
	demMaleFlag == 1
replace valid_cat_hours = 2 if valid_labHrsWorkEnumWeek == "TWENTY" & ///
	demMaleFlag == 1
replace valid_cat_hours = 3 if valid_labHrsWorkEnumWeek == "THIRTY_SEVEN" & ///
	demMaleFlag == 1
replace valid_cat_hours = 4 if valid_labHrsWorkEnumWeek == "FORTY" & ///
	demMaleFlag == 1
replace valid_cat_hours = 5 if valid_labHrsWorkEnumWeek == "FIFTY" & ///
	demMaleFlag == 1
replace valid_cat_hours = 6 if valid_labHrsWorkEnumWeek == "SIXTY" & ///
	demMaleFlag == 1	
	
	
* Hourly wage 
// obs_earnings_hourly - alternative only containing observed wages
// pred_hourly_wage - alternative containing predicted wages
gen valid_wage =  obs_earnings_hourly	
replace valid_wag	= . if obs_earnings_hourly < 0 
replace valid_wage = . if valid_wage == 0 & labC4 == 1


** INCOME (ANNUAL)
/*
Amounts of personal income stored with the IHS transformation. 
Benefit Unit level measure (gross and disposable income) are stored without the 
transformation. 

No missing observations in income amounts.
*/

* Annual individual employment gross income 
rename yplgrs_dv yEmpPersGrossMonth

sum yEmpPersGrossMonth
count if yEmpPersGrossMonth == . 

* Convert to levels 
gen yEmpPersGrossLevelMonth = sinh(yEmpPersGrossMonth) 
* Convert to annual 
gen valid_yEmpPersGrossLevelYear = yEmpPersGrossLevelMonth * 12

* Annual benefit unit gross employment income
bys year idBu: egen valid_yEmpBuGrossLevelYear = ///
	total(valid_yEmpPersGrossLevelYear)


* Annual individual capital income 
rename ypncp yCapitalPersMonth

sum yCapitalPersMonth
count if yCapitalPersMonth == . 

* Convert to levels
gen yCapitalPersLevelMonth = sinh(yCapitalPersMonth) 
* Convert to annual 
gen valid_yCapitalPersLevelYear = yCapitalPersLevelMonth * 12

* Annual benefit unit capital income
bys year idBu: egen valid_yCapitalBuLevelYear = ///
	total(valid_yCapitalPersLevelYear)
	
	
* Annual individual gross private pension income 
rename ypnoab yPensPersGrossMonth

sum yPensPersGrossMonth
count if yPensPersGrossMonth == . 

* Convert to levels
gen yPensPersGrossLevelMonth = 0
* Convert to annual 
gen valid_yPensPersGrossLevelYear = yPensPersGrossLevelMonth * 12

* Annual benefit unit gross private pension income
bys year idBu: egen valid_yPensBuGrossLevelYear = ///
	total(valid_yPensPersGrossLevelYear)
	
	
* Annual individual gross non-benefit income 
/*
rename ypnbihs_dv yNonBenPersGrossMonth

* Convert to levels
gen yNonBenPersGrossLevelMonth = sinh(yNonBenPersGrossMonth) 
* Convert to annual
gen valid_yNonBenPersGrossLevelYear = yNonBenPersGrossLevelMonth * 12
*/
egen valid_yNonBenPersGrossLevelYear = ///
	rowtotal(valid_yPensPersGrossLevelYear valid_yCapitalPersLevelYear ///
	valid_yEmpPersGrossLevelYear)

* Annual benefit unit gross non-benefit income 
bys year idBu: egen valid_yNonBenBuGrossLevelYear = ///
	total(valid_yNonBenPersGrossLevelYear)	
	
	
* Annual benefit unit gross income (level, non-benefit)
/*
Gross income is the same as non-benefit private income. 
*/
gen valid_yGrossBuLevelYear = valid_yNonBenBuGrossLevelYear

gen valid_yGrossPersLevelYear = valid_yNonBenPersGrossLevelYear

	
* Annual benefit unit disposable income (level)
rename ydisp yDispPersMonth		
* Convert to annual 
gen valid_yDispPersYear = yDispPersMonth * 12 

* Convert to benefit unit
bys year idBu: egen valid_yDispBuLevelYear = total(valid_yDispPersYear)
	
	
* Benefit unit - Net transfers 	
gen valid_net_transfers = valid_yDispBuLevelYear - valid_yNonBenBuGrossLevelYear	
	

* Equivalised disposable income per benefit unit 

* Compute equivalence scale 
* Idenifty types of children 
gen is_older_child = 1 if inrange(demAge,14,18) & (idMother < . | idFather < .)
gen is_child = 1 if demAge < 14 & (idMother < . | idFather < .)

* Sum up number in hh 
bysort idHh: egen num_older_children = total(is_older_child)
bysort idHh: egen num_children = total(is_child)

* Compute Modified OECD equivalence scale 

cap drop moecd_eq
gen moecd_eq = . 
replace moecd_eq = 1.5 if dhhtp_c4 == 1
replace moecd_eq = 0.3 * num_children + 0.5 * num_older_children + 1.5 if ///
	dhhtp_c4 == 2
replace moecd_eq = 1 if dhhtp_c4 == 3
replace moecd_eq = 0.3 * num_children + 0.5 * num_older_children + 1 if ///
	dhhtp_c4 == 4 

* Apply equivalence scale   
gen valid_yDispBuEquivYear = valid_yDispBuLevelYear / moecd_eq 

drop is_older_child is_child moecd_eq


* Restrict sample to relevant validation years 
drop if year < ${min_sim_year}
drop if year > ${max_sim_year}

	
save "$dir_data/${country}-eusilc_validation_sample.dta", replace

