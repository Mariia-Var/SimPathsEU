********************************************************************************
* MASTER DO-FILE: ALL VARIABLES RETAINED (NO DELETIONS)
********************************************************************************

* 1. PRE-PROCESSING & MISSING RECODE
* Standardizing all variables mentioned across all domains
local all_vars "dlftphm dcpen ded der dhh_owned dgn dag dagsq ydses_c5 dnc dnc02 dhe deh_c3 deh_c4 dehsp_c3 dehsp_c4 les_c3 les_c4 ypnbihs_dv dhesp dcpyy dcpagdf dhhtp_c4 lesdf_c4 drgn1 stm dcpex dcpyy_st dchpd dlltsd yptciihs_dv obs_earning lhw sprfm scedsmpl dcpyy_st"
      
recode `all_vars' (-9 = .)
replace stm = stm - 2000 if stm > 1000 // Ensure centering only happens once
replace dhe = . if dhe == 0

* 2. PANEL SETUP & SAMPLE DROPS
xtset idperson swv
sort idperson swv 
drop if dag < 15 // Baseline drop to ensure sample consistency

* 3. TIME TRANSFORMATIONS & YEAR DUMMIES
* Generating both y2011 (lowercase) and Y2011 (uppercase) to prevent breakage
forvalues y = 2011/2023 {
    local val = `y' - 2000
    gen y`y' = (stm == `val')
    gen Y`y' = (stm == `val')
}

gen Post2020 = (stm >= 20)
gen Post2020_trend = max(0, stm - 20)
gen Post2015 = (stm >= 16)
gen year_post2020 = (stm > 20) * (stm - 20)
gen y2223 = (stm == 22 | stm == 23)
gen Y2223 = y2223
gen Year_transformed = stm
gen Year_transformed_sq = stm * stm

* 4. AGE TRANSFORMATIONS, KNOTS & SPLINES
gen Dag = dag
gen Dag_sq = dagsq
gen Dag_c = dag - 23
gen Dag_c_sq = Dag_c * Dag_c
gen Dag_knot17 = max(0, dag - 17)        
gen Dag_knot23 = max(0, dag - 23)        
gen Dag_knot26 = max(0, dag - 26)
gen Dag_post25 = (dag > 25) * (dag - 25)
gen Dag_post21 = (dag > 21) * (dag - 21)
gen Dag_post18_sq = (dag > 18) * (dag - 18)^2
gen Dag_post21_sq = (dag > 21) * (dag - 21)^2
gen Dag_post25_sq = (dag > 25) * (dag - 25)^2
gen Dag_post26_sq = (dag > 26) * (dag - 26)^2
mkspline rcs = dag, cubic knots(18 21 23 26)


* 5. EDUCATION & STUDENT FLAGS
cap gen Dst = .
replace Dst = 0 if les_c3 != 2 & les_c3 != .
replace Dst = 1 if les_c3 == 2 
replace Dst = . if les_c3 == . 

gen Ded = ded
gen Ded_2 = 1 - ded
recode deh_c3 (1 = 3) (3 = 1), gen(deh_c3_recoded)

* 6. REGION DUMMIES & MACROS
tab drgn1, gen(${country}) 
rename PL5 PL10 
rename PL4 PL6
rename PL3 PL5 
rename PL2 PL4
rename PL1 PL2
global regions "i.PL4 i.PL5 i.PL6 i.PL10"

* 7. CATEGORICAL DUMMY GENERATION (The "D" prefix variables)
* Employment (les_c3 and les_c4)
tab les_c3, gen(Les_c3_)
rename Les_c3_1 Les_c3_Employed
rename Les_c3_2 Les_c3_Student
rename Les_c3_3 Les_c3_NotEmployed

tab les_c4, gen(Les_c4_)
rename Les_c4_1 Les_c4_Employed
rename Les_c4_2 Les_c4_Student
rename Les_c4_3 Les_c4_NotEmployed
rename Les_c4_4 Les_c4_Retired

* Education (deh_c3 and deh_c4)
tab deh_c3, gen(Deh_c3_)
rename Deh_c3_1 Deh_c3_High
rename Deh_c3_2 Deh_c3_Medium
rename Deh_c3_3 Deh_c3_Low

tab deh_c4, gen(Deh_c4_)
rename Deh_c4_1 Deh_c4_Na
rename Deh_c4_2 Deh_c4_High
rename Deh_c4_3 Deh_c4_Medium
rename Deh_c4_4 Deh_c4_Low

* Health (dhe)
tab dhe, gen(Dhe_)
rename Dhe_1 Dhe_Poor
rename Dhe_2 Dhe_Fair
rename Dhe_3 Dhe_Good
rename Dhe_4 Dhe_VeryGood
rename Dhe_5 Dhe_Excellent


* Spouse Health and Education
tab dhesp, gen(Dhesp_)
rename Dhesp_1 Dhesp_Poor
rename Dhesp_2 Dhesp_Fair
rename Dhesp_3 Dhesp_Good
rename Dhesp_4 Dhesp_VeryGood
rename Dhesp_5 Dhesp_Excellent

tab dehsp_c3, gen(Dehsp_c3_)
rename Dehsp_c3_1 Dehsp_c3_High
rename Dehsp_c3_2 Dehsp_c3_Medium
rename Dehsp_c3_3 Dehsp_c3_Low

tab dehsp_c4, gen(Dehsp_c4_)
rename Dehsp_c4_1 Dehsp_c4_Na
rename Dehsp_c4_2 Dehsp_c4_High
rename Dehsp_c4_3 Dehsp_c4_Medium
rename Dehsp_c4_4 Dehsp_c4_Low

* Income Quintiles & Households
tab ydses_c5, gen(Ydses_c5_Q)
tab dcpst, gen(Dcpst_)
rename Dcpst_1 Dcpst_Partnered
rename Dcpst_2 Dcpst_Single

tab lesdf_c4, gen(Lesdf_c4_)
rename Lesdf_c4_1 Lesdf_c4_BothEmployed
rename Lesdf_c4_2 Lesdf_c4_EmpSpouseNotEmp
rename Lesdf_c4_3 Lesdf_c4_NotEmpSpouseEmp
rename Lesdf_c4_4 Lesdf_c4_BothNotEmployed

tab dhhtp_c4, gen(Dhhtp_c4_)
rename Dhhtp_c4_1 Dhhtp_c4_CoupleNoChildren
rename Dhhtp_c4_2 Dhhtp_c4_CoupleChildren
rename Dhhtp_c4_3 Dhhtp_c4_SingleNoChildren
rename Dhhtp_c4_4 Dhhtp_c4_SingleChildren

* 8. LAGS & LAGGED INTERACTIONS
* Standard Lags
gen Dnc = dnc
gen Dnc02 = dnc02
gen L1_Dnc = l.Dnc
gen Dnc_L1 = l.Dnc
gen Dnc02_L1 = l.Dnc02
gen Ded_L1 = l.ded
gen Dhe_L1 = l.dhe
gen Ydses_c5_L1 = l.ydses_c5
gen Dlltsd = dlltsd
gen Dlltsdsp = dlltsd_sp




* Generate lags
gen l_ydses_c5 = ydses_c5[_n-1] if idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1 

gen l_dhe = dhe[_n-1] if idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1 
		
gen l_les_c3 = les_c3[_n-1] if idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1 
		
gen l_dhhtp_c4 = dhhtp_c4[_n-1] if idperson == idperson[_n-1] & ///
	swv == swv[_n-1] + 1 	

tab l_dhe, gen(L_Dhe_c5_)
rename L_Dhe_c5_1 Dhe_Poor_L1
rename L_Dhe_c5_2 Dhe_Fair_L1
rename L_Dhe_c5_3 Dhe_Good_L1
rename L_Dhe_c5_4 Dhe_VeryGood_L1
rename L_Dhe_c5_5 Dhe_Excellent_L1


tab l_dhhtp_c4, gen(L_Dhhtp_c4_)
rename L_Dhhtp_c4_1 Dhhtp_c4_CoupleNoChildren_L1
rename L_Dhhtp_c4_2 Dhhtp_c4_CoupleChildren_L1
rename L_Dhhtp_c4_3 Dhhtp_c4_SingleNoChildren_L1
rename L_Dhhtp_c4_4 Dhhtp_c4_SingleChildren_L1


* Categorical Lags (Specifically used in your scripts)
gen Deh_c4_Na_L1 = l.Deh_c4_Na
gen Deh_c4_High_L1 = l.Deh_c4_High
gen Deh_c4_Medium_L1 = l.Deh_c4_Medium
gen Deh_c4_Low_L1 = l.Deh_c4_Low
gen Ydses_c5_Q2_L1 = l.Ydses_c5_Q2
gen Ydses_c5_Q3_L1 = l.Ydses_c5_Q3
gen Ydses_c5_Q4_L1 = l.Ydses_c5_Q4
gen Ydses_c5_Q5_L1 = l.Ydses_c5_Q5

* 9. INTERACTIONS
gen Dgn = dgn
gen Dgn_Les_c4_Student = Dgn * Les_c4_Student
gen Dgn_Les_c4_NotEmployed = Dgn * Les_c4_NotEmployed
gen Dgn_Les_c4_Retired = Dgn * Les_c4_Retired
gen Les_c4_Student_Dgn = Dgn * Les_c4_Student
gen Les_c4_NotEmployed_Dgn = Dgn * Les_c4_NotEmployed
gen Les_c4_Retired_Dgn = Dgn * Les_c4_Retired

gen Ded_Dag = Ded * Dag 
gen Ded_Dag_sq = Ded * Dag_sq 
gen Ded_Dgn = Ded * Dgn
gen Ded_Dnc_L1 = Ded * l.Dnc
gen Ded_Dnc02_L1 = Ded * l.Dnc02
gen Ded_Dcpst_Single = Dcpst_Single * Ded
gen Ded_Dcpst_Single_L1 = l.Dcpst_Single * Ded

* Education + Health/Spouse Interactions
gen Ded_Dhe_Fair_L1 = l.Dhe_Fair * Ded
gen Ded_Dhe_Good_L1 = l.Dhe_Good * Ded
gen Ded_Dhe_VeryGood_L1 = l.Dhe_VeryGood * Ded
gen Ded_Dhe_Excellent_L1 = l.Dhe_Excellent * Ded
gen Ded_Dhesp_Good_L1 = l.Dhesp_Good * Ded
gen Ded_Dhesp_Fair_L1 = l.Dhesp_Fair * Ded

* 10. DOMAIN SPECIFIC LOGIC
* Fertility
replace dchpd = 1 if dchpd >= 1 & dchpd <= 5

* Retirement
gen lesnr_c2 = (les_c4 == 1) if les_c4 != .
replace lesnr_c2 = 1 if inrange(les_c4, 2, 3)
gen Reached_Retirement_Age = dagpns
gen Elig_pen = dagpns_y
gen Elig_pen_L1 = dagpns_y1
gen Reached_Retirement_Age_Sp = dagpns_sp
gen Elig_pen_Sp = dagpns_y_sp
gen Elig_pen_L1_Sp = dagpns_y1_sp
cap gen Reached_Retirement_Age_Les = Reached_Retirement_Age * l.lesnr_c2

* Housing & Wages
egen tag_bu_wave = tag(idbenefitunit swv)
gsort idbenefitunit swv -ypnbihs_dv -dag idperson 
bysort idbenefitunit swv: gen benunit_head = (_n == 1)

gen Dcpyy = dcpyy_st
gen Dcpagdf = dcpagdf
gen Ypnbihs_dv = ypnbihs_dv
gen Ynbcpdf_dv = ynbcpdf_dv
gen Yptciihs_dv = yptciihs_dv
gen Dhh_owned = dhh_owned

cap merge m:1 stm using "$dir_data/growth_rates", keep(3) nogen keepusing(real_wage_growth)
gen hours = cond(lhw > 0 & lhw < ., lhw, 0)

* 11. LABELING
label def jbf_lbl 1 "Employed" 2 "Student" 3 "Not Employed" 4 "Retired"
label val les_c3 les_c4 lessp_c3 jbf_lbl
label var hours "Hours worked"

********************************************************************************
* END OF FILE
********************************************************************************