/*******************************************************************************
* PROJECT:        SimPaths EU
* SECTION:        ALIGNMENT PROCEDURES
*
* AUTHORS:        Mariia Vartuzova (MV)
* LAST UPDATE:    24/11/2026 (MV)
* COUNTRY:        EU
*
* DATA:           input/<country>/align_popProjections.xlsx (official
*                population by gender, region and single year of age)
*
* DESCRIPTION:    Shared step of the target do-files 01-05 in this folder.
*                The survey weights (wgtCrossMainSurvey) are scaled to the
*                national total only, so the weighted initial populations
*                keep the survey's age mix. SimPaths simulates the official
*                population's mix instead (population alignment), so a
*                target computed on the survey's mix is partly a difference
*                in age composition. This do-file:
*                  - Reads the official population by year x gender x
*                    region x single year of age, ages popproj_top_age and
*                    above in one cell, and saves it to dir_working_data
*                  - Defines the program popproj_weight, which adds
*                    wgtPopProj = wgtCrossMainSurvey x official count /
*                    survey weighted count in the person's cell
*
*                Ages 80+ form one cell: EU-SILC top-codes age at 78, and the
*                UID construction imputes the older ages
*                (02_create_variables_<country>.do).
*
* USE:            Run by 01-05 once they have set dir_w, country and
*                dir_working_data:
*                  do "${dir_w}/input_processing/alignment_targets/${country}/00_popproj_weights.do"
*                Then, on one year's initial population, one row per person:
*                  popproj_weight <year>
*
* CHECKS:         popproj_weight stops with an error if a survey person falls
*                in no official cell, or if the cells with no survey person
*                hold more than popproj_max_empty_share of the official
*                population. Those cells cannot be reweighted, so their
*                population is left out of the targets.
*
*******************************************************************************/

* Ages from this one up form one cell
global popproj_top_age 80

* Largest share of the official population allowed in cells with no survey
* person (0.005 = 0.5%)
global popproj_max_empty_share 0.005


* --- OFFICIAL POPULATION BY CELL ------------------------------------------- *

import excel using "${dir_w}/input/${country}/align_popProjections.xlsx", ///
	sheet("Population_projections") firstrow clear

* Drop blank rows below the table
drop if missing(Gender, Region, Age)
confirm numeric variable Age

* The year columns have numeric headers: firstrow names them by column letter
* and keeps the year as the variable label
foreach v of varlist _all {
	if !inlist("`v'", "Gender", "Region", "Age") {
		local yr : variable label `v'
		rename `v' popProj`yr'
	}
}
reshape long popProj, i(Gender Region Age) j(year)

gen int popprojAge = min(Age, ${popproj_top_age})
rename (Gender Region) (popprojGender popprojRegion)
collapse (sum) popProj, by(year popprojGender popprojRegion popprojAge)
save "${dir_working_data}/popproj_cells_${country}.dta", replace
clear


* --- PROGRAM: popproj_weight ------------------------------------------------ *

capture program drop popproj_weight
program define popproj_weight
	args year

	confirm variable demMaleFlag demRgn demAge wgtCrossMainSurvey
	assert !missing(demMaleFlag, demRgn, demAge, wgtCrossMainSurvey)
	assert wgtCrossMainSurvey > 0

	* Official population of this year, by cell
	tempfile cells
	preserve
	use "${dir_working_data}/popproj_cells_${country}.dta" if year == `year', clear
	quietly count
	if r(N) == 0 {
		display as error "align_popProjections.xlsx has no population for `year'"
		exit 459
	}
	quietly summarize popProj
	local total = r(sum)
	drop year
	save `cells'
	restore

	* Survey weighted count by cell
	quietly {
		gen str6 popprojGender = cond(demMaleFlag == 1, "Male", "Female")
		gen str8 popprojRegion = "${country}" + string(demRgn)
		gen int popprojAge = min(demAge, ${popproj_top_age})
		bys popprojGender popprojRegion popprojAge: egen double popprojSurvey = total(wgtCrossMainSurvey)
		merge m:1 popprojGender popprojRegion popprojAge using `cells'
	}

	quietly count if _merge == 1
	if r(N) > 0 {
		display as error "`year': " r(N) " survey persons fall in no official gender x region x age cell"
		exit 459
	}

	quietly summarize popProj if _merge == 2
	local n_empty = r(N)
	local empty_share = r(sum) / `total'
	display as text "`year': " `n_empty' " official cells with no survey person, " ///
		%5.3f 100 * `empty_share' "% of the official population"
	if `empty_share' > ${popproj_max_empty_share} {
		display as error "`year': cells with no survey person hold more than " ///
			100 * ${popproj_max_empty_share} "% of the official population"
		exit 459
	}

	quietly drop if _merge == 2
	gen double wgtPopProj = wgtCrossMainSurvey * popProj / popprojSurvey
	drop popprojGender popprojRegion popprojAge popprojSurvey popProj _merge
end
