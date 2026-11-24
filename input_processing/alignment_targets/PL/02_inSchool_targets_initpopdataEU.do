/*******************************************************************************
* PROJECT:        SimPaths EU
* SECTION:        ALIGNMENT PROCEDURES
*
* AUTHORS:        Codex
* LAST UPDATE:    24/11/2026
* COUNTRY:        EU
*
* DATA:           Initial populations
*
* DESCRIPTION:    This do-file constructs student targets for different
*                groups of the population using initial population data.
*                It:
*                  - Imports initial population CSV files by year
*                  - Computes student ratio to total population for each year
*                  - Exports the results to Excel
*
* WEIGHTS:        Each person's wgtCrossMainSurvey is multiplied by the
*                official count over the survey weighted count in their
*                gender x region x age cell (00_popproj_weights.do). The
*                target is then computed on the age mix of the official
*                population, which SimPaths simulates, not on the
*                survey's own mix. The version on the survey's mix is
*                kept as 02_inSchool_targets_initpopdataEU_NotPopProjAgeNormalised.do.
*
* NOTE:           This EU version uses refactored variable names from the
*                initial populations (e.g., idPers, demAge, labC4,
*                wgtCrossMainSurvey).
*
* STATA REQ:      Stata 13+. `import delimited` uses `case(preserve)` to
*                retain the camelCase column names of the refactored
*                initial-population CSVs.
*
* SET-UP:         1. Set global dir_w to the root of this SimPaths project
*                 2. The initial populations are read from
*                    input/<country>/InitialPopulations of that project, and
*                    the official population from
*                    input/<country>/align_popProjections.xlsx. The workbook
*                    is written straight to input/<country>/, where SimPaths
*                    reads it
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

* Directory structure
global dir_input_data   "$dir_w/input/${country}/InitialPopulations"
global dir_working_data "$dir_w/input/${country}/DoFilesTargets/working_data"
global dir_output       "$dir_w/input/${country}"

* Create the working-data folders if they do not exist yet
capture mkdir "$dir_w/input/${country}/DoFilesTargets"
capture mkdir "${dir_working_data}"

* Official population by cell, and the program popproj_weight
do "${dir_w}/input_processing/alignment_targets/${country}/00_popproj_weights.do"

* Initialise file that will store student shares for all years
clear
save "${dir_working_data}/student_shares_${country}_initpopdata_popproj.dta", emptyok replace

* ========================================================================== *

// Loop over all years in the requested range
foreach y of numlist $min_year/$max_year {

	* Build file name for the given year and import initial population data
	local file = subinstr("population_initial_${country}_YYYY.csv","YYYY","`y'",.)
	import delimited using "${dir_input_data}/`file'", clear case(preserve)

	bys idPers: keep if _n == 1 // keep one obs per idPers

	* Weight on the official gender x region x age mix: wgtPopProj
	popproj_weight `y'

	// Alignment target: share of students among 16-29 age group, defined in SimPathsModel.java
	gen byte isStudent = (labC4 == 2 & demAge >= 16 & demAge <= 29)
    collapse (mean) student_share = isStudent if (labC4 != . & demAge >= 16 & demAge <= 29) [pw = wgtPopProj]

	gen year = `y'

	* Append to cumulative file for all years
	append using "${dir_working_data}/student_shares_${country}_initpopdata_popproj.dta"
	duplicates drop
	save "${dir_working_data}/student_shares_${country}_initpopdata_popproj.dta", replace

}

* -------------------------------------------------------------------------- *
* POST-PROCESSING: export aggregated results to Excel
* -------------------------------------------------------------------------- *


use "${dir_working_data}/student_shares_${country}_initpopdata_popproj.dta", clear

* Sort by year for neat export
sort year

* Create/overwrite Excel file that will hold all sheets
putexcel set "${dir_output}/alignment_targets_inSchool.xlsx", replace


* Build separate matrices for year and share (written with explicit Excel formats)
mkmat year,          matrix(Yr)
mkmat student_share, matrix(Sh)

* Point putexcel at the output file and the group-specific sheet
putexcel set "${dir_output}/alignment_targets_inSchool.xlsx", sheet("students") modify

* Write headers
putexcel A1=("year") B1=("student_share")

* Write data: years as integers, shares with 7 decimal places
putexcel A2=matrix(Yr), nformat("0")
putexcel B2=matrix(Sh), nformat("0.000000")

* --- INFO SHEET ------------------------------------------------------------ *
local today "`c(current_date)'"
putexcel set "${dir_output}/alignment_targets_inSchool.xlsx", sheet("info") modify
putexcel A1=("Field")       B1=("Value")
putexcel A2=("Target")      B2=("Share of students among persons aged 16-29 with non-missing labour status")
putexcel A3=("Population")  B3=("Persons aged 16-29 with non-missing labC4")
putexcel A4=("Definition")  B4=("labC4 == 2 (Student) & demAge >= 16 & demAge <= 29")
putexcel A5=("Age filter")  B5=("16-29 (matching SimPathsModel inSchool alignment window)")
putexcel A6=("Weighting")   B6=("wgtPopProj = wgtCrossMainSurvey x official count / survey weighted count in the person's gender x region x age cell (ages ${popproj_top_age}+ pooled; align_popProjections.xlsx, 00_popproj_weights.do)")
putexcel A7=("Source")      B7=("EU-SILC-based SimPaths initial populations")
putexcel A8=("Country")     B8=("${country}")
putexcel A9=("Years")       B9=("${min_year}-${max_year}")
putexcel A10=("Do-file")    B10=("02_inSchool_targets_initpopdataEU.do")
putexcel A11=("Produced")   B11=("`today'")


* --- CLEAN UP ------------------------------------------------------------- *
* The workbook is the only output: erase the working data, then the
* working-data folder and DoFilesTargets if nothing else is left in them
erase "${dir_working_data}/student_shares_${country}_initpopdata_popproj.dta"
erase "${dir_working_data}/popproj_cells_${country}.dta"
capture rmdir "${dir_working_data}"
capture rmdir "$dir_w/input/${country}/DoFilesTargets"
