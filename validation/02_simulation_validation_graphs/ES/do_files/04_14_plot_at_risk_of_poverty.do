
/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         04_14_plot_at_risk_of_poverty.do
* DESCRIPTION:          Plots observed and simulated at-risk-of-poverty rates.
* COUNTRY:              ES
* DATA:                 EU-SILC validation sample and SimPaths outputs
* AUTHOR:               Ashley Burdett
* LAST UPDATE:          21 October 2026
********************************************************************************
* NOTES:
*
*   -----------------------------------------------------------------------
*    What this file does
*   -----------------------------------------------------------------------
*   This do-file generates validation plots comparing annual
*   at-risk-of-poverty rates in EU-SILC and SimPaths.
*
*   Individuals are classified as at risk of poverty if their equivalised 
* 	disposable benefit-unit income falls below 60% of the median equivalised 
* 	disposable income.
*
*   Poverty thresholds are calculated separately for each year and, for 
* 	SimPaths, each simulation run. EU-SILC thresholds and poverty rates are 
* 	calculated using survey weights.
*
*   The plots compare observed EU-SILC poverty rates with the mean simulated 
* 	rates across multiple simulation runs.
*
*   Comparisons are produced separately for individuals aged 18-65 and 
* 	individuals aged 18 or older.
*
*******************************************************************************/

********************************************************************************
* 1 : Mean values over time
********************************************************************************

********************************************************************************
* 1.1 : Mean values over time, working age (18-65)
********************************************************************************

* Prepare validation data
use year demAge dwt valid_yDispBuEquivYear using ///
	"$dir_data/${country}-eusilc_validation_sample.dta", clear

* Select sample
keep if inrange(demAge,18,65)	
		
qui sum year
local min_year = 2011
if "$min_sim_year" != "" local min_year = $min_sim_year
local max_year = r(max)
if "$max_sim_year" != "" local max_year = $max_sim_year


* Calculate poverty threshold using weighted median income
gen poverty_line = .

forval year = `min_year'/`max_year' {
	
	_pctile valid_yDispBuEquivYear [pw = dwt] if year == `year', p(50)
	replace poverty_line = 0.6*r(r1) if year == `year'

}

* Calculate at risk of poverty 
gen arop = (valid_yDispBuEquivYear < poverty_line) ///
    if !missing(valid_yDispBuEquivYear, poverty_line)

collapse (mean) arop [aw = dwt], by(year)

save "$dir_data/temp_valid_stats.dta", replace


* Prepare simulated data
use run year demAge sim_yDispEquivYear using ///
	"$dir_data/simulation_sample.dta", clear
	
* Select sample	
keep if inrange(demAge,18,65)		

* Calculate poverty threshold 
bys run year: egen equivincome_median = median(sim_yDispEquivYear)

gen poverty_line = 0.6*equivincome_median

* Calculate at risk of poverty 
gen arop_sim = (sim_yDispEquivYear < poverty_line) ///
    if !missing(sim_yDispEquivYear, poverty_line)
	
collapse (mean) arop_sim, by(run year)

collapse (mean) arop_sim ///
		 (sd) arop_sim_sd = arop_sim ///
		 , by(year)
		 
foreach varname in arop_sim {
	
	gen `varname'_high = `varname' + 1.96*`varname'_sd
	gen `varname'_low = `varname' - 1.96*`varname'_sd

}

merge 1:1 year using "$dir_data/temp_valid_stats.dta", keep(3) nogen

* Plot figure
twoway (rarea arop_sim_high arop_sim_low year, sort color(green%20) ///
	legend(label(1 "SimPaths"))) ///
(line arop year, sort color(green) legend(label(2 "SILC"))), ///
	title("At Risk of Poverty") ///
	subtitle("Ages 18-65") ///
	xtitle("Year", size(small)) ///
	ytitle("Share", size(small)) ///
	xlabel(, labsize(small)) ///
	ylabel(, labsize(small)) ///
	legend(size(small)) ///
	graphregion(color(white)) ///
	note("Note: Poverty line calculated within each year as 60% of the median equivalised disposable income of benefit unit. Calculated" "using individual level observations.", ///
	size(vsmall))

* Save figure
graph export "$dir_output_files/poverty/validation_${country}_at_risk_of_poverty_18_65.jpg", ///
	replace width(2560) height(1440) quality(100)

	
	
********************************************************************************
* 1.1 : Mean values over time, 18+ 
********************************************************************************

* Prepare validation data
use year demAge dwt valid_yDispBuEquivYear using ///
	"$dir_data/${country}-eusilc_validation_sample.dta", clear

* Select sample 
drop if demAge < 18	

qui sum year
local min_year = 2011
if "$min_sim_year" != "" local min_year = $min_sim_year
local max_year = r(max)
if "$max_sim_year" != "" local max_year = $max_sim_year


* Calculate poverty threshold using weighted median income
gen poverty_line = .

forval year = `min_year'/`max_year' {
	
	_pctile valid_yDispBuEquivYear [pw = dwt] ///
        if year == `yearr', p(50)

    replace poverty_line = 0.6*r(r1) if year == `year'

}

* Calculate at risk of poverty 
gen arop = (valid_yDispBuEquivYear < poverty_line)

collapse (mean) arop [aw = dwt], by(year)

save "$dir_data/temp_valid_stats.dta", replace


* Prepare simulated data
use run year demAge sim_yDispEquivYear using ///
	"$dir_data/simulation_sample.dta", clear

* Select sample
drop if demAge < 18 

* Calculate poverty threshold
bys run year: egen equivincome_median = median(sim_yDispEquivYear)

gen poverty_line = 0.6*equivincome_median

* Calculate at risk of poverty 
gen arop_sim = (sim_yDispEquivYear < poverty_line)

collapse (mean) arop_sim, by(run year)

collapse (mean) arop_sim ///
		 (sd) arop_sim_sd = arop_sim ///
		 , by(year)
		 
foreach varname in arop_sim {
	
	gen `varname'_high = `varname' + 1.96*`varname'_sd
	gen `varname'_low = `varname' - 1.96*`varname'_sd

}

merge 1:1 year using "$dir_data/temp_valid_stats.dta", keep(3) nogen

* Plot figure
twoway (rarea arop_sim_high arop_sim_low year, sort color(green%20) ///
	legend(label(1 "SimPaths"))) ///
(line arop year, sort color(green) legend(label(2 "SILC"))), ///
	title("At Risk of Poverty") ///
	subtitle("Ages 18+") ///
	xtitle("Year", size(small)) ///
	ytitle("Share", size(small)) ///
	xlabel(, labsize(small)) ///
	ylabel(, labsize(small)) ///
	legend(size(small)) ///
	graphregion(color(white)) ///
	note("Note: Poverty line calculated within each year as 60% of the median equivalised disposable income of benefit unit. Calculated" "using individual level observations.", ///
	size(vsmall))

* Save figure
graph export "$dir_output_files/poverty/validation_${country}_at_risk_of_poverty_18plus.jpg", ///
	replace width(2560) height(1440) quality(100)
	
	
graph drop _all 	
