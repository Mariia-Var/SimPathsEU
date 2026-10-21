/*******************************************************************************
* PROJECT:        SimPaths EU
* SECTION:        ALIGNMENT PROCEDURES
*
* AUTHORS:        Codex
* LAST UPDATE:    30/03/2026
* COUNTRY:        PL
*
* DATA:           Existing target Excel workbooks
*
* DESCRIPTION:    This do-file compares old and new PL target workbooks and
*                exports the difference metrics to Excel. It:
*                  - Imports matching sheets from `*OLD.xlsx` and `.xlsx`
*                  - Merges observations by year
*                  - Computes raw difference and percentage-point difference
*                  - Flags the largest absolute pp difference within each
*                    sheet and ranks all comparisons in a summary sheet
*
* OUTPUTS:        input/PL/targets_old_vs_new_differences.xlsx
*                 input/PL/targets_old_vs_new_differences.dta
*
*******************************************************************************/

clear all


* --- DEFINE GLOBALS -------------------------------------------------------- *

global dir_w "/Users/pineapple/IdeaProjects/SimPathsEU_APR"
global country "PL"

global dir_input  "$dir_w/input/${country}"
global dir_output "$dir_w/input/${country}"


* --- TARGET / SHEET MAP --------------------------------------------------- *

local sheets_disability  "disability"
local sheets_employment  "Couples SingleAC_Females SingleAC_Males SingleDep_Females SingleDep_Males Single_female Single_male"
local sheets_inschool    "students"
local sheets_partnered   "partnered"
local sheets_retirement  "retirement"


* --- INITIALISE COMBINED OUTPUT ------------------------------------------- *

tempfile comparison_all
clear
save `comparison_all', emptyok replace

capture erase "${dir_output}/targets_old_vs_new_differences.xlsx"


* --- LOOP OVER TARGET FILES ------------------------------------------------ *

local targets "alignment_targets_disability alignment_targets_employment alignment_targets_inSchool alignment_targets_partnered_share alignment_targets_retirement"
local export_opt "replace"

foreach target of local targets {

    local sheets ""
    if "`target'" == "alignment_targets_disability" {
        local sheets "`sheets_disability'"
    }
    else if "`target'" == "alignment_targets_employment" {
        local sheets "`sheets_employment'"
    }
    else if "`target'" == "alignment_targets_inSchool" {
        local sheets "`sheets_inschool'"
    }
    else if "`target'" == "alignment_targets_partnered_share" {
        local sheets "`sheets_partnered'"
    }
    else if "`target'" == "alignment_targets_retirement" {
        local sheets "`sheets_retirement'"
    }

    foreach sheet of local sheets {

        * Read OLD workbook sheet.
        import excel using "${dir_input}/`target'OLD.xlsx", sheet("`sheet'") firstrow clear
        ds
        local vars `r(varlist)'
        local old_var : word 2 of `vars'
        keep year `old_var'
        rename `old_var' old_value
        sort year

        tempfile old_sheet
        save `old_sheet', replace

        * Read NEW workbook sheet and merge to old by year.
        import excel using "${dir_input}/`target'.xlsx", sheet("`sheet'") firstrow clear
        ds
        local vars `r(varlist)'
        local new_var : word 2 of `vars'
        keep year `new_var'
        rename `new_var' new_value
        sort year

        merge 1:1 year using `old_sheet', nogen assert(match)

        gen str40 target_file = "`target'"
        gen str32 sheet_name  = "`sheet'"
        gen double difference = new_value - old_value
        gen double pp_difference = 100 * difference
        gen double abs_pp_difference = abs(pp_difference)

        egen double max_abs_pp_in_sheet = max(abs_pp_difference)
        gen byte biggest_pp_in_sheet = abs_pp_difference == max_abs_pp_in_sheet

        order target_file sheet_name year old_value new_value difference pp_difference abs_pp_difference biggest_pp_in_sheet
        sort year
        drop max_abs_pp_in_sheet

        export excel using "${dir_output}/targets_old_vs_new_differences.xlsx", ///
            sheet("`sheet'") firstrow(variables) `export_opt'

        local export_opt "sheetmodify"

        append using `comparison_all'
        save `comparison_all', replace
    }
}


* --- SUMMARY SHEET --------------------------------------------------------- *

use `comparison_all', clear
gsort -abs_pp_difference target_file sheet_name year
gen long abs_pp_rank = _n
gen byte top10_abs_pp = abs_pp_rank <= 10

order abs_pp_rank top10_abs_pp target_file sheet_name year old_value new_value difference pp_difference abs_pp_difference biggest_pp_in_sheet

save "${dir_output}/targets_old_vs_new_differences.dta", replace

export excel using "${dir_output}/targets_old_vs_new_differences.xlsx", ///
    sheet("summary") firstrow(variables) sheetmodify
