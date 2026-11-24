/*******************************************************************************
* PROJECT:        SimPaths EU
* SECTION:        ALIGNMENT PROCEDURES
*
* AUTHORS:        Mariia Vartuzova (MV)
* LAST UPDATE:    19/11/2026 (MV)
* COUNTRY:        ES (Spain)
*
* DATA:           Initial populations
*
* DESCRIPTION:    This do-file constructs disability targets using initial
*                population data. It:
*                  - Imports initial population CSV files by year
*                  - Computes the share of disabled persons
*                    (healthDsblLongtermFlag == 1) among those with non-missing
*                    disability status
*                  - Exports the results to Excel
*
* SUPERSEDED:     Kept for reference: the targets on the survey's own age
*                mix, written to alignment_targets_disability_NotPopProjAgeNormalised.xlsx.
*                SimPaths uses the targets of 03_disability_targets_initpopdataEU.do, computed
*                on the official population's age mix.
*
* NOTE:           This EU version uses refactored variable names from the
*                initial populations (e.g., idPers, healthDsblLongtermFlag,
*                wgtCrossMainSurvey).
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
global dir_w "~/IdeaProjects/SimPathsEU_OCT"

* Country code and time span for which targets are produced
global country = "ES"
global min_year 2011
global max_year 2023

* Directory structure
global dir_input_data   "$dir_w/input/${country}/InitialPopulations"
global dir_working_data "$dir_w/input/${country}/DoFilesTargets/working_data"
global dir_output       "$dir_w/input/${country}/DoFilesTargets"

* Create the output folders if they do not exist yet
capture mkdir "${dir_output}"
capture mkdir "${dir_working_data}"


* Initialise file that will store disability shares for all years
clear
save "${dir_working_data}/disability_shares_${country}_initpopdata.dta", emptyok replace

* ========================================================================== *

// Loop over all years in the requested range
foreach y of numlist $min_year/$max_year {

	* Build file name for the given year and import initial population data
	local file = subinstr("population_initial_${country}_YYYY.csv","YYYY","`y'",.)
	import delimited using "${dir_input_data}/`file'", clear case(preserve)

	bys idPers: keep if _n == 1 // keep one obs per idPers

	// Alignment target: share of disabled persons among those with non-missing healthDsblLongtermFlag
	gen byte isDisabled = (healthDsblLongtermFlag == 1)
    collapse (mean) disabled_share = isDisabled if (healthDsblLongtermFlag != .) [pw = wgtCrossMainSurvey]

	gen year = `y'

	* Append to cumulative file for all years
	append using "${dir_working_data}/disability_shares_${country}_initpopdata.dta"
	duplicates drop
	save "${dir_working_data}/disability_shares_${country}_initpopdata.dta", replace

}

* -------------------------------------------------------------------------- *
* POST-PROCESSING: export aggregated results to Excel
* -------------------------------------------------------------------------- *


use "${dir_working_data}/disability_shares_${country}_initpopdata.dta", clear

* Sort by year for neat export
sort year

* Create/overwrite Excel file that will hold all sheets
* Start from a new workbook. putexcel applies replace only at its first
* write, so an existing workbook would otherwise be modified, and its styles
* duplicated on every run (until Apache POI in SimPaths rejects the file)
capture erase "${dir_output}/alignment_targets_disability_NotPopProjAgeNormalised.xlsx"
putexcel set "${dir_output}/alignment_targets_disability_NotPopProjAgeNormalised.xlsx", replace


* Build separate matrices for year and share (written with explicit Excel formats)
mkmat year,           matrix(Yr)
mkmat disabled_share, matrix(Sh)

* Point putexcel at the output file and the group-specific sheet
putexcel set "${dir_output}/alignment_targets_disability_NotPopProjAgeNormalised.xlsx", sheet("disability") modify

* Write headers
putexcel A1=("year") B1=("disabled_share")

* Write data: years as integers, shares with 7 decimal places
putexcel A2=matrix(Yr), nformat("0")
putexcel B2=matrix(Sh), nformat("0.000000")

* --- INFO SHEET ------------------------------------------------------------ *
local today "`c(current_date)'"
putexcel set "${dir_output}/alignment_targets_disability_NotPopProjAgeNormalised.xlsx", sheet("info") modify
putexcel A1=("Field")       B1=("Value")
putexcel A2=("Target")      B2=("Share of disabled persons among those with non-missing disability status")
putexcel A3=("Population")  B3=("All persons in the initial population with non-missing healthDsblLongtermFlag")
putexcel A4=("Definition")  B4=("healthDsblLongtermFlag == 1 (long-term sick or disabled)")
putexcel A5=("Age filter")  B5=("None (all ages included)")
putexcel A6=("Weighting")   B6=("Population weights (wgtCrossMainSurvey)")
putexcel A7=("Note")        B7=("SimPaths H2 model only updates healthDsblLongtermFlag for non-retired, non-student persons aged 16+; target denominator includes all ages and statuses")
putexcel A8=("Source")      B8=("EU-SILC-based SimPaths initial populations")
putexcel A9=("Country")     B9=("${country}")
putexcel A10=("Years")      B10=("${min_year}-${max_year}")
putexcel A11=("Do-file")    B11=("03_disability_targets_initpopdataEU_NotPopProjAgeNormalised.do")
putexcel A12=("Produced")   B12=("`today'")


* --- CLEAN UP ------------------------------------------------------------- *
* The workbook is the only output: erase the working data, then the
* working-data folder if nothing else is left in it
erase "${dir_working_data}/disability_shares_${country}_initpopdata.dta"
capture rmdir "${dir_working_data}"
