/*******************************************************************************
* PROJECT:        SimPaths EU
* SECTION:        ALIGNMENT PROCEDURES
*
* AUTHORS:        Codex
* LAST UPDATE:    19/11/2026
* COUNTRY:        EU
*
* DATA:           Initial populations
*
* DESCRIPTION:    This do-file constructs retirement targets using initial
*                population data. It:
*                  - Imports initial population CSV files by year
*                  - Computes the share of retired persons (labC4 == 4)
*                    among those aged min_age_to_retire (50) or older with
*                    non-missing labour status
*                  - Exports the results to Excel
*
*                The age limit is MIN_AGE_TO_RETIRE in parameters.xlsx, the
*                age from which SimPaths considers retirement. The simulation
*                measures the retired share on the same population, both when
*                aligning (RetirementAlignment.java) and in the output
*                (AlignmentStatistics.java).
*
* SUPERSEDED:     Kept for reference: the targets on the survey's own age
*                mix, written to alignment_targets_retirement_NotPopProjAgeNormalised.xlsx.
*                SimPaths uses the targets of 01_retirement_targets_initpopdataEU.do, computed
*                on the official population's age mix.
*
* NOTE:           This EU version uses refactored variable names from the
*                initial populations (e.g., idPers, labC4, wgtCrossMainSurvey).
*
* STATA REQ:      Stata 13+. `import delimited` uses `case(preserve)` to
*                retain the camelCase column names of the refactored
*                initial-population CSVs.
*
* SET-UP:         1. Set global dir_w to the root of this SimPaths project
*                 2. The initial populations are read from
*                    input/<country>/InitialPopulations of that project. The
*                    workbook is written to input/<country>/DoFilesTargets;
*                    copy it to input/<country>/ for SimPaths to use it
*
*******************************************************************************/

clear all


* --- DEFINE GLOBALS -------------------------------------------------------- *

* Working directory (project root)
//global dir_w "/Users/pineapple/Library/CloudStorage/OneDrive-UniversityofEssex/WorkCEMPA/SimPathsEU/SimPathsTargets"
global dir_w "/Users/pineapple/IdeaProjects/SimPathsEU_OCT"


* Country code and time span for which targets are produced
global country = "PL"
global min_year 2011
global max_year 2023

* Target population: persons aged min_age_to_retire or older. Must equal
* MIN_AGE_TO_RETIRE in input/${country}/parameters.xlsx (sheet Parameters).
global min_age_to_retire 50

* Directory structure
global dir_input_data   "$dir_w/input/${country}/InitialPopulations"
global dir_working_data "$dir_w/input/${country}/DoFilesTargets/working_data"
global dir_output       "$dir_w/input/${country}/DoFilesTargets"

* Create the output folders if they do not exist yet
capture mkdir "${dir_output}"
capture mkdir "${dir_working_data}"


* Initialise file that will store retirement shares for all years. Start from
* an empty file, so that shares saved by an earlier run are not exported again.
clear
save "${dir_working_data}/retirement_shares_${country}_initpopdata.dta", emptyok replace


* ========================================================================== *

// Loop over all years in the requested range
foreach y of numlist $min_year/$max_year {

	* Build file name for the given year and import initial population data
	local file = subinstr("population_initial_${country}_YYYY.csv","YYYY","`y'",.)
	import delimited using "${dir_input_data}/`file'", clear case(preserve)

	bys idPers: keep if _n == 1 // keep one obs per idPers

	// Alignment target: share of retired persons among those aged
	// min_age_to_retire or older with non-missing labC4
	gen byte isRetired = (labC4 == 4)
    collapse (mean) retired_share = isRetired ///
        if (labC4 != . & demAge != . & demAge >= ${min_age_to_retire}) [pw = wgtCrossMainSurvey]

	gen year = `y'

	* Append to cumulative file for all years
	append using "${dir_working_data}/retirement_shares_${country}_initpopdata.dta"
	duplicates drop
	save "${dir_working_data}/retirement_shares_${country}_initpopdata.dta", replace

}

* -------------------------------------------------------------------------- *
* POST-PROCESSING: export aggregated results to Excel
* -------------------------------------------------------------------------- *


use "${dir_working_data}/retirement_shares_${country}_initpopdata.dta", clear

* Sort by year for neat export
sort year

* Create/overwrite Excel file that will hold all sheets
* Start from a new workbook. putexcel applies replace only at its first
* write, so an existing workbook would otherwise be modified, and its styles
* duplicated on every run (until Apache POI in SimPaths rejects the file)
capture erase "${dir_output}/alignment_targets_retirement_NotPopProjAgeNormalised.xlsx"
putexcel set "${dir_output}/alignment_targets_retirement_NotPopProjAgeNormalised.xlsx", replace


* Build separate matrices for year and share (written with explicit Excel formats)
mkmat year,          matrix(Yr)
mkmat retired_share, matrix(Sh)

* Point putexcel at the output file and the group-specific sheet
putexcel set "${dir_output}/alignment_targets_retirement_NotPopProjAgeNormalised.xlsx", sheet("retirement") modify

* Write headers
putexcel A1=("year") B1=("retired_share")

* Write data: years as integers, shares with 7 decimal places
putexcel A2=matrix(Yr), nformat("0")
putexcel B2=matrix(Sh), nformat("0.000000")

* --- INFO SHEET ------------------------------------------------------------ *
local today "`c(current_date)'"
putexcel set "${dir_output}/alignment_targets_retirement_NotPopProjAgeNormalised.xlsx", sheet("info") modify
putexcel A1=("Field")       B1=("Value")
putexcel A2=("Target")      B2=("Share of retired persons among persons aged ${min_age_to_retire}+ with non-missing labour status")
putexcel A3=("Population")  B3=("Persons in the initial population aged ${min_age_to_retire}+ with non-missing labC4")
putexcel A4=("Definition")  B4=("labC4 == 4 (Retired)")
putexcel A5=("Age filter")  B5=("demAge >= ${min_age_to_retire} (MIN_AGE_TO_RETIRE in parameters.xlsx; RetirementAlignment and AlignmentStatistics use the same population)")
putexcel A6=("Weighting")   B6=("Population weights (wgtCrossMainSurvey)")
putexcel A7=("Source")      B7=("EU-SILC-based SimPaths initial populations")
putexcel A8=("Country")     B8=("${country}")
putexcel A9=("Years")       B9=("${min_year}-${max_year}")
putexcel A10=("Do-file")    B10=("01_retirement_targets_initpopdataEU_NotPopProjAgeNormalised.do")
putexcel A11=("Produced")   B11=("`today'")


* --- CLEAN UP ------------------------------------------------------------- *
* The workbook is the only output: erase the working data, then the
* working-data folder if nothing else is left in it
erase "${dir_working_data}/retirement_shares_${country}_initpopdata.dta"
capture rmdir "${dir_working_data}"
