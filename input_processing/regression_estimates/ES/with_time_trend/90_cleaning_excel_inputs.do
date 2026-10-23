****************************************************
* Clean the regression Excel workbooks in place
*
* Reads each workbook from $dir_work, where 01-10 save it, and replaces it
* there with the cleaned version:
*   - Info, Gof (if present) are copied cell by cell, unchanged
*   - model sheets: empty rows and empty columns are dropped
*   - any other sheet (e.g. E2a_raw, H1_raw) is not carried over; the raw
*     results are also saved under $dir_raw_results
* The cleaned workbook is written to a temporary file first and only then
* copied over the original, so a failure leaves the original intact.
*
* Run from 00_master_regression_estimates_ES.do, which sets $dir_work.
****************************************************
clear all
set more off

if `"$dir_work"' == "" {
    di as err "Global dir_work is not set: run this file from 00_master_regression_estimates_ES.do"
    exit 198
}

/****************************************************
* Helper: write current dataset to a sheet
*   mode replace: start a new workbook; modify: add the sheet to it
*   header: row 1 holds the column headers and the data start in row 2.
*           The headers are the variable labels, which import excel firstrow
*           sets to the original header text (the variable name if unset).
*   otherwise the data start in row 1 (sheet imported without firstrow).
* Cells are written through Mata's xl() class, so text containing quotes or
* macro characters is written as is. Empty cells are left empty.
****************************************************/
capture program drop _write_sheet
program define _write_sheet
    syntax, file(string) sheet(string) mode(string) [header]
    mata: _write_sheet_xl(`"`file'"', `"`sheet'"', "`mode'" == "replace", "`header'" != "")
end

mata:
void _write_sheet_xl(string scalar file, string scalar sheet,
                     real scalar newbook, real scalar header)
{
    class xl scalar b
    real scalar j, i, first
    string scalar h
    real colvector x
    string colvector s

    b = xl()
    if (newbook) {
        if (fileexists(file)) unlink(file)
        b.create_book(file, sheet, "xlsx")
    }
    else {
        b.load_book(file)
        b.add_sheet(sheet)
    }
    b.set_sheet(sheet)
    b.set_mode("open")

    first = header ? 2 : 1
    for (j = 1; j <= st_nvar(); j++) {
        if (header) {
            h = st_varlabel(j)
            if (h == "") h = st_varname(j)
            b.put_string(1, j, h)
        }
        if (st_isnumvar(j)) {
            x = st_data(., j)
            for (i = 1; i <= rows(x); i++) {
                if (x[i] < .) b.put_number(i + first - 1, j, x[i])
            }
        }
        else {
            s = st_sdata(., j)
            for (i = 1; i <= rows(s); i++) {
                if (s[i] != "") b.put_string(i + first - 1, j, s[i])
            }
        }
    }
    b.close_book()
}
end

/****************************************************
* USER SETTINGS
****************************************************/
local DIR "$dir_work"

local passthrough "Info Gof"

local workbooks ///
"reg_education reg_leave_parental_home reg_partnership reg_fertility reg_health reg_home_ownership reg_retirement reg_wages reg_employmentSelection reg_income reg_RMSE scenario_parametricMatching"

foreach wb of local workbooks {
    di as txt "--------------------------------------------"
    di as txt "Processing workbook: `wb'"
    di as txt "--------------------------------------------"

    local file    "`DIR'/`wb'.xlsx"
    local tmpfile "`DIR'/`wb'_cleaning_tmp.xlsx"

    capture confirm file "`file'"
    if _rc {
        di as err "WARNING: `file' not found -> skipping"
        continue
    }

    * Define model sheets for each workbook
    local models ""
    if "`wb'" == "reg_education"               local models "E1a E1b E2a"
    if "`wb'" == "reg_health"                  local models "H1 H2"
    if "`wb'" == "reg_partnership"             local models "U1 U2"
    if "`wb'" == "reg_fertility"               local models "F1"
    if "`wb'" == "reg_home_ownership"          local models "HO1"
    if "`wb'" == "reg_leave_parental_home"     local models "P1"
    if "`wb'" == "reg_retirement"              local models "R1a R1b"
    if "`wb'" == "reg_income"                  local models "I1a I1b"
    if "`wb'" == "reg_wages"                   local models "W1fa W1ma W1fb W1mb"
    if "`wb'" == "reg_employmentSelection"     local models "W1fa-sel W1ma-sel W1fb-sel W1mb-sel"
    if "`wb'" == "reg_RMSE"                    local models "RMSE"
    if "`wb'" == "scenario_parametricMatching" local models "Parameters"

    * Sheets in the workbook, and those that are not carried over
    quietly import excel using "`file'", describe
    local nsheets = r(N_worksheet)
    local sheets ""
    forvalues k = 1/`nsheets' {
        local sheets "`sheets' `r(worksheet_`k')'"
    }
    local keep "`passthrough' `models'"
    local dropped : list sheets - keep
    if "`dropped'" != "" di as txt "  Not carried over: `dropped'"

    local started = 0

    /**********************
    * A) Copy Info + Gof unchanged
    **********************/
    foreach s of local passthrough {
        local present : list s in sheets
        if !`present' {
            di as txt "  Passthrough sheet `s' not found -> skipping"
            continue
        }
        * No firstrow, so the first row is copied as data, not turned into variable names
        quietly import excel using "`file'", sheet("`s'") cellrange(A1) clear
        local mode = cond(`started', "modify", "replace")
        capture noisily _write_sheet, file("`tmpfile'") sheet("`s'") mode("`mode'")
        if _rc {
            di as err "ERROR: Could not save `tmpfile' (close Excel / check permissions). `file' left unchanged."
            capture erase "`tmpfile'"
            exit 603
        }
        local started = 1
    }

    /**********************
    * B) Clean model sheets
    **********************/
    foreach s of local models {
        local present : list s in sheets
        if !`present' {
            di as err "    -> Sheet `s' not found in `file' (skipping)"
            continue
        }
        di as txt "  Cleaning sheet: `s'"

        quietly import excel using "`file'", sheet("`s'") cellrange(A1) firstrow clear

        * Drop empty rows (strok counts non-empty strings as well as numbers)
        unab allvars : _all
        egen __nonmiss = rownonmiss(`allvars'), strok
        drop if __nonmiss == 0
        drop __nonmiss

        * Drop empty columns
        foreach v of varlist _all {
            quietly count if !missing(`v')
            if r(N) == 0 drop `v'
        }

        local mode = cond(`started', "modify", "replace")
        capture noisily _write_sheet, file("`tmpfile'") sheet("`s'") mode("`mode'") header
        if _rc {
            di as err "ERROR: Could not save `tmpfile' (close Excel / check permissions). `file' left unchanged."
            capture erase "`tmpfile'"
            exit 603
        }
        local started = 1
    }

    if `started' == 0 {
        di as err "No sheets exported for `wb' -> `file' left unchanged."
        continue
    }

    * Replace the original with the cleaned workbook
    copy "`tmpfile'" "`file'", replace
    erase "`tmpfile'"
    di as res "Done: `file'"
}

di as res "All done."
