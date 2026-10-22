**************************************************************************
* 			Project: Simpaths EU 
*			Labour supply estimation for couples 
************************************************************************
/*
// @@@ SPECIFICATION @@@
Consumption-leisure preferences using a quadratic utility function. 
One model for couples 
*/

global file_log="${log}/couples_elast-std-simple"

*Housekeeping
capture log close

log using "$file_log", replace
cd "$local_data"

*=======================================================================
*           estimate hours of work for couples with female and male partners
*   Note: it is fine to use temp_idorigperson2 to be the couple's identifier 
*         as this is cross-sectional data and the partner does not vary
*=======================================================================
use couples_wage$impmethod, clear

*=======================================================================
* Variables used in estimation
*=======================================================================
#delimit ;

global vars
    hhcon_100
    hhcon2_10000
    leisure
    leisure2
    sp_leisure
    sp_leisure2
    lei_sp_lei
    full_fixed_cost
    sp_full_fixed_cost
    lei_age_100
    lei_age2_10000
    sp_lei_age_100
    sp_lei_age2_10000
    lei_temp_d_ch2
    sp_lei_temp_d_ch2
;

global casevars
    temp_d_deh_H
    sp_temp_d_deh_H
;

#delimit cr
//temp_d_deh_Msp_temp_d_deh_M
*=======================================================================
* Estimate
*=======================================================================

asclogit temp_choicehh $vars, case(temp_idorigperson2) alt(temp_seq) casevars($casevars) iterate(100) nocons

*=======================================================================
*                    EIGENVALUE STABILITY CHECK
*=======================================================================

matrix V_eig = e(V)
matrix symeigen EigVec EigVal = V_eig

scalar max_eig = EigVal[1,1]
scalar min_eig = EigVal[1,colsof(EigVal)]

display "Max eigenvalue = " %12.6g max_eig
display "Min eigenvalue = " %12.6g min_eig

if (max_eig < 1e-12) {
    display as error "CRITICAL ERROR: asclogit VCV near singular"
    display as error "Max eigenvalue = " %12.6g max_eig
    exit 999
}

scalar min_ratio = min_eig / max_eig
display "Min/Max eigenvalue ratio = " %12.6g min_ratio

if (min_ratio < 1e-12) {
    display as error "ERROR: asclogit VCV ill-conditioned"
    display as error "Min/Max eigenvalue ratio = " %12.6g min_ratio
    exit 506
}

display "asclogit VCV stability check passed"

*=======================================================================
*                 END OF EIGENVALUE STABILITY CHECK
*=======================================================================

gen ll = (e(ll)) //gen log likelihood 

eststo couples_wage$impmethod
capture drop sample_couples
gen sample_couples=(e(sample))


version 13

//////////////////////////////
// output estimation results //
//////////////////////////////
* output labels

putexcel set "$results/reg_labourSupplyUtility_ES", sheet("Couples") modify

*=======================================================================

*=======================================================================
* Labels: rows
*=======================================================================

putexcel A1 = ("REGRESSOR")
putexcel A2 = ("IncomeDiv100")
putexcel A3 = ("IncomeSqDiv10000")
putexcel A4 = ("MaleLeisure")
putexcel A5 = ("MaleLeisureSq")
putexcel A6 = ("FemaleLeisure")
putexcel A7 = ("FemaleLeisureSq")
putexcel A8 = ("MaleLeisure_FemaleLeisure")
putexcel A9 = ("FullFixedCost_Male")
putexcel A10 = ("FullFixedCost_Female")
putexcel A11 = ("MaleLeisure_MaleAgeDiv100")
putexcel A12 = ("MaleLeisure_MaleAgeSqDiv10000")
putexcel A13 = ("FemaleLeisure_FemaleAgeDiv100")
putexcel A14 = ("FemaleLeisure_FemaleAgeSqDiv10000")
putexcel A15 = ("MaleLeisure_ChildAge2")
putexcel A16 = ("FemaleLeisure_ChildAge2")

putexcel A17 = ("eduDehC4High_Male_1")
putexcel A18 = ("eduDehC4High_Female_1")
putexcel A19 = ("eduDehC4High_Male_2")
putexcel A20 = ("eduDehC4High_Female_2")
putexcel A21 = ("eduDehC4High_Male_3")
putexcel A22 = ("eduDehC4High_Female_3")
putexcel A23 = ("eduDehC4High_Male_4")
putexcel A24 = ("eduDehC4High_Female_4")
putexcel A25 = ("eduDehC4High_Male_5")
putexcel A26 = ("eduDehC4High_Female_5")
putexcel A27 = ("eduDehC4High_Male_10")
putexcel A28 = ("eduDehC4High_Female_10")
putexcel A29 = ("eduDehC4High_Male_11")
putexcel A30 = ("eduDehC4High_Female_11")
putexcel A31 = ("eduDehC4High_Male_12")
putexcel A32 = ("eduDehC4High_Female_12")
putexcel A33 = ("eduDehC4High_Male_13")
putexcel A34 = ("eduDehC4High_Female_13")
putexcel A35 = ("eduDehC4High_Male_14")
putexcel A36 = ("eduDehC4High_Female_14")
putexcel A37 = ("eduDehC4High_Male_15")
putexcel A38 = ("eduDehC4High_Female_15")
putexcel A39 = ("eduDehC4High_Male_20")
putexcel A40 = ("eduDehC4High_Female_20")
putexcel A41 = ("eduDehC4High_Male_21")
putexcel A42 = ("eduDehC4High_Female_21")
putexcel A43 = ("eduDehC4High_Male_22")
putexcel A44 = ("eduDehC4High_Female_22")
putexcel A45 = ("eduDehC4High_Male_23")
putexcel A46 = ("eduDehC4High_Female_23")
putexcel A47 = ("eduDehC4High_Male_24")
putexcel A48 = ("eduDehC4High_Female_24")
putexcel A49 = ("eduDehC4High_Male_25")
putexcel A50 = ("eduDehC4High_Female_25")
putexcel A51 = ("eduDehC4High_Male_30")
putexcel A52 = ("eduDehC4High_Female_30")
putexcel A53 = ("eduDehC4High_Male_31")
putexcel A54 = ("eduDehC4High_Female_31")
putexcel A55 = ("eduDehC4High_Male_32")
putexcel A56 = ("eduDehC4High_Female_32")
putexcel A57 = ("eduDehC4High_Male_33")
putexcel A58 = ("eduDehC4High_Female_33")
putexcel A59 = ("eduDehC4High_Male_34")
putexcel A60 = ("eduDehC4High_Female_34")
putexcel A61 = ("eduDehC4High_Male_35")
putexcel A62 = ("eduDehC4High_Female_35")
putexcel A63 = ("eduDehC4High_Male_40")
putexcel A64 = ("eduDehC4High_Female_40")
putexcel A65 = ("eduDehC4High_Male_41")
putexcel A66 = ("eduDehC4High_Female_41")
putexcel A67 = ("eduDehC4High_Male_42")
putexcel A68 = ("eduDehC4High_Female_42")
putexcel A69 = ("eduDehC4High_Male_43")
putexcel A70 = ("eduDehC4High_Female_43")
putexcel A71 = ("eduDehC4High_Male_44")
putexcel A72 = ("eduDehC4High_Female_44")
putexcel A73 = ("eduDehC4High_Male_45")
putexcel A74 = ("eduDehC4High_Female_45")
putexcel A75 = ("eduDehC4High_Male_50")
putexcel A76 = ("eduDehC4High_Female_50")
putexcel A77 = ("eduDehC4High_Male_51")
putexcel A78 = ("eduDehC4High_Female_51")
putexcel A79 = ("eduDehC4High_Male_52")
putexcel A80 = ("eduDehC4High_Female_52")
putexcel A81 = ("eduDehC4High_Male_53")
putexcel A82 = ("eduDehC4High_Female_53")
putexcel A83 = ("eduDehC4High_Male_54")
putexcel A84 = ("eduDehC4High_Female_54")
putexcel A85 = ("eduDehC4High_Male_55")
putexcel A86 = ("eduDehC4High_Female_55")

*=======================================================================
* Labels: columns
*=======================================================================

putexcel B1 = ("COEFFICIENT")

putexcel C1 = ("IncomeDiv100")
putexcel D1 = ("IncomeSqDiv10000")
putexcel E1 = ("MaleLeisure")
putexcel F1 = ("MaleLeisureSq")
putexcel G1 = ("FemaleLeisure")
putexcel H1 = ("FemaleLeisureSq")
putexcel I1 = ("MaleLeisure_FemaleLeisure")
putexcel J1 = ("FullFixedCost_Male")
putexcel K1 = ("FullFixedCost_Female")
putexcel L1 = ("MaleLeisure_MaleAgeDiv100")
putexcel M1 = ("MaleLeisure_MaleAgeSqDiv10000")
putexcel N1 = ("FemaleLeisure_FemaleAgeDiv100")
putexcel O1 = ("FemaleLeisure_FemaleAgeSqDiv10000")
putexcel P1 = ("MaleLeisure_ChildAge2")
putexcel Q1 = ("FemaleLeisure_ChildAge2")

putexcel R1 = ("eduDehC4High_Male_1")
putexcel S1 = ("eduDehC4High_Female_1")
putexcel T1 = ("eduDehC4High_Male_2")
putexcel U1 = ("eduDehC4High_Female_2")
putexcel V1 = ("eduDehC4High_Male_3")
putexcel W1 = ("eduDehC4High_Female_3")
putexcel X1 = ("eduDehC4High_Male_4")
putexcel Y1 = ("eduDehC4High_Female_4")
putexcel Z1 = ("eduDehC4High_Male_5")
putexcel AA1 = ("eduDehC4High_Female_5")
putexcel AB1 = ("eduDehC4High_Male_10")
putexcel AC1 = ("eduDehC4High_Female_10")
putexcel AD1 = ("eduDehC4High_Male_11")
putexcel AE1 = ("eduDehC4High_Female_11")
putexcel AF1 = ("eduDehC4High_Male_12")
putexcel AG1 = ("eduDehC4High_Female_12")
putexcel AH1 = ("eduDehC4High_Male_13")
putexcel AI1 = ("eduDehC4High_Female_13")
putexcel AJ1 = ("eduDehC4High_Male_14")
putexcel AK1 = ("eduDehC4High_Female_14")
putexcel AL1 = ("eduDehC4High_Male_15")
putexcel AM1 = ("eduDehC4High_Female_15")
putexcel AN1 = ("eduDehC4High_Male_20")
putexcel AO1 = ("eduDehC4High_Female_20")
putexcel AP1 = ("eduDehC4High_Male_21")
putexcel AQ1 = ("eduDehC4High_Female_21")
putexcel AR1 = ("eduDehC4High_Male_22")
putexcel AS1 = ("eduDehC4High_Female_22")
putexcel AT1 = ("eduDehC4High_Male_23")
putexcel AU1 = ("eduDehC4High_Female_23")
putexcel AV1 = ("eduDehC4High_Male_24")
putexcel AW1 = ("eduDehC4High_Female_24")
putexcel AX1 = ("eduDehC4High_Male_25")
putexcel AY1 = ("eduDehC4High_Female_25")
putexcel AZ1 = ("eduDehC4High_Male_30")
putexcel BA1 = ("eduDehC4High_Female_30")
putexcel BB1 = ("eduDehC4High_Male_31")
putexcel BC1 = ("eduDehC4High_Female_31")
putexcel BD1 = ("eduDehC4High_Male_32")
putexcel BE1 = ("eduDehC4High_Female_32")
putexcel BF1 = ("eduDehC4High_Male_33")
putexcel BG1 = ("eduDehC4High_Female_33")
putexcel BH1 = ("eduDehC4High_Male_34")
putexcel BI1 = ("eduDehC4High_Female_34")
putexcel BJ1 = ("eduDehC4High_Male_35")
putexcel BK1 = ("eduDehC4High_Female_35")
putexcel BL1 = ("eduDehC4High_Male_40")
putexcel BM1 = ("eduDehC4High_Female_40")
putexcel BN1 = ("eduDehC4High_Male_41")
putexcel BO1 = ("eduDehC4High_Female_41")
putexcel BP1 = ("eduDehC4High_Male_42")
putexcel BQ1 = ("eduDehC4High_Female_42")
putexcel BR1 = ("eduDehC4High_Male_43")
putexcel BS1 = ("eduDehC4High_Female_43")
putexcel BT1 = ("eduDehC4High_Male_44")
putexcel BU1 = ("eduDehC4High_Female_44")
putexcel BV1 = ("eduDehC4High_Male_45")
putexcel BW1 = ("eduDehC4High_Female_45")
putexcel BX1 = ("eduDehC4High_Male_50")
putexcel BY1 = ("eduDehC4High_Female_50")
putexcel BZ1 = ("eduDehC4High_Male_51")
putexcel CA1 = ("eduDehC4High_Female_51")
putexcel CB1 = ("eduDehC4High_Male_52")
putexcel CC1 = ("eduDehC4High_Female_52")
putexcel CD1 = ("eduDehC4High_Male_53")
putexcel CE1 = ("eduDehC4High_Female_53")
putexcel CF1 = ("eduDehC4High_Male_54")
putexcel CG1 = ("eduDehC4High_Female_54")
putexcel CH1 = ("eduDehC4High_Male_55")
putexcel CI1 = ("eduDehC4High_Female_55")

*=======================================================================


* output coefficients 
matrix results = r(table)
matrix results = results[1..6,1...]'   //extract the first six rows of results, and then transpose results
putexcel B2 = matrix(results /*, names*/ ) //names nformat(number_d2)  //write in Excel from cell B2 

* output variance-covariance matrix 
matrix results=e(V)
putexcel C2 = matrix(results /*, names*/ ) //names nformat(number_d2)  //write e(V) in Excel from cell C2 


******************
*Predict choices *
******************

*predictions from the model, we store epsilons required for counterfactuals and predicted probabilities
predict double pred_prob 											//predicted probabilities (deterministic)
predict double pred_utility , xb										//deterministic component of utility
sum pred_utility 


/*
*method 1 															
*the highest deterministic utility is chosen
bys temp_idorigperson2: egen double max_utility1=max(pred_utility)		//for each agent var with highest utility 
gen pred_choicehh1=(max_utility1==pred_utility)						//dummy for predicted choices

gen pred_lhw1=lhw if pred_choicehh1==1									//male predicted hours of work pred_lhw
gen pred_sp_lhw1=sp_lhw if pred_choicehh1==1									//female predicted hours of work pred_lhw

bys temp_idorigperson2: egen temp_pred_lhw1=total(pred_lhw1)				//expand pred_lhw to all alternatives
replace pred_lhw1=temp_pred_lhw1									//expand pred_lhw to all alternatives

bys temp_idorigperson2: egen temp_pred_sp_lhw1=total(pred_sp_lhw1)				//expand pred_sp_lhw to all alternatives
replace pred_sp_lhw1=temp_pred_sp_lhw1									//expand pred_sp_lhw to all alternatives
*/

*method 2

*the highest utility=deterministic+stochastic is chosen

set seed 339487731
gen double epsilon2= -log(-log(runiform()))	 						//random draw from an extreme value distribution (required for counterfactual)
gen double pred_utility2= pred_utility+epsilon2 					//utility=deterministic utility+stochastic utility
bys temp_idorigperson2: egen double max_utility2=max(pred_utility2) 		//for each agent highest utility 
gen pred_choicehh2=(max_utility2==pred_utility2) 					//dummy for predicted choices

gen pred_lhw2=lhw if pred_choicehh2==1							//male predicted hours of work
gen pred_sp_lhw2=sp_lhw if pred_choicehh2==1							//female predicted hours of work

bys temp_idorigperson2: egen temp_pred_lhw2=total(pred_lhw2) 				//expand pred_lhw2 to all alternatives
replace pred_lhw2=temp_pred_lhw2 								//expand pred_lhw2 to all alternatives

bys temp_idorigperson2: egen temp_pred_sp_lhw2=total(pred_sp_lhw2) 				//expand pred_sp_lhw2 to all alternatives
replace pred_sp_lhw2=temp_pred_sp_lhw2 								//expand pred_sp_lhw2 to all alternatives


**hours fit (histograms for two genders with 2 utility prediction methods)


*foreach j in 1 2{ //loop begin for utility prediction method 

/////////////////////////////////
///hours fit graph (histogram) //
/////////////////////////////////
twoway (histogram temp_hh_alt if temp_choicehh==1, ///
        xlabel(${graph_couples}, noticks angle(45)) ///
        percent width(0.8) color(green)) ///
       (histogram temp_hh_alt if pred_choicehh2==1, ///
        percent width(0.8) fcolor(none) lcolor(black)), ///
       legend(order(1 "observed" 2 "predicted")) ///
       subtitle("Couples, both LS flexible") ///
       note("(women hours, men hours)")

	
graph save "$results_ls/couples/his_hoursfit.gph", replace		   
graph export "$results_ls/couples/his_hoursfit_couples.png", as(png) replace



*}  //loop end for utility prediction method

*method 1
//tab pred_lhw1 lhw if temp_choicehh==1 , m  //hours fit confusion matrix
//tab pred_sp_lhw1 sp_lhw if temp_choicehh==1 , m  //hours fit confusion matrix

*method 2	
//tab pred_lhw2 lhw if temp_choicehh==1 , m  //hours fit confusion matrix
//tab pred_sp_lhw2 sp_lhw if temp_choicehh==1 , m  //hours fit confusion matrix


sum ils_dispy hhcon
//save temp_file2_wage2.dta, replace

///////////////////////////////////////
//export estimation results to Excel //
///////////////////////////////////////
//capture erase couples_lslogit.csv
//esttab  couples_wage1 using couples_clogit.csv, replace label cells(b(star fmt(a3)) t(par fmt(2)))
esttab  couples_wage$impmethod using "$results_ls/couples/ls_couples.tex", replace label cells(b(star fmt(3))) stats(ll r2_p N ) nonumbers  ///
collabels(none) ///
title(Labour supply (utility function) estimation: Couples. ///
		Notes: Income in hundreds of Euros. ///
\label{tab:hours-couples}) ///
varlabels(r2_p pseudo-R^2) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing tex including female and male(including at least three non-zero digits)


esttab  couples_wage$impmethod using "$results_ls/couples/ls_couples.csv", replace label cells(b(star fmt(3))) stats(ll r2_p N ) nonumbers  ///
collabels(none) ///
title(Labour supply (utility function) estimation: Couples. ///
		Notes: Income in hundreds of Euros. ///
\label{tab:hours-couples}) ///
varlabels(r2_p pseudo-R^2) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing csv including female and male(including at least three non-zero digits)
/////////////////////////////////////////////

*********************
*Marginal utilities *
*********************
capture drop dU_c
capture drop dU_lei*
capture drop dU2_c
capture drop dU2_lei*

			*-----------------------------------------------------------------
			* First differential of utility w.r.t. disposable income
			*-----------------------------------------------------------------
			gen dU_c=_b[hhcon_100] +2*hhcon_100*_b[hhcon2_10000] /*+leisure*_b[lei_hhcon_100] +sp_leisure*_b[sp_lei_hhcon_100] */ 
            su dU_c if temp_choicehh==1 &e(sample)
			
			
			*-----------------------------------------------------------------
			* Second differential of utility w.r.t. disposable income
			*-----------------------------------------------------------------
            gen dU2_c=2*_b[hhcon2_10000]
			su dU2_c if temp_choicehh==1 &e(sample)

			*-----------------------------------------------------------------
			* First differential of utility w.r.t. leisure of male partner
			*-----------------------------------------------------------------
			gen double dU_lei_male    =_b[leisure]  +2*leisure   *_b[leisure2]  /*+hhcon_100*_b[lei_hhcon_100] */ ///
			+age_100*_b[lei_age_100] +age2_10000*_b[lei_age2_10000] ///
			/*+ temp_n_ch*_b[lei_temp_n_ch]*/  + temp_d_ch2*_b[lei_temp_d_ch2]
			su dU_lei_male if temp_choicehh==1 &e(sample)	
			
			*-----------------------------------------------------------------
			* Second differential of utility w.r.t. leisure of male partner
			*-----------------------------------------------------------------
		    gen dU2_lei_male=2*_b[leisure2]
			su dU2_lei_male if temp_choicehh==1 &e(sample)
			
			
			*-----------------------------------------------------------------
			* First differential of utility w.r.t. leisure of female partner
			*-----------------------------------------------------------------
			gen double   dU_lei_female=_b[sp_leisure]+2*sp_leisure*_b[sp_leisure2] /*+hhcon_100*_b[sp_lei_hhcon_100] */ ///
			+sp_age_100*_b[sp_lei_age_100] +sp_age2_10000*_b[sp_lei_age2_10000] ///
			/*+ temp_n_ch*_b[sp_lei_temp_n_ch]*/  + temp_d_ch2*_b[sp_lei_temp_d_ch2] 
			su dU_lei_female if temp_choicehh==1 &e(sample)
			
			*-----------------------------------------------------------------
			* Second differential of utility w.r.t. leisure of female partner
			*-----------------------------------------------------------------
		    gen dU2_lei_female=2*_b[sp_leisure2]
			su dU2_lei_female if temp_choicehh==1 &e(sample)


*version 13

*export estimation results to tex
//capture erase couples_lslogit.tex
esttab  couples_wage$impmethod using "$results_ls/couples/couples_clogit.tex", replace label cells(b(star fmt(a3)) t(par fmt(2)))


****************
*Elasticities  *
****************
*the highest utility=deterministic+stochastic is chosen
//firstly, append simulated hhcon resulting from an 10% increase of male partners' gross wage
append using "$local_data\sim_couples_110male_output_wage$impmethod"   //get ils_dispy and hhcon resulting from 10% increase of male partners' gross wage
append using "$local_data\sim_couples_110female_output_wage$impmethod"   //get sp_ils_dispy and hhcon resulting from 10% increase of female partners' gross wage
fre sim_flag 


capture drop pred_prob
capture drop de_pred_utility
predict double pred_prob if  sim_flag==0										//predicted probabilities (deterministic)
predict double de_pred_utility if  sim_flag==0, xb										//deterministic component of utility
sum de_pred_utility if  sim_flag==0
//v15 update
//combine the following gender loop with those below
foreach gender in 0 1{  //predict for simulated data, loop begin for gender (for own wage, cross wage elast)
capture drop pred_prob_`gender'wage
capture drop de_pred_utility_`gender'wage
predict double pred_prob_`gender'wage if  sim_flag==1`gender'										//predicted probabilities (deterministic)
predict double de_pred_utility_`gender'wage if  sim_flag==1`gender', xb										//for simulated hhcon, deterministic component of utility
su de_pred_utility_`gender'wage if  sim_flag==1`gender'
//}

capture drop part_0* 
capture drop part_1* 
capture drop sim_part_*
capture drop in_*
capture drop out_*

set seed 339487731
//v15 update: loop for random draw
//add loop beginning
capture drop hrs_elas_`gender'wage*
capture drop sp_hrs_elas_`gender'wage*
capture drop mean_hrs_elas_`gender'wage
capture drop mean_sp_hrs_elas_`gender'wage

forvalues i = 1/$n_draws {
capture drop epsilon 
capture drop pred_utility
capture drop max_utility
capture drop pred_lhw
capture drop pred_sp_lhw
capture drop temp_pred_lhw
capture drop temp_pred_sp_lhw
*capture drop hrs_elas_`gender'wage_`i'
*capture drop sp_hrs_elas_`gender'wage_`i'

gen double epsilon= -log(-log(runiform()))	 						//random draw from an extreme value distribution (required for counterfactual)
gen double pred_utility= de_pred_utility+epsilon 	if sim_flag==0				//utility=deterministic utility+stochastic utility
//BUG! varlist not allowed
bys temp_idorigperson2: egen double max_utility=max(pred_utility) if sim_flag==0	//for each hh highest utility 
//gen pred_choice2_`gender'=(max_utility2_`gender'==pred_utility2_`gender') 						//dummy for predicted choices
//gen pred_lhw2_`gender'=lhw if pred_choice2_`gender'==1& dgn==`gender'							//predicted hours of work
gen pred_lhw=lhw if max_utility==pred_utility	& sim_flag==0 & pred_utility!=.					//predicted male partners' hours of work (only present in the chosen row)
gen pred_sp_lhw=sp_lhw if max_utility==pred_utility	& sim_flag==0 & pred_utility!=.						//predicted female partners' hours of work (only present in the chosen row)

//replace pred_lhw=0 if pred_lhw==.
//replace pred_sp_lhw=0 if pred_sp_lhw==.

bys temp_idorigperson2: egen temp_pred_lhw=total(pred_lhw) , missing				//expand pred_lhw to all alternatives (missing as 0)
bys temp_idorigperson2: egen temp_pred_sp_lhw=total(pred_sp_lhw) , missing				//expand pred_sp_lhw to all alternatives (missing as 0)

*replace pred_lhw_0=temp_pred_lhw_0 	& pred_lhw_0==.								//expand pred_lhw to all alternatives

capture drop pred_utility_`gender'wage
capture drop max_utility_`gender'wage
capture drop pred_lhw_`gender'wage
capture drop temp_pred_lhw_`gender'wage
capture drop pred_sp_lhw_`gender'wage
capture drop temp_pred_sp_lhw_`gender'wage

//v15 update: predict optimal hours for sim_hhcon
gen double pred_utility_`gender'wage= de_pred_utility_`gender'wage+epsilon 	if sim_flag==1`gender'				//utility=deterministic utility+stochastic utility
bys temp_idorigperson2: egen double max_utility_`gender'wage=max(pred_utility_`gender'wage) if sim_flag==1`gender'	//for each agent highest utility 
//gen pred_choice2_`gender'=(max_utility2_`gender'==pred_utility2_`gender') 						//dummy for predicted choices
//gen pred_lhw2_`gender'=lhw if pred_choice2_`gender'==1& dgn==`gender'							//predicted hours of work
gen pred_lhw_`gender'wage=lhw if max_utility_`gender'wage==pred_utility_`gender'wage &  sim_flag==1`gender'	& pred_utility_`gender'wage!=.						//predicted hours of work (only present in the chosen row)
gen pred_sp_lhw_`gender'wage=sp_lhw if max_utility_`gender'wage==pred_utility_`gender'wage &  sim_flag==1`gender' & pred_utility_`gender'wage!=.							//predicted hours of work (only present in the chosen row)

bys temp_idorigperson2: egen temp_pred_lhw_`gender'wage=total(pred_lhw_`gender'wage) , missing				//expand pred_lhw to all alternatives (missing as 0)
bys temp_idorigperson2: egen temp_pred_sp_lhw_`gender'wage=total(pred_sp_lhw_`gender'wage) , missing				//expand pred_lhw to all alternatives (missing as 0)

*elasticity
gen hrs_elas_`gender'wage_`i'=10*(temp_pred_lhw_`gender'wage-temp_pred_lhw)/temp_pred_lhw if  temp_choicehh==1
gen sp_hrs_elas_`gender'wage_`i'=10*(temp_pred_sp_lhw_`gender'wage-temp_pred_sp_lhw)/temp_pred_sp_lhw if  temp_choicehh==1
//male partner participation
gen part_`gender'wage_`i'=(temp_pred_lhw>0) if  temp_choicehh==1  //dummy of participation (positive working hours) 
gen sim_part_`gender'wage_`i'=(temp_pred_lhw_`gender'wage>0) if  temp_choicehh==1  //simulated dummy of participation (positive working hours)
gen in_`gender'wage_`i'= (sim_part_`gender'wage_`i'-part_`gender'wage_`i'==1) if  temp_choicehh==1  //dummy of switching from 0 hrs to positive hrs due to an increase of gross wage
drop sim_part_`gender'wage_`i' part_`gender'wage_`i'  //save space for Stata
//gen out_`gender'wage_`i'= (sim_part_`gender'wage_`i'-part_`gender'wage_`i'==-1) if  temp_choicehh==1  //dummy of switching from positive hrs to 0 hrs due to an increase of gross wage

//female partner participation
gen sp_part_`gender'wage_`i'=(temp_pred_sp_lhw>0) if  temp_choicehh==1  //dummy of participation (positive working hours) 
gen sp_sim_part_`gender'wage_`i'=(temp_pred_sp_lhw_`gender'wage>0) if  temp_choicehh==1  //simulated dummy of participation (positive working hours)
gen sp_in_`gender'wage_`i'= (sp_sim_part_`gender'wage_`i'-sp_part_`gender'wage_`i'==1) if  temp_choicehh==1  //dummy of switching from 0 hrs to positive hrs due to an increase of gross wage
drop sp_sim_part_`gender'wage_`i' sp_part_`gender'wage_`i'  //save space for Stata
//gen sp_out_`gender'wage_`i'= (sp_sim_part_`gender'wage_`i'-sp_part_`gender'wage_`i'==-1) if  temp_choicehh==1  //dummy of switching from positive hrs to 0 hrs due to an increase of gross wage

}  //loop end for random draw

*Elastisities 
order hrs_elas_`gender'wage_*, last 
egen mean_hrs_elas_`gender'wage=rmean(hrs_elas_`gender'wage_1-hrs_elas_`gender'wage_$n_draws) if  temp_choicehh==1 & sample_couples==1  // male partners' own wage and cross wage hours elasticity (for each obs)

order sp_hrs_elas_`gender'wage_*, last 
egen sp_mean_hrs_elas_`gender'wage=rmean(sp_hrs_elas_`gender'wage_1-sp_hrs_elas_`gender'wage_$n_draws) if  temp_choicehh==1 & sample_couples==1  // male partners' own wage and cross wage hours elasticity (for each obs)

su mean_hrs_elas_`gender'wage if  temp_choicehh==1 & sample_couples==1,d  //summary of ale partners' own wage and cross wage hours elasticity across observations
su sp_mean_hrs_elas_`gender'wage if  temp_choicehh==1 & sample_couples==1,d  //summary of ale partners' own wage and cross wage hours elasticity across observations

}  //loop end for gender


/////////////////////////////////////////
//graph of elasticity for both genders //
/////////////////////////////////////////
twoway (histogram mean_hrs_elas_0wage if temp_choicehh==1 & sample_couples==1 ,  color(green) ) ///
	   (histogram mean_hrs_elas_1wage if temp_choicehh==1 & sample_couples==1, ///
		    fcolor(none) lcolor(black)), legend(order(1 "female" 2 "male" )) ///
		   subtitle("Hours elasticity")
graph export "$results_ls/couples/hrs_elas_couples.png", as(png) replace



///////////////////////////////
//histogram of du/dc, du/dlei//
///////////////////////////////
histogram dU_c if temp_choicehh==1,  fcolor(none) lcolor(black) subtitle("MU wrt income for couples")
		   graph export "$results_ls/couples/dUdc_couple.png", as(png) replace

twoway (histogram dU_lei_female if temp_choicehh==1 ,  color(green) ) ///
		   (histogram dU_lei_male if dgn==1 & temp_choicehh==1, ///
		    fcolor(none) lcolor(black)), legend(order(1 "female in couple" 2 "male in couple" )) ///
		   subtitle("MU wrt leisure")
		   graph export "$results_ls/couples/dUdlei_couple.png", as(png) replace
	   
	   
su dU_c  dU_lei_female dU_lei_male if e(sample) & temp_choicehh==1
su dU2_c dU2_lei_female dU2_lei_male if e(sample) & temp_choicehh==1


///////////////////
//Income deciles //
///////////////////
xtile dec_hhcon = hhcon if sample_couples==1 &temp_choicehh==1, nq(10)  //create decile variable
//own wage elasticity by decile
graph box mean_hrs_elas_1wage sp_mean_hrs_elas_0wage if temp_choicehh==1, ytitle(own wage elasticity) over(dec_hhcon) note("Income decile" ///
"Lines indicate upper adjacent value, 75th percentile, median, 25th percentile, lower adjacent value.") ///
subtitle("Couples, both LS flexible") legend(order(1 "male partner" 2 "female partner" )) 
//graph export own_wage_elas.png, as(png) replace
graph export "$results_ls/couples/wage_elas_couples.png", as(png) replace

//cross wage elasticity by decile
graph box mean_hrs_elas_0wage sp_mean_hrs_elas_1wage, ytitle(cross wage elasticity) over(dec_hhcon) ///
subtitle("cross wage elasticity by income decile") legend(order(1 "male partner" 2 "female partner" ))
graph export "$results_ls/couples/cross_wage_elas.png", as(png) replace

		
///////////////////
///summary stats //
///////////////////
*percent of obs with posititive marginal utilities  
foreach i in dU_c  dU_lei_male dU_lei_female{
gen `i'_positive=(`i'>0)
su `i'_positive if e(sample) & temp_choicehh==1
}
*percent of obs with negative marginal utilities  
foreach i in dU_c dU_lei_male dU_lei_female  {
cap drop `i'_negative
gen `i'_negative=(`i'<0)
sum `i'_negative if sample==1 & temp_choicehh==1 
} 

/////////////////////////////////////////////		
//output to Excel file with summary stats ///
/////////////////////////////////////////////
putexcel set "${summary_table}", sheet(${sheet}) modify	   

putexcel A2=("Wage elasticities of hours of work")
putexcel A6=("Couples both LS flexible, women")
putexcel A7=("Couples both LS flexible, men")
mean mean_hrs_elas_0wage if  temp_choicehh==1 & sample_couples==1
putexcel B6=matrix(e(b)')
mean mean_hrs_elas_1wage if  temp_choicehh==1 & sample_couples==1
putexcel B7=matrix(e(b)')

putexcel A9=("% obs with negative marginal utility wrt income")
putexcel A13=("Couples both LS flexible, men and women")
mean dU_c_negative if sample==1 & temp_choicehh==1 
putexcel B13=matrix(e(b)')

putexcel A15=("% obs with negative marginal utility wrt leisure")
putexcel A19=("Couples, male partner")
putexcel A20=("Couples, female partner")
mean dU_lei_male_negative if sample==1 & temp_choicehh==1 
putexcel B19=matrix(e(b)')
mean dU_lei_female_negative if sample==1 & temp_choicehh==1 
putexcel B20=matrix(e(b)')


*log likelihood 
putexcel A22=("Log likelihood")
putexcel A26=("Couples both LS flexible, men and women")
qui mean ll if sample==1 
putexcel B26=matrix(e(b)')


//obs vs predicted wages fit 
putexcel A28=("Mean hours")

putexcel A38=("Couples both LS flexible, men")
putexcel A39=("observed")
putexcel A40=("predicted")
qui mean lhw if temp_choicehh==1
putexcel B39=matrix(e(b)')
qui mean lhw if pred_choicehh2==1
putexcel B40=matrix(e(b)')

putexcel A41=("Couples both LS flexible, women")
putexcel A42=("observed")
putexcel A43=("predicted")
qui mean sp_lhw if temp_choicehh==1
putexcel B42=matrix(e(b)')
qui mean sp_lhw if pred_choicehh2==1
putexcel B43=matrix(e(b)')


log close


