************************************************************************
* 			Project: Simpaths EU 
*			Labour supply estimation for dependent singles 
************************************************************************
/*
// @@@ SPECIFICATION @@@
Consumption-leisure preferences using a quadratic utility function with fixed costs. 
Combined model for men and women with gender introduced via interaction 
*/

global file_log="${log}/singles_indep_elast-std-simple"

cd "$local_data"

*Housekeeping
capture log close
*office PC

log using "$file_log", replace
pwd
clear all
set seed 1																//same seed gives same results	

*version 15

*=======================================================================
*           estimate hours of work for female and male, respectively
*=======================================================================
//use wage 1 only because MU is better                       
use singles_dep_wage$impmethod, clear
//foreach gender in 0 1{ //loop begin for gender
capture drop temp_pred_lhw1
capture drop pred_prob
capture drop pred_utility
capture drop pred_utility2
capture drop max_utility2
capture drop pred_choice2
capture drop pred_lhw2
capture drop temp_pred_lhw2
capture drop epsilon2

capture drop pred_choice1
capture drop pred_utility1
capture drop max_utility1
capture drop pred_choice1
capture drop pred_lhw1
capture drop temp_pred_lhw1


drop if sim_flag==1  //make sure the data is actual at this point


global vars "hhcon_100  hhcon2_10000 leisure leisure2  full_fixc_dgn  lei_age_100 lei_age2_10000" // adding fixed_cost#gender dummypart_fixc_dgnlei_hhcon_100
****************************************************************************************************************
//clogit temp_choicehh `vars_simple', group (temp_idorigperson2) //estimate only on actual data (sim_flag==0)
asclogit temp_choicehh  ${vars}, case(temp_idorigperson2) alt(temp_seq) casevars(liwwh temp_dhe3_2 temp_dhe3_3 /*ln_liwwh liwwh2*/ )  iterate(100) nocons 
****************************************************************************************************************

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

gen ll = (e(ll)) //gen log likelyhood 

eststo singles_wage$impmethod
gen sample=(e(sample))
version 13

foreach gender in 0 1 { // loop begin for gender
//////////////////////////////////////
// output estimated results to Excel //
//////////////////////////////////////
* output labels 
if (`gender' == 0) {
    putexcel set "$results/reg_labourSupplyUtility_ES", sheet("SingleDep_Females") modify

putexcel A1 = ("REGRESSOR")
putexcel A2 = ("IncomeDiv100")
putexcel A3 = ("IncomeSqDiv10000")
putexcel A4 = ("FemaleLeisure")
putexcel A5 = ("FemaleLeisureSq")
putexcel A6 = ("FullFixedCost_Male")
putexcel A7 = ("FemaleLeisure_FemaleAgeDiv100")
putexcel A8 = ("FemaleLeisure_FemaleAgeSqDiv10000")
putexcel A9  = ("Liwwh_1")
putexcel A10 = ("HealthSelfRatedGood_1")
putexcel A11 = ("HealthSelfRatedVeryGoodExcel_1")
putexcel A12 = ("Liwwh_2")
putexcel A13 = ("HealthSelfRatedGood_2")
putexcel A14 = ("HealthSelfRatedVeryGoodExcel_2")
putexcel A15 = ("Liwwh_3")
putexcel A16 = ("HealthSelfRatedGood_3")
putexcel A17 = ("HealthSelfRatedVeryGoodExcel_3")
putexcel A18 = ("Liwwh_4")
putexcel A19 = ("HealthSelfRatedGood_4")
putexcel A20 = ("HealthSelfRatedVeryGoodExcel_4")
putexcel A21 = ("Liwwh_5")
putexcel A22 = ("HealthSelfRatedGood_5")
putexcel A23 = ("HealthSelfRatedVeryGoodExcel_5")
putexcel A24 = ("Liwwh_10")
putexcel A25 = ("HealthSelfRatedGood_10")
putexcel A26 = ("HealthSelfRatedVeryGoodExcel_10")
putexcel A27 = ("Liwwh_20")
putexcel A28 = ("HealthSelfRatedGood_20")
putexcel A29 = ("HealthSelfRatedVeryGoodExcel_20")
putexcel A30 = ("Liwwh_30")
putexcel A31 = ("HealthSelfRatedGood_30")
putexcel A32 = ("HealthSelfRatedVeryGoodExcel_30")
putexcel A33 = ("Liwwh_40")
putexcel A34 = ("HealthSelfRatedGood_40")
putexcel A35 = ("HealthSelfRatedVeryGoodExcel_40")
putexcel A36 = ("Liwwh_50")
putexcel A37 = ("HealthSelfRatedGood_50")
putexcel A38 = ("HealthSelfRatedVeryGoodExcel_50")

putexcel B1 = ("COEFFICIENT")
putexcel C1 = ("IncomeDiv100")
putexcel D1 = ("IncomeSqDiv10000")
putexcel E1 = ("FemaleLeisure")
putexcel F1 = ("FemaleLeisureSq")
putexcel G1 = ("FullFixedCost_Male")
putexcel H1 = ("FemaleLeisure_FemaleAgeDiv100")
putexcel I1 = ("FemaleLeisure_FemaleAgeSqDiv10000")
putexcel J1 = ("Liwwh_1")
putexcel K1 = ("HealthSelfRatedGood_1")
putexcel L1 = ("HealthSelfRatedVeryGoodExcel_1")
putexcel M1 = ("Liwwh_2")
putexcel N1 = ("HealthSelfRatedGood_2")
putexcel O1 = ("HealthSelfRatedVeryGoodExcel_2")
putexcel P1 = ("Liwwh_3")
putexcel Q1 = ("HealthSelfRatedGood_3")
putexcel R1 = ("HealthSelfRatedVeryGoodExcel_3")
putexcel S1 = ("Liwwh_4")
putexcel T1 = ("HealthSelfRatedGood_4")
putexcel U1 = ("HealthSelfRatedVeryGoodExcel_4")
putexcel V1 = ("Liwwh_5")
putexcel W1 = ("HealthSelfRatedGood_5")
putexcel X1 = ("HealthSelfRatedVeryGoodExcel_5")
putexcel Y1 = ("Liwwh_10")
putexcel Z1 = ("HealthSelfRatedGood_10")
putexcel AA1 = ("HealthSelfRatedVeryGoodExcel_10")
putexcel AB1 = ("Liwwh_20")
putexcel AC1 = ("HealthSelfRatedGood_20")
putexcel AD1 = ("HealthSelfRatedVeryGoodExcel_20")
putexcel AE1 = ("Liwwh_30")
putexcel AF1 = ("HealthSelfRatedGood_30")
putexcel AG1 = ("HealthSelfRatedVeryGoodExcel_30")
putexcel AH1 = ("Liwwh_40")
putexcel AI1 = ("HealthSelfRatedGood_40")
putexcel AJ1 = ("HealthSelfRatedVeryGoodExcel_40")
putexcel AK1 = ("Liwwh_50")
putexcel AL1 = ("HealthSelfRatedGood_50")
putexcel AM1 = ("HealthSelfRatedVeryGoodExcel_50")
}

else {
    putexcel set "$results/reg_labourSupplyUtility_ES", sheet("SingleDep_Males") modify

putexcel A1 = ("REGRESSOR")
putexcel A2 = ("IncomeDiv100")
putexcel A3 = ("IncomeSqDiv10000")
putexcel A4 = ("MaleLeisure")
putexcel A5 = ("MaleLeisureSq")
putexcel A6 = ("FullFixedCost_Male")
putexcel A7 = ("MaleLeisure_MaleAgeDiv100")
putexcel A8 = ("MaleLeisure_MaleAgeSqDiv10000")
putexcel A9  = ("Liwwh_1")
putexcel A10 = ("HealthSelfRatedGood_1")
putexcel A11 = ("HealthSelfRatedVeryGoodExcel_1")
putexcel A12 = ("Liwwh_2")
putexcel A13 = ("HealthSelfRatedGood_2")
putexcel A14 = ("HealthSelfRatedVeryGoodExcel_2")
putexcel A15 = ("Liwwh_3")
putexcel A16 = ("HealthSelfRatedGood_3")
putexcel A17 = ("HealthSelfRatedVeryGoodExcel_3")
putexcel A18 = ("Liwwh_4")
putexcel A19 = ("HealthSelfRatedGood_4")
putexcel A20 = ("HealthSelfRatedVeryGoodExcel_4")
putexcel A21 = ("Liwwh_5")
putexcel A22 = ("HealthSelfRatedGood_5")
putexcel A23 = ("HealthSelfRatedVeryGoodExcel_5")
putexcel A24 = ("Liwwh_10")
putexcel A25 = ("HealthSelfRatedGood_10")
putexcel A26 = ("HealthSelfRatedVeryGoodExcel_10")
putexcel A27 = ("Liwwh_20")
putexcel A28 = ("HealthSelfRatedGood_20")
putexcel A29 = ("HealthSelfRatedVeryGoodExcel_20")
putexcel A30 = ("Liwwh_30")
putexcel A31 = ("HealthSelfRatedGood_30")
putexcel A32 = ("HealthSelfRatedVeryGoodExcel_30")
putexcel A33 = ("Liwwh_40")
putexcel A34 = ("HealthSelfRatedGood_40")
putexcel A35 = ("HealthSelfRatedVeryGoodExcel_40")
putexcel A36 = ("Liwwh_50")
putexcel A37 = ("HealthSelfRatedGood_50")
putexcel A38 = ("HealthSelfRatedVeryGoodExcel_50")

putexcel B1 = ("COEFFICIENT")
putexcel C1 = ("IncomeDiv100")
putexcel D1 = ("IncomeSqDiv10000")
putexcel E1 = ("MaleLeisure")
putexcel F1 = ("MaleLeisureSq")
putexcel G1 = ("FullFixedCost_Male")
putexcel H1 = ("MaleLeisure_MaleAgeDiv100")
putexcel I1 = ("MaleLeisure_MaleAgeSqDiv10000")
putexcel J1 = ("Liwwh_1")
putexcel K1 = ("HealthSelfRatedGood_1")
putexcel L1 = ("HealthSelfRatedVeryGoodExcel_1")
putexcel M1 = ("Liwwh_2")
putexcel N1 = ("HealthSelfRatedGood_2")
putexcel O1 = ("HealthSelfRatedVeryGoodExcel_2")
putexcel P1 = ("Liwwh_3")
putexcel Q1 = ("HealthSelfRatedGood_3")
putexcel R1 = ("HealthSelfRatedVeryGoodExcel_3")
putexcel S1 = ("Liwwh_4")
putexcel T1 = ("HealthSelfRatedGood_4")
putexcel U1 = ("HealthSelfRatedVeryGoodExcel_4")
putexcel V1 = ("Liwwh_5")
putexcel W1 = ("HealthSelfRatedGood_5")
putexcel X1 = ("HealthSelfRatedVeryGoodExcel_5")
putexcel Y1 = ("Liwwh_10")
putexcel Z1 = ("HealthSelfRatedGood_10")
putexcel AA1 = ("HealthSelfRatedVeryGoodExcel_10")
putexcel AB1 = ("Liwwh_20")
putexcel AC1 = ("HealthSelfRatedGood_20")
putexcel AD1 = ("HealthSelfRatedVeryGoodExcel_20")
putexcel AE1 = ("Liwwh_30")
putexcel AF1 = ("HealthSelfRatedGood_30")
putexcel AG1 = ("HealthSelfRatedVeryGoodExcel_30")
putexcel AH1 = ("Liwwh_40")
putexcel AI1 = ("HealthSelfRatedGood_40")
putexcel AJ1 = ("HealthSelfRatedVeryGoodExcel_40")
putexcel AK1 = ("Liwwh_50")
putexcel AL1 = ("HealthSelfRatedGood_50")
putexcel AM1 = ("HealthSelfRatedVeryGoodExcel_50")
}

* output coefficients 
matrix results = r(table)
matrix results = results[1..6,1...]'   //extract the first six rows of results, and then transpose results
putexcel B2= matrix(results /*, names*/ ) //names nformat(number_d2)  //write estimates in Excel from cell B2

* output variance-covariance matrix 
matrix results=e(V)
putexcel C2 = matrix(results /*, names*/ ) //names nformat(number_d2)  //write e(V) in Excel from cell C2 

} //end of loop for gender 


*********************
*Marginal utilities *
*********************
*this is inside the gender loop (ignore,estimates are combined for  both genders)
capture drop dU_c
capture drop dU_lei
capture drop dU2_c
capture drop dU2_lei


			*-----------------------------------------------------------------
			* First differential of utility w.r.t. disposable income
			*-----------------------------------------------------------------
			gen dU_c=_b[hhcon_100] +2*hhcon_100*_b[hhcon2_10000] /*+leisure*_b[lei_hhcon_100]*/ 
            su dU_c if temp_choicehh==1  //& sim_flag==0
			
			*-----------------------------------------------------------------
			* Second differential of utility w.r.t. disposable income
			*-----------------------------------------------------------------
            gen dU2_c=2*_b[hhcon2_10000]
			su dU2_c if temp_choicehh==1  //& sim_flag==0


			*-----------------------------------------------------------------
			* First differential of utility w.r.t. leisure
			*-----------------------------------------------------------------
			gen double dU_lei=_b[leisure]+2*leisure*_b[leisure2] /*+hhcon_100*_b[lei_hhcon_100]*/ ///
			+ age_100*_b[lei_age_100] + age2_10000*_b[lei_age2_10000]
            su dU_lei if temp_choicehh==1  //& sim_flag==0
						
			*-----------------------------------------------------------------
			* Second differential of utility w.r.t. leisure
			*-----------------------------------------------------------------
		    gen dU2_lei=2*_b[leisure2]
			su dU2_lei if temp_choicehh==1  //& sim_flag==0
			
			
			
			
*-----------------------------------------------------------------
* Predict prob for both actual and simulated data
*-----------------------------------------------------------------
capture drop choice_prob
capture drop hrs_hat
capture drop E_hrs_hat
capture drop prob_work

predict choice_prob    //probability of a positive outcome
count 
*the highest utility=deterministic+stochastic is chosen

append using "sim_singles_dep_110_individuals_output_wage$impmethod"   //for "singles" sample, get simulated ils_dispy resulting from 10% increase of gross wage
fre sim_flag 
//we need to generate  fixc_dgn also for the simulated income sample
replace fixc_dgn=fixed_cost*dgn if sim_flag==1
lab var fixc_dgn "fixed cost for labour$\times$1(male)"

predict double pred_prob if sim_flag==0										//predicted probabilities (deterministic)
predict double de_pred_utility if  sim_flag==0, xb										//deterministic component of utility
sum de_pred_utility if  sim_flag==0
//v15 update
predict double sim_pred_prob if  sim_flag==1										//predicted probabilities (deterministic)
predict double sim_de_pred_utility if  sim_flag==1, xb										//for simulated hhcon, deterministic component of utility
su sim_de_pred_utility if  sim_flag==1



capture drop hrs_elas_*
set seed 339487731
//v15 update: loop for random draw
//add loop beginning
forvalues i = 1/$n_draws {
capture drop epsilon 
capture drop pred_utility
capture drop max_utility
capture drop pred_lhw
capture drop temp_pred_lhw

capture drop sim_pred_utility
capture drop sim_max_utility
capture drop sim_pred_lhw
capture drop sim_temp_pred_lhw


gen double epsilon= -log(-log(runiform()))	 						//random draw from an extreme value distribution (required for counterfactual)
gen double pred_utility= de_pred_utility+epsilon if  sim_flag==0				//utility=deterministic utility+stochastic utility

bys temp_idorigperson2: egen double max_utility=max(pred_utility) if  sim_flag==0	//for each agent highest utility 
gen pred_lhw=lhw if max_utility==pred_utility & sim_flag==0						//predicted hours of work (only present in the chosen row)
replace pred_lhw=0 if pred_lhw==.
bys temp_idorigperson2: egen temp_pred_lhw=total(pred_lhw) , missing				//expand pred_lhw2 to all alternatives (missing as 0)



//v15 update: predict optimal hours for sim_hhcon
gen double sim_pred_utility= sim_de_pred_utility+epsilon if  sim_flag==1				//utility=deterministic utility+stochastic utility
bys temp_idorigperson2: egen double sim_max_utility=max(sim_pred_utility) if sim_flag==1	//for each agent highest utility 
gen sim_pred_lhw=lhw if sim_max_utility==sim_pred_utility  & sim_flag==1							//predicted hours of work (only present in the chosen row)
bys temp_idorigperson2: egen sim_temp_pred_lhw=total(sim_pred_lhw) , missing				//expand pred_lhw2 to all alternatives (missing as 0)


****************
*Elasticities  *
****************
gen hrs_elas_`i'=10*(sim_temp_pred_lhw-temp_pred_lhw)/temp_pred_lhw if  temp_choicehh==1
}
order hrs_elas_*, last 
egen mean_hrs_elas=rmean(hrs_elas_1-hrs_elas_$n_draws) if  temp_choicehh==1 & sample==1  // single female's/male's hours elasticity (for each obs)
su mean_hrs_elas if  temp_choicehh==1 & sample==1,d  //summary of single females's hours elasticity across observations


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//hours fit graph (histograms for two genders)(with the last random draw as previous draws are all overwritten)  //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*twoway (histogram lhw           if temp_choice==1  & sample==1, discrete percent color(green) ) ///
	   (histogram temp_pred_lhw if temp_choice==1  & sample==1, discrete percent fcolor(none) lcolor(black)), ///
		   legend(order(1 "observed" 2 "predicted" )) ///
		   subtitle("Couples, only one partner LS flexible") xtitle("weekly hours worked") xlabel($graph_combined , valuelabel )
 
//graph combine  "his_hoursfit_0" "his_hoursfit_1" 
graph export "$results_ls/singles-dep/his_hoursfit_bothgenders_dep.png", as(png) replace
*/

////////////////////////////////////////////////////////////////////////////////////////////////////
// hours fit graphs: women and men, then combined
////////////////////////////////////////////////////////////////////////////////////////////////////

forvalues gender = 0/1 {

    if (`gender' == 0) {
        local hours $graph_singles_women
        local title "Women"
    }
    else {
        local hours $graph_singles_men
        local title "Men"
    }

    local n : word count `hours'
    local labels ""

    capture drop graph_lhw_`gender' graph_pred_lhw_`gender'
    gen graph_lhw_`gender' = .
    gen graph_pred_lhw_`gender' = .

    forvalues i = 1/`n' {
        local h : word `i' of `hours'

        replace graph_lhw_`gender' = `i' if lhw == `h'
        replace graph_pred_lhw_`gender' = `i' if temp_pred_lhw == `h'

        local labels `labels' `i' "`h'"
    }

    twoway ///
        (histogram graph_lhw_`gender' if temp_choice==1 & sample==1, ///
            discrete percent color(green)) ///
        (histogram graph_pred_lhw_`gender' if temp_choice==1 & sample==1, ///
            discrete percent fcolor(none) lcolor(black)), ///
        legend(order(1 "observed" 2 "predicted")) ///
        subtitle("`title'") ///
        xtitle("weekly hours worked") ///
        xlabel(`labels', noticks)

    graph save "$results_ls/singles-dep/his_hoursfit_`gender'_dep.gph", replace
}

graph combine ///
    "$results_ls/singles-dep/his_hoursfit_0_dep.gph" ///
    "$results_ls/singles-dep/his_hoursfit_1_dep.gph", ///
    cols(2) ///
    title("Couples, only one partner LS flexible")

graph export "$results_ls/singles-dep/his_hoursfit_bothgenders_dep.png", ///
    as(png) replace


/////////////////////////
//graph of elasticity  //
/////////////////////////
twoway (histogram mean_hrs_elas if temp_choicehh==1 & sample==1 ,  fcolor(none) lcolor(black)), ///
		      subtitle("Hours elasticity")
graph export "$results_ls/singles-dep/hrs_elas_single_dep.png", as(png) replace


sum ils_dispy
//save singles_wage$impmethod.dta, replace  //try not to save too many data files to save disc space

///////////////////////////////
//histogram of du/dc, du/dlei//
///////////////////////////////
twoway (histogram dU_c if sample==1 &temp_choicehh==1 ,  fcolor(none) lcolor(black)), ///
		   subtitle("MU wrt income")
		   graph export "$results_ls/singles-dep/dUdc_single_dep.png", as(png) replace
		   
twoway (histogram dU_lei if sample==1& temp_choicehh==1,  fcolor(none) lcolor(black)), ///
		   subtitle("MU wrt leisure")
		   graph export "$results_ls/singles-dep/dUdlei_single_dep.png", as(png) replace

		   
su dU_c dU_lei  dU2_c dU2_lei  if sample==1& temp_choicehh==1  

  

/////////////////////////////////////
//export estimation results to tex //
/////////////////////////////////////
esttab  singles_wage$impmethod using "$results_ls/singles-dep/ls_single_dep_10.tex", replace label cells(b(star fmt(3))) stats(ll r2_p N ) nonumbers ///
collabels(none) ///
title(Labour supply (utility function) estimation: Couples, only one partner LS flexible. ///
		Notes: Income in hundreds of British Pounds. ///
\label{tab:hours-singles}) ///
varlabels(r2_p pseudo-R^2) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing tex including female and male(including at least three non-zero digits)

esttab  singles_wage$impmethod using "$results_ls/singles-dep/ls_single_dep_10.csv", replace label cells(b(star fmt(3))) stats(ll r2_p N ) nonumbers  ///
collabels(none) ///
title(Labour supply (utility function) estimation: Couples, only one partner LS flexible. ///
		Notes: Income in hundreds of British Pounds. ///
\label{tab:hours-singles}) ///
varlabels(r2_p pseudo-R^2) ///
addnote("*** Results significant at 0.1\%, ** 1\%, * 5\%.") //for writing csv including female and male(including at least three non-zero digits)

/////////////////////
//Income deciles ////
/////////////////////
xtile dec_hhcon = hhcon if sample==1 &temp_choicehh==1, nq(10)  //create decile variable for single female and male

bysort dec_hhcon:su mean_hrs_elas if sample==1 &temp_choicehh==1

//box plot
label var dec_hhcon "income decile"
graph box mean_hrs_elas if temp_choicehh==1, ytitle(wage elasticity) over(dec_hhcon)  subtitle("Couples, only one partner LS flexible") note("Income decile" ///
"Lines indicate upper adjacent value, 75th percentile, median, 25th percentile, lower adjacent value.") 

graph export "$results_ls/singles-dep/wage_elas_dep.png", as(png) replace
		
		
///////////////////
///summary stats //
///////////////////

*percent of obs with positive marginal utilities 
foreach i in dU_c dU_lei{
//foreach gender in 0 1{
gen `i'positive=(`i'>0)
su `i'positive if sample==1 & temp_choicehh==1
//}
}
*percent of obs with negative marginal utilities  
foreach i in dU_c dU_lei{
cap drop `i'_negative
gen `i'_negative=(`i'<0)
sum `i'_negative if sample==1 & temp_choicehh==1 
} 

		
///////////////////////////////////////////////		
//output to Excel file with summary stats   ///
///////////////////////////////////////////////
putexcel set "${summary_table}", sheet(${sheet}) modify	


putexcel A2=("Wage elasticities of hours of work")
putexcel A8=("Couples, only one LS flexible")
qui mean mean_hrs_elas if sample==1 &temp_choicehh==1
putexcel B8=matrix(e(b)')

putexcel A9=("% obs with negative marginal utility wrt income")
putexcel A14=("Couples, only one LS flexible")
qui mean dU_c_negative if sample==1 &temp_choicehh==1
putexcel B14=matrix(e(b)')


putexcel A15=("% obs with negative marginal utility wrt leisure")
putexcel A21=("Couples, only one LS flexible")
qui mean dU_lei_negative if sample==1 &temp_choicehh==1
putexcel B21=matrix(e(b)')

//add log likelihood 
putexcel A22=("Log likelihood")
putexcel A27=("Couples, only one LS flexible")
qui mean ll if sample==1 
putexcel B27=matrix(e(b)')


//obs vs predicted wages fit 
putexcel A44=("Couples, only one LS flexible")
putexcel A45=("observed")
putexcel A46=("predicted")
qui mean lhw if temp_choice==1 & sample==1 
putexcel B45=matrix(e(b)')
qui mean temp_pred_lhw if temp_choice==1  & sample==1
putexcel B46=matrix(e(b)')
	
		
		
log close

		

