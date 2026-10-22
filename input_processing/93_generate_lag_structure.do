/*******************************************************************************
* PROJECT:      SimPaths EU
* SECTION:      Input processing
* OBJECT:       Generate comprehensive lag-structure workbook – all processes
*
* INPUT:        input/{country}/reg_*.xlsx (the regression workbooks the model loads)
* OUTPUT FILE:  documentation/SimPaths_lag_structure_full_{country}.xlsx
*
* USAGE:        run from the repository root or from input_processing/, e.g.
*                 do input_processing/93_generate_lag_structure_full.do ES
*               Without an argument, the country in USER SETTINGS is used.
*
* SHEETS:
*   all_regressors   every individual regressor × one column per model
*   grouped          categorical dummies collapsed, one column per model
*   grouped_strict   as grouped, but rows merged only when lag patterns match
*   notes            legend / key
*   schedule_check   current-period regressors vs. the order of the schedule
*
* CODING:
*   c    current-period value (no lag prefix or suffix)
*   l    first-order lag  (_L1 suffix or L1_ prefix)
*   l2   second-order lag (_L2 suffix or L2_ prefix)
*
* COLUMNS:  one column per model, in the order of the yearly schedule
*   (documentation/SimPathsEU_ScheduleNEW.xlsx, sheet "Schedule IO disabled"):
*   R1a R1b | E1a E1b E2a | P1 | HO1 | H1 H2 |
*   W1fa W1ma W1fb W1mb W1fa_sel W1ma_sel W1fb_sel W1mb_sel | U1 U2 | F1 |
*   I1a I1b | Single_female…SingleAC_Males   (RMSE excluded)
*
* NOTES:
*   - Multi-outcome sheets (E2a → Low/Medium; H1 → Poor/Fair/Good/VeryGood/Excellent)
*     have outcome-category suffixes stripped before lag detection.
*   - Trailing lone underscores (proportional-odds shared coefficients) are stripped.
*   - Labour-supply sheets: the hours-alternative index is stripped (Liwwh_10 → Liwwh,
*     eduDehC4High_Female_23 → eduDehC4High).
*   - Interaction terms (Ded_*, Deh_c4_*_Dag, Dgn_Les_c4_*) form their own group, so
*     their lags are not attributed to the first variable in the name.
*   - reg_RMSE excluded: diagnostics only, not a behavioural process.
*   - Hyphenated sheet names (W1fa-sel etc.) stored in proc_sh_*; the corresponding
*     Stata-valid proc_key uses an underscore (W1fa_sel).
*
* AUTHOR:       SimPaths team
* LAST UPDATE:  2026-10-21
*******************************************************************************/

version 15.1
args country_arg
clear all
set more off

/*============================================================================
  USER SETTINGS
============================================================================*/
local country "ES"              // used when no country is passed as an argument
if "`country_arg'" != "" local country = upper("`country_arg'")

* Repository root: the current directory, or its parent when run from input_processing/
local ROOT_DIR "`c(pwd)'"
capture confirm file "`ROOT_DIR'/input/DatabaseCountryYear.xlsx"
if _rc {
    local ROOT_DIR "`c(pwd)'/.."
    capture confirm file "`ROOT_DIR'/input/DatabaseCountryYear.xlsx"
    if _rc {
        di as err "Run this do-file from the repository root or from input_processing/."
        exit 601
    }
}
local INPUT_DIR   "`ROOT_DIR'/input/`country'"
local OUTPUT_FILE "`ROOT_DIR'/documentation/SimPaths_lag_structure_`country'.xlsx"

di as txt "Country: `country'" _n "Input:   `INPUT_DIR'" _n "Output:  `OUTPUT_FILE'"


/*============================================================================
  HELPERS
============================================================================*/

* Integer column number → Excel column letter(s)  (1=A, 27=AA …)
program define __col2xl, rclass
    version 15.1
    syntax, NUM(integer)
    local n = `num'
    local col ""
    while `n' > 0 {
        local rem = mod(`n' - 1, 26)
        local col = char(65 + `rem') + "`col'"
        local n   = floor((`n' - 1) / 26)
    }
    return local col "`col'"
end

* Label, canonical code and display tier of one regressor group (grouped sheets)
program define __grp
    version 15.1
    syntax, group(string) label(string) code(string) tier(integer)
    quietly replace grp_label = "`label'" if grp_var == "`group'"
    quietly replace grp_code  = "`code'"  if grp_var == "`group'"
    quietly replace grp_sort  = `tier'    if grp_var == "`group'"
end

* Schedule position of the models consuming a regressor (schedule_check)
program define __cons
    version 15.1
    syntax, keys(string) step(integer) seq(integer) module(string)
    foreach k of local keys {
        quietly replace consumer_step   = `step'     if proc_key == "`k'"
        quietly replace consumer_seq    = `seq'      if proc_key == "`k'"
        quietly replace consumer_module = "`module'" if proc_key == "`k'"
    }
end

* Schedule position of the process producing a regressor (schedule_check)
program define __prod
    version 15.1
    syntax if, step(integer) seq(integer) proc(string) module(string)
    quietly replace producer_step   = `step'     `if'
    quietly replace producer_seq    = `seq'      `if'
    quietly replace producer_proc   = "`proc'"   `if'
    quietly replace producer_module = "`module'" `if'
end


/*============================================================================
  PROCESS (COLUMN) DEFINITIONS
  One column per individual model, in the order of the yearly schedule.
  proc_key  = Stata-valid name (no hyphens)
  proc_sh_* = actual Excel sheet name (may differ: W1fa_sel → "W1fa-sel")
  proc_wb_* = workbook filename without .xlsx
  proc_desc_* = short description for header row
  proc_cats_* = outcome-category suffixes to strip (multi-outcome sheets)
============================================================================*/

* Ordered list of process keys (Stata-valid names), following the schedule
local proc_keys ///
    R1a R1b ///
    E1a E1b E2a ///
    P1 ///
    HO1 ///
    H1 H2 ///
    W1fa W1ma W1fb W1mb ///
    W1fa_sel W1ma_sel W1fb_sel W1mb_sel ///
    U1 U2 ///
    F1 ///
    I1a I1b ///
    Single_female Single_male SingleDep_Females SingleDep_Males ///
    Couples SingleAC_Females SingleAC_Males

* Labour-supply utility sheets (regressors indexed by hours alternative)
local ls_keys Single_female Single_male SingleDep_Females SingleDep_Males ///
    Couples SingleAC_Females SingleAC_Males

* ---- Workbooks ----
local proc_wb_P1                reg_leave_parental_home
local proc_wb_R1a               reg_retirement
local proc_wb_R1b               reg_retirement
local proc_wb_E1a               reg_education
local proc_wb_E1b               reg_education
local proc_wb_E2a               reg_education
local proc_wb_HO1               reg_home_ownership
local proc_wb_H1                reg_health
local proc_wb_H2                reg_health
local proc_wb_W1fa              reg_wages
local proc_wb_W1ma              reg_wages
local proc_wb_W1fb              reg_wages
local proc_wb_W1mb              reg_wages
local proc_wb_U1                reg_partnership
local proc_wb_U2                reg_partnership
local proc_wb_F1                reg_fertility
local proc_wb_Single_female     reg_labourSupplyUtility
local proc_wb_Single_male       reg_labourSupplyUtility
local proc_wb_SingleDep_Females reg_labourSupplyUtility
local proc_wb_SingleDep_Males   reg_labourSupplyUtility
local proc_wb_Couples           reg_labourSupplyUtility
local proc_wb_SingleAC_Females  reg_labourSupplyUtility
local proc_wb_SingleAC_Males    reg_labourSupplyUtility
local proc_wb_I1a               reg_income
local proc_wb_I1b               reg_income
local proc_wb_W1fa_sel          reg_employmentSelection
local proc_wb_W1ma_sel          reg_employmentSelection
local proc_wb_W1fb_sel          reg_employmentSelection
local proc_wb_W1mb_sel          reg_employmentSelection

* ---- Actual sheet names within each workbook ----
local proc_sh_P1                P1
local proc_sh_R1a               R1a
local proc_sh_R1b               R1b
local proc_sh_E1a               E1a
local proc_sh_E1b               E1b
local proc_sh_E2a               E2a
local proc_sh_HO1               HO1
local proc_sh_H1                H1
local proc_sh_H2                H2
local proc_sh_W1fa              W1fa
local proc_sh_W1ma              W1ma
local proc_sh_W1fb              W1fb
local proc_sh_W1mb              W1mb
local proc_sh_U1                U1
local proc_sh_U2                U2
local proc_sh_F1                F1
local proc_sh_Single_female     Single_female
local proc_sh_Single_male       Single_male
local proc_sh_SingleDep_Females SingleDep_Females
local proc_sh_SingleDep_Males   SingleDep_Males
local proc_sh_Couples           Couples
local proc_sh_SingleAC_Females  SingleAC_Females
local proc_sh_SingleAC_Males    SingleAC_Males
local proc_sh_I1a               I1a
local proc_sh_I1b               I1b
local proc_sh_W1fa_sel          W1fa-sel
local proc_sh_W1ma_sel          W1ma-sel
local proc_sh_W1fb_sel          W1fb-sel
local proc_sh_W1mb_sel          W1mb-sel

* ---- Dependent variable title (header row 2 – "dependent variable") ----
local proc_dv_title_P1                "exited parental home"
local proc_dv_title_R1a               "enter retirement"
local proc_dv_title_R1b               "retired"
local proc_dv_title_E1a               "in continuous education"
local proc_dv_title_E1b               "return to education"
local proc_dv_title_E2a               "education level"
local proc_dv_title_HO1               "home ownership"
local proc_dv_title_H1                "health status"
local proc_dv_title_H2                "long-term sick or disabled"
local proc_dv_title_W1fa              "potential wage"
local proc_dv_title_W1ma              "potential wage"
local proc_dv_title_W1fb              "potential wage"
local proc_dv_title_W1mb              "potential wage"
local proc_dv_title_U1                "enter partnership"
local proc_dv_title_U2                "exit partnership"
local proc_dv_title_F1                "fertility"
local proc_dv_title_Single_female     "weekly labour supply"
local proc_dv_title_Single_male       "weekly labour supply"
local proc_dv_title_SingleDep_Females "weekly labour supply"
local proc_dv_title_SingleDep_Males   "weekly labour supply"
local proc_dv_title_Couples           "weekly labour supply"
local proc_dv_title_SingleAC_Females  "weekly labour supply"
local proc_dv_title_SingleAC_Males    "weekly labour supply"
local proc_dv_title_I1a               "capital income"
local proc_dv_title_I1b               "capital income"
local proc_dv_title_W1fa_sel          "employment selection"
local proc_dv_title_W1ma_sel          "employment selection"
local proc_dv_title_W1fb_sel          "employment selection"
local proc_dv_title_W1mb_sel          "employment selection"

* ---- Dependent variable code (header row 3 – "code") ----
local proc_dv_code_P1                "dlftphm"
local proc_dv_code_R1a               "drtren"
local proc_dv_code_R1b               "dlrtrd"
local proc_dv_code_E1a               "ded"
local proc_dv_code_E1b               "der"
local proc_dv_code_E2a               "deh_c3"
local proc_dv_code_HO1               "dhh_owned"
local proc_dv_code_H1                "dhe"
local proc_dv_code_H2                "dlltsd"
local proc_dv_code_W1fa              "fullTimeHourlyEarningsPotential"
local proc_dv_code_W1ma              "fullTimeHourlyEarningsPotential"
local proc_dv_code_W1fb              "fullTimeHourlyEarningsPotential"
local proc_dv_code_W1mb              "fullTimeHourlyEarningsPotential"
local proc_dv_code_U1                "dcpen"
local proc_dv_code_U2                "dcpex"
local proc_dv_code_F1                "dnc"
local proc_dv_code_Single_female     "labourSupplyWeekly"
local proc_dv_code_Single_male       "labourSupplyWeekly"
local proc_dv_code_SingleDep_Females "labourSupplyWeekly"
local proc_dv_code_SingleDep_Males   "labourSupplyWeekly"
local proc_dv_code_Couples           "labourSupplyWeekly"
local proc_dv_code_SingleAC_Females  "labourSupplyWeekly"
local proc_dv_code_SingleAC_Males    "labourSupplyWeekly"
local proc_dv_code_I1a               "ypncp"
local proc_dv_code_I1b               "ypncp"
local proc_dv_code_W1fa_sel          "lowWageOffer"
local proc_dv_code_W1ma_sel          "lowWageOffer"
local proc_dv_code_W1fb_sel          "lowWageOffer"
local proc_dv_code_W1mb_sel          "lowWageOffer"

* ---- Process descriptions (shown in header row 1) ----
local proc_desc_P1                "Leaving parental home"
local proc_desc_R1a               "Retirement decision"
local proc_desc_R1b               "Retirement decision"
local proc_desc_E1a               "Remaining in education"
local proc_desc_E1b               "Returning to education"
local proc_desc_E2a               "Education attainment"
local proc_desc_HO1               "Home ownership"
local proc_desc_H1                "Health transitions"
local proc_desc_H2                "Disability"
local proc_desc_W1fa              "Wage - female FT"
local proc_desc_W1ma              "Wage - male FT"
local proc_desc_W1fb              "Wage - female PT"
local proc_desc_W1mb              "Wage - male PT"
local proc_desc_U1                "Partnership entry"
local proc_desc_U2                "Partnership exit"
local proc_desc_F1                "Fertility"
local proc_desc_Single_female     "Labour supply - single female"
local proc_desc_Single_male       "Labour supply - single male"
local proc_desc_SingleDep_Females "Labour supply - single dep. female"
local proc_desc_SingleDep_Males   "Labour supply - single dep. male"
local proc_desc_Couples           "Labour supply - couple"
local proc_desc_SingleAC_Females  "Labour supply - single AC female"
local proc_desc_SingleAC_Males    "Labour supply - single AC male"
local proc_desc_I1a               "Income process (capital)"
local proc_desc_I1b               "Income process (capital, alt.)"
local proc_desc_W1fa_sel          "Emp. selection - female FT"
local proc_desc_W1ma_sel          "Emp. selection - male FT"
local proc_desc_W1fb_sel          "Emp. selection - female PT"
local proc_desc_W1mb_sel          "Emp. selection - male PT"

* ---- Outcome-category suffixes to strip (multi-outcome sheets; empty = none) ----
local proc_cats_E2a               Low Medium
local proc_cats_H1                Poor Fair Good VeryGood Excellent


/*============================================================================
  COLLECTION PHASE
  Read each model sheet; extract regressor names from column A; post triples
  (base_var, proc_key, lag_status) to a postfile.
============================================================================*/
tempname ph
tempfile ph_data

postfile `ph' str80 base_var str32 proc_key str4 lag_status ///
    using `ph_data', replace

foreach pk of local proc_keys {

    local wb    "`proc_wb_`pk''"
    local sh    "`proc_sh_`pk''"
    local cats  "`proc_cats_`pk''"
    local is_ls : list pk in ls_keys

    local infile "`INPUT_DIR'/`wb'.xlsx"
    capture confirm file "`infile'"
    if _rc {
        di as err "  [SKIP] Workbook not found: `infile'"
        continue
    }

    di as txt "Processing `wb' / `sh'  [proc: `pk']"

    capture noisily import excel "`infile'", sheet("`sh'") firstrow clear
    if _rc {
        di as err "  [SKIP] Cannot read sheet `sh' from `infile'"
        continue
    }

    * First column = REGRESSOR names
    quietly ds
    local rvar = word("`r(varlist)'", 1)

    quietly count
    local nrows = r(N)

    forvalues i = 1/`nrows' {

        local raw = strtrim(`rvar'[`i'])
        if "`raw'" == "" continue

        * Skip metadata / header rows
        local lraw = lower("`raw'")
        if regexm("`lraw'", "^(constant|regressor|coefficient)") continue
        if "`lraw'" == "." continue

        * ---- Strip outcome-category suffix (multi-outcome sheets only) ----
        local s "`raw'"
        foreach cat of local cats {
            if regexm("`s'", "_`cat'$") {
                local s = regexr("`s'", "_`cat'$", "")
            }
        }

        * Strip trailing lone underscore (shared proportional-odds coefficients)
        if regexm("`s'", "_$") local s = regexr("`s'", "_$", "")

        * ---- Labour-supply sheets: strip the hours-alternative index ----
        *      Liwwh_10 -> Liwwh;  eduDehC4High_Female_23 -> eduDehC4High
        if `is_ls' & regexm("`s'", "_[0-9]+$") {
            local s = regexr("`s'", "_[0-9]+$", "")
            local s = regexr("`s'", "_(Male|Female)$", "")
        }

        * ---- Determine lag status from suffix (X_L1) or prefix (L1_X) ----
        local base "`s'"
        local lag  "c"
        if regexm("`s'", "_L2$") {
            local lag  "l2"
            local base = regexr("`s'", "_L2$", "")
        }
        else if regexm("`s'", "_L1$") {
            local lag  "l"
            local base = regexr("`s'", "_L1$", "")
        }
        else if regexm("`s'", "^L2_") {
            local lag  "l2"
            local base = regexr("`s'", "^L2_", "")
        }
        else if regexm("`s'", "^L1_") {
            local lag  "l"
            local base = regexr("`s'", "^L1_", "")
        }

        if "`base'" == "" continue

        post `ph' ("`base'") ("`pk'") ("`lag'")
    }
}

postclose `ph'

di as txt _n "Collection complete."


/*============================================================================
  AGGREGATE
  For each (base_var, proc_key) pair, merge all observed lag statuses into a
  combined string: c, l, l2, c,l, c,l2, l,l2, or c,l,l2.
============================================================================*/
use `ph_data', clear

* Deduplicate exact triples
duplicates drop base_var proc_key lag_status, force

* Indicator variables for each lag type
gen byte has_c  = (lag_status == "c")
gen byte has_l  = (lag_status == "l")
gen byte has_l2 = (lag_status == "l2")

* Collapse: one row per (base_var, proc_key)
collapse (max) has_c has_l has_l2, by(base_var proc_key)

* Build combined lag string (c first, then l, then l2)
gen str8 combined_lag = ""
replace combined_lag = "c"       if has_c==1 & has_l==0 & has_l2==0
replace combined_lag = "l"       if has_c==0 & has_l==1 & has_l2==0
replace combined_lag = "l2"      if has_c==0 & has_l==0 & has_l2==1
replace combined_lag = "c,l"     if has_c==1 & has_l==1 & has_l2==0
replace combined_lag = "c,l2"    if has_c==1 & has_l==0 & has_l2==1
replace combined_lag = "l,l2"    if has_c==0 & has_l==1 & has_l2==1
replace combined_lag = "c,l,l2"  if has_c==1 & has_l==1 & has_l2==1

drop has_c has_l has_l2

* Reshape to wide: one column per proc_key
reshape wide combined_lag, i(base_var) j(proc_key) string

* Ensure all proc_key columns exist (fill with empty if absent)
foreach pk of local proc_keys {
    capture confirm variable combined_lag`pk'
    if _rc gen str8 combined_lag`pk' = ""
    replace combined_lag`pk' = "" if combined_lag`pk' == "."
}

* Rename to lag_{proc_key}
foreach pk of local proc_keys {
    rename combined_lag`pk' lag_`pk'
}

gen str80 bv_upper = upper(base_var)

* Interaction terms: an education/gender variable combined with a second variable
gen byte is_inter = regexm(bv_upper, "^(DED|DEH_C4_[A-Z]+|DGN)_(DAG|DGN|DHE|DEHSP|DCPST|YPNCP|LN_YPNCP|YDSES|LES_C|DNC)")

/*---- Sort rows by meaningful display order ---------------------------------
  sort_grp 1: core person characteristics
  sort_grp 2: income / wealth / wage / labour-supply variables
  sort_grp 3: macro / time controls
  sort_grp 9: anything else (alphabetical)
---------------------------------------------------------------------------*/
gen byte sort_grp = 9

* Core characteristics
replace sort_grp = 1 if regexm(bv_upper, "^(DGN|DGNSP)")
replace sort_grp = 1 if regexm(bv_upper, "^(DAG|DAGSQ|RCS)")
replace sort_grp = 1 if regexm(bv_upper, "^(DED|DER|DEH|DEHM|DEHF|DEHSP|EDUDEHC4)")
replace sort_grp = 1 if regexm(bv_upper, "^(DCPST|DHHTP|DCPYY|DCPAGDF|NEW_REL)")
replace sort_grp = 1 if regexm(bv_upper, "^(DNC|D_CHILDREN)")
replace sort_grp = 1 if regexm(bv_upper, "^(DHE|DHM|DHMGHQ|GHQ|DLLTSD|HEALTHSELFRATED)")
replace sort_grp = 1 if regexm(bv_upper, "^(LES_C|LESSP|LESDF|REACHED_RETIREMENT|ELIG_PEN)") | bv_upper == "PT"
replace sort_grp = 1 if regexm(bv_upper, "^PARENTS_")

* Income / wealth / wages / labour-supply terms
replace sort_grp = 2 if regexm(bv_upper, "^(YDSES|YPNBIHS|YPTCIIHS|INCOMEDIV|INCOMESQDIV|YNBCPDF)")
replace sort_grp = 2 if regexm(bv_upper, "^(YPLGRS|YPNCP|LN_YPNCP|YPNOAB)")
replace sort_grp = 2 if regexm(bv_upper, "^(LOG_HOURLY|FULLTIMEHOURLY|LIWW|INVMILLSRATIO|INVERSEMILLSRATIO)")
replace sort_grp = 2 if regexm(bv_upper, "^(MALELEISURE|FEMALELEISURE|HRS_40PLUS|FULLFIXEDCOST|PARTFIXEDCOST)")
replace sort_grp = 2 if regexm(bv_upper, "^(DHH_OWN|DHHOWN)")

* Macro / time controls
replace sort_grp = 3 if regexm(bv_upper, "^(PL|EL|IT|HU|ES)[0-9]")
replace sort_grp = 3 if regexm(bv_upper, "^Y[0-9][0-9][0-9][0-9]$")
replace sort_grp = 3 if regexm(bv_upper, "^(YEAR_TRANSFORMED|POST2015|POST2020|FERTILITYRATE|REALWAGEGROWTH)")

sort sort_grp base_var

* ---- Covariate description for col B of all_regressors ----
gen str160 bv_desc = ""
replace bv_desc = "Gender (1=male)"                         if bv_upper == "DGN"
replace bv_desc = "Spouse gender"                           if bv_upper == "DGNSP"
replace bv_desc = "Age (years)"                             if bv_upper == "DAG"
replace bv_desc = "Age squared"                             if inlist(bv_upper, "DAGSQ", "DAG_SQ")
replace bv_desc = "Age spline knot"                         if regexm(bv_upper, "^DAG_KNOT")
replace bv_desc = "Age indicator"                           if regexm(bv_upper, "^DAG[0-9]")
replace bv_desc = "Age restricted cubic spline"             if regexm(bv_upper, "^RCS")
replace bv_desc = "In education"                            if bv_upper == "DED"
replace bv_desc = "Returned to education"                   if bv_upper == "DER"
replace bv_desc = "Education level category"                if regexm(bv_upper, "^DEH_C")
replace bv_desc = "Spouse education level"                  if regexm(bv_upper, "^DEHSP")
replace bv_desc = "Mother's education level"                if regexm(bv_upper, "^DEHM")
replace bv_desc = "Father's education level"                if regexm(bv_upper, "^DEHF")
replace bv_desc = "Education level x hours alternative"     if regexm(bv_upper, "^EDUDEHC4")
replace bv_desc = "Partnership status category"             if regexm(bv_upper, "^DCPST")
replace bv_desc = "Household type"                          if regexm(bv_upper, "^DHHTP")
replace bv_desc = "Years since partnership formed"          if regexm(bv_upper, "^DCPYY")
replace bv_desc = "Age difference from partner"             if regexm(bv_upper, "^DCPAGDF")
replace bv_desc = "New relationship indicator"              if regexm(bv_upper, "^NEW_REL")
replace bv_desc = "Number of children"                      if regexm(bv_upper, "^DNC")
replace bv_desc = "Children present"                        if regexm(bv_upper, "^D_CHILDREN")
replace bv_desc = "Health status (1=Poor to 5=Excellent)"   if bv_upper == "DHE"
replace bv_desc = "Health status category"                  if regexm(bv_upper, "^DHE_")
replace bv_desc = "Spouse health status"                    if regexm(bv_upper, "^DHESP")
replace bv_desc = "Self-rated health x hours alternative"   if regexm(bv_upper, "^HEALTHSELFRATED")
replace bv_desc = "Mental health (GHQ score)"               if regexm(bv_upper, "^(DHM|DHMGHQ|GHQ)")
replace bv_desc = "Long-term sick or disabled"              if regexm(bv_upper, "^DLLTSD")
replace bv_desc = "Spouse long-term sick or disabled"       if regexm(bv_upper, "^DLLTSDSP")
replace bv_desc = "Activity status category"                if regexm(bv_upper, "^LES_C")
replace bv_desc = "Spouse activity status"                  if regexm(bv_upper, "^LESSP")
replace bv_desc = "Activity status of couple"               if regexm(bv_upper, "^LESDF")
replace bv_desc = "Reached statutory retirement age"        if regexm(bv_upper, "^REACHED_RETIREMENT")
replace bv_desc = "Eligible for state pension"              if regexm(bv_upper, "^ELIG_PEN")
replace bv_desc = "Co-resident parents' income quintile"    if regexm(bv_upper, "^PARENTS_YPNB")
replace bv_desc = "Co-resident parent known"                if bv_upper == "PARENTS_KNOWN"
replace bv_desc = "Parent known x household income quintile" if regexm(bv_upper, "^PARENTS_KNOWN_YDSES")
replace bv_desc = "Household income quintile"               if regexm(bv_upper, "^YDSES")
replace bv_desc = "Household non-benefit income"            if regexm(bv_upper, "^YPNBIHS")
replace bv_desc = "Total capital + transfer income (hh)"    if regexm(bv_upper, "^YPTCIIHS")
replace bv_desc = "Non-benefit income difference (couple)"  if regexm(bv_upper, "^YNBCPDF")
replace bv_desc = "Disposable income at hours alternative"  if regexm(bv_upper, "^INCOMEDIV")
replace bv_desc = "Disposable income at hours alternative, squared" if regexm(bv_upper, "^INCOMESQDIV")
replace bv_desc = "Employment income – gross"               if regexm(bv_upper, "^YPLGRS")
replace bv_desc = "Capital income"                          if regexm(bv_upper, "^YPNCP")
replace bv_desc = "Capital income (log)"                    if regexm(bv_upper, "^LN_YPNCP")
replace bv_desc = "Pension / old-age benefit income"        if regexm(bv_upper, "^YPNOAB")
replace bv_desc = "Years in employment (work experience)"   if bv_upper == "LIWWH"
replace bv_desc = "Years in employment, squared"            if bv_upper == "LIWWHSQ"
replace bv_desc = "Leisure at hours alternative"            if regexm(bv_upper, "^(MALELEISURE|FEMALELEISURE)")
replace bv_desc = "Works 40+ hours at alternative"          if regexm(bv_upper, "^HRS_40PLUS")
replace bv_desc = "Part-time (weekly hours below full-time)" if bv_upper == "PT"
replace bv_desc = "Fixed cost of work at alternative"       if regexm(bv_upper, "^(FULLFIXEDCOST|PARTFIXEDCOST)")
replace bv_desc = "Log potential hourly wage"               if regexm(bv_upper, "^LOG_HOURLY")
replace bv_desc = "Potential full-time hourly wage"         if regexm(bv_upper, "^FULLTIMEHOURLY")
replace bv_desc = "Inverse Mills ratio (from W1*-sel)"      if inlist(bv_upper, "INVMILLSRATIO", "INVERSEMILLSRATIO")
replace bv_desc = "Home owner"                              if regexm(bv_upper, "^(DHH_OWN|DHHOWN)")
replace bv_desc = "Region (NUTS level 1)"                   if regexm(bv_upper, "^(PL|EL|IT|HU|ES)[0-9]")
replace bv_desc = "Year"                                    if regexm(bv_upper, "^Y[0-9][0-9][0-9][0-9]$")
replace bv_desc = "Time trend"                              if regexm(bv_upper, "^YEAR_TRANSFORMED")
replace bv_desc = "Post-2015 indicator"                     if regexm(bv_upper, "^POST2015")
replace bv_desc = "Post-2020 indicator"                     if regexm(bv_upper, "^POST2020")
replace bv_desc = "Fertility rate (macro)"                  if regexm(bv_upper, "^FERTILITYRATE")
replace bv_desc = "Real wage growth (macro)"                if regexm(bv_upper, "^REALWAGEGROWTH")
replace bv_desc = "Interaction term"                        if is_inter

drop bv_upper sort_grp

* Save for both sheets
tempfile wide_data
save `wide_data'


/*============================================================================
  WRITE SHEET 1: all_regressors
  Col A : covariate code  (regressor base name, e.g. Deh_c4_Low)
  Col B : covariate name  (human-readable description)
  Col C : row-type label in header rows; "process" label in row 4
  Cols D+: one column per model, in schedule order

  Header layout (4 rows):
    Row 1 – A="", B="", C="process group",      D+=process description
    Row 2 – A="", B="", C="dependent variable", D+=dep-var title
    Row 3 – A="", B="", C="code",               D+=dep-var code
    Row 4 – A="covariate code", B="covariate name", C="process", D+=model code
    Row 5+ – data
============================================================================*/
di as txt _n "Writing sheet: all_regressors"

putexcel set "`OUTPUT_FILE'", sheet("all_regressors") replace

* ---- Row 1 (process group name) ----
putexcel A1 = ""
putexcel B1 = ""
putexcel C1 = "process group", bold

* ---- Row 2 (dependent variable title) ----
putexcel A2 = ""
putexcel B2 = ""
putexcel C2 = "dependent variable", bold

* ---- Row 3 (dependent variable code) ----
putexcel A3 = ""
putexcel B3 = ""
putexcel C3 = "code", bold

* ---- Row 4 (model / process code) ----
putexcel A4 = "covariate code", bold
putexcel B4 = "covariate name", bold
putexcel C4 = "process",        bold

local cnum = 4
foreach pk of local proc_keys {
    __col2xl, num(`cnum')
    local xlc "`r(col)'"
    putexcel `xlc'1 = "`proc_desc_`pk''"
    putexcel `xlc'2 = "`proc_dv_title_`pk''"
    putexcel `xlc'3 = "`proc_dv_code_`pk''"
    putexcel `xlc'4 = "`pk'", bold
    local ++cnum
}

* ---- Data rows (start at row 5) ----
local nobs = _N
forvalues r = 1/`nobs' {
    local rnum = `r' + 4
    putexcel A`rnum' = base_var[`r']
    local desc = bv_desc[`r']
    if "`desc'" != "" & "`desc'" != "." putexcel B`rnum' = "`desc'"

    local cnum = 4
    foreach pk of local proc_keys {
        __col2xl, num(`cnum')
        local xlc "`r(col)'"
        local val = lag_`pk'[`r']
        if "`val'" != "" & "`val'" != "." {
            putexcel `xlc'`rnum' = "`val'"
        }
        local ++cnum
    }
}

di as txt "  → `nobs' regressors written."


/*============================================================================
  PREPARE GROUPED DATA
  Assign each regressor to a conceptual group (rules below, applied to the
  upper-cased base_var), then aggregate lag statuses within each
  (group × proc_key). Variables matching no rule stay as their own row.
  Interaction terms are assigned last, so they never fall into the group of
  their first component.
============================================================================*/
use `wide_data', clear

gen str80 bv_upper  = upper(base_var)
gen str80 grp_var   = base_var
gen str80 grp_label = base_var
replace grp_label = bv_desc if bv_desc != ""

replace grp_var = "age"                if regexm(bv_upper, "^(DAG|DAGSQ|RCS)")
replace grp_var = "gender"             if inlist(bv_upper, "DGN", "DGNSP")
replace grp_var = "education"          if regexm(bv_upper, "^(DED|DER|DEH_C|EDUDEHC4)")
replace grp_var = "spouse_education"   if regexm(bv_upper, "^DEHSP")
replace grp_var = "maternal_education" if regexm(bv_upper, "^DEHM")
replace grp_var = "paternal_education" if regexm(bv_upper, "^DEHF")
replace grp_var = "partnership_status" if regexm(bv_upper, "^(DCPST|DHHTP|DCPYY|DCPAGDF|NEW_REL)")
replace grp_var = "children"           if regexm(bv_upper, "^(DNC|D_CHILDREN)")
replace grp_var = "health_status"      if regexm(bv_upper, "^(DHE|HEALTHSELFRATED)")
replace grp_var = "mental_health"      if regexm(bv_upper, "^(DHM|DHMGHQ|GHQ)")
replace grp_var = "disability"         if regexm(bv_upper, "^DLLTSD")
replace grp_var = "activity_status"    if regexm(bv_upper, "^(LES_C|LESSP|LESDF)") | bv_upper == "PT"
replace grp_var = "retirement_age"     if regexm(bv_upper, "^(REACHED_RETIREMENT|ELIG_PEN)")
replace grp_var = "parents"            if regexm(bv_upper, "^PARENTS_")
replace grp_var = "ses_income"         if regexm(bv_upper, "^(YDSES|YPNBIHS|YPTCIIHS|YNBCPDF)")
replace grp_var = "employment_income"  if regexm(bv_upper, "^YPLGRS")
replace grp_var = "capital_income"     if regexm(bv_upper, "^(YPNCP|LN_YPNCP)")
replace grp_var = "pension_income"     if regexm(bv_upper, "^YPNOAB")
replace grp_var = "experience"         if regexm(bv_upper, "^LIWW")
replace grp_var = "potential_wage"     if regexm(bv_upper, "^(LOG_HOURLY|FULLTIMEHOURLY)")
replace grp_var = "mills_ratio"        if inlist(bv_upper, "INVMILLSRATIO", "INVERSEMILLSRATIO")
replace grp_var = "ls_income"          if regexm(bv_upper, "^(INCOMEDIV|INCOMESQDIV)")
replace grp_var = "ls_alternative"     if regexm(bv_upper, "^(MALELEISURE|FEMALELEISURE|HRS_40PLUS|FULLFIXEDCOST|PARTFIXEDCOST)")
replace grp_var = "home_ownership"     if regexm(bv_upper, "^(DHH_OWN|DHHOWN)")
replace grp_var = "region"             if regexm(bv_upper, "^(PL|EL|IT|HU|ES)[0-9]")
replace grp_var = "year"               if regexm(bv_upper, "^Y[0-9][0-9][0-9][0-9]$")
replace grp_var = "year"               if regexm(bv_upper, "^(YEAR_TRANSFORMED|POST2015|POST2020|FERTILITYRATE|REALWAGEGROWTH)")
replace grp_var = "interaction"        if is_inter

* Group label, canonical SimPaths code (col A of the grouped sheets) and display tier
* (1 person characteristics, 2 income / wages / labour supply, 3 macro, 4 interactions,
*  9 ungrouped variables)
gen str80 grp_code = base_var
gen byte  grp_sort = 9
__grp, group(gender)             label("Gender")                                      code(dgn)                             tier(1)
__grp, group(age)                label("Age")                                         code(dag)                             tier(1)
__grp, group(education)          label("Education (in education, level)")             code(deh)                             tier(1)
__grp, group(spouse_education)   label("Spouse education")                            code(dehsp)                           tier(1)
__grp, group(maternal_education) label("Maternal education")                          code(dehm)                            tier(1)
__grp, group(paternal_education) label("Paternal education")                          code(dehf)                            tier(1)
__grp, group(partnership_status) label("Partnership status / household type")         code(dcpst)                           tier(1)
__grp, group(children)           label("Children")                                    code(dnc)                             tier(1)
__grp, group(health_status)      label("Health status")                               code(dhe)                             tier(1)
__grp, group(mental_health)      label("Mental health")                               code(dhm)                             tier(1)
__grp, group(disability)         label("Disability status")                           code(dlltsd)                          tier(1)
__grp, group(activity_status)    label("Activity status")                             code(les_c4)                          tier(1)
__grp, group(retirement_age)     label("Retirement age / pension eligibility")        code(elig_pen)                        tier(1)
__grp, group(parents)            label("Co-resident parents (known, income quintile)") code(parents_ypnb)                   tier(1)
__grp, group(ses_income)         label("Household income / SES")                      code(ydses_c5)                        tier(2)
__grp, group(employment_income)  label("Employment income")                           code(yplgrs)                          tier(2)
__grp, group(capital_income)     label("Capital income")                              code(ypncp)                           tier(2)
__grp, group(pension_income)     label("Pension income")                              code(ypnoab)                          tier(2)
__grp, group(experience)         label("Years in employment")                         code(liwwh)                           tier(2)
__grp, group(potential_wage)     label("Potential wage")                              code(fullTimeHourlyEarningsPotential) tier(2)
__grp, group(mills_ratio)        label("Inverse Mills ratio (employment selection)")  code(InvMillsRatio)                   tier(2)
__grp, group(ls_income)          label("Disposable income at hours alternative")      code(IncomeDiv100)                    tier(2)
__grp, group(ls_alternative)     label("Leisure / hours / fixed costs at alternative") code(leisure)                        tier(2)
__grp, group(home_ownership)     label("Home owner")                                  code(dhh_owned)                       tier(2)
__grp, group(region)             label("Region")                                      code(drgn1)                           tier(3)
__grp, group(year)               label("Year / time trend")                           code(stm)                             tier(3)
__grp, group(interaction)        label("Interaction terms")                           code(interactions)                    tier(4)

drop bv_upper

* Save pre-collapse snapshot; used later for the strict-grouped sheet
tempfile grpraw_data
save `grpraw_data'

/*---- Aggregate: one row per (grp_var × proc_key) -------------------------
  Convert each lag_{pk} string to binary indicators, collapse with max,
  then rebuild the combined lag string.
---------------------------------------------------------------------------*/
foreach pk of local proc_keys {
    gen byte g_c_`pk'  = strpos(lag_`pk', "c")  > 0
    gen byte g_l_`pk'  = inlist(lag_`pk', "l", "c,l", "l,l2", "c,l,l2")
    gen byte g_l2_`pk' = strpos(lag_`pk', "l2") > 0
    drop lag_`pk'
}

collapse (max) g_c_* g_l_* g_l2_* (firstnm) grp_label grp_code grp_sort, by(grp_var)

foreach pk of local proc_keys {
    gen str8 grp_lag_`pk' = ""
    replace grp_lag_`pk' = "c"       if g_c_`pk'==1 & g_l_`pk'==0 & g_l2_`pk'==0
    replace grp_lag_`pk' = "l"       if g_c_`pk'==0 & g_l_`pk'==1 & g_l2_`pk'==0
    replace grp_lag_`pk' = "l2"      if g_c_`pk'==0 & g_l_`pk'==0 & g_l2_`pk'==1
    replace grp_lag_`pk' = "c,l"     if g_c_`pk'==1 & g_l_`pk'==1 & g_l2_`pk'==0
    replace grp_lag_`pk' = "c,l2"    if g_c_`pk'==1 & g_l_`pk'==0 & g_l2_`pk'==1
    replace grp_lag_`pk' = "l,l2"    if g_c_`pk'==0 & g_l_`pk'==1 & g_l2_`pk'==1
    replace grp_lag_`pk' = "c,l,l2"  if g_c_`pk'==1 & g_l_`pk'==1 & g_l2_`pk'==1
    drop g_c_`pk' g_l_`pk' g_l2_`pk'
}

sort grp_sort grp_var

tempfile grouped_data
save `grouped_data'


/*============================================================================
  WRITE SHEET 2: grouped
  Col A : covariate code  (canonical SimPaths variable name, e.g. deh, dag)
  Col B : covariate name  (human-readable group label)
  Col C : row-type label in header rows; "process" label in row 4
  Cols D+: one column per model

  Header layout (4 rows):
    Row 1 – A="", B="", C="process group",      D+=process description
    Row 2 – A="", B="", C="dependent variable", D+=dep-var title
    Row 3 – A="", B="", C="code",               D+=dep-var code
    Row 4 – A="covariate code", B="covariate name", C="process", D+=model code
    Row 5+ – data
============================================================================*/
di as txt _n "Writing sheet: grouped"

putexcel set "`OUTPUT_FILE'", sheet("grouped") modify

* ---- Row 1 (process group name) ----
putexcel A1 = ""
putexcel B1 = ""
putexcel C1 = "process group", bold

* ---- Row 2 (dependent variable title) ----
putexcel A2 = ""
putexcel B2 = ""
putexcel C2 = "dependent variable", bold

* ---- Row 3 (dependent variable code) ----
putexcel A3 = ""
putexcel B3 = ""
putexcel C3 = "code", bold

* ---- Row 4 (model / process code) ----
putexcel A4 = "covariate code", bold
putexcel B4 = "covariate name", bold
putexcel C4 = "process",        bold

local cnum = 4
foreach pk of local proc_keys {
    __col2xl, num(`cnum')
    local xlc "`r(col)'"
    putexcel `xlc'1 = "`proc_desc_`pk''"
    putexcel `xlc'2 = "`proc_dv_title_`pk''"
    putexcel `xlc'3 = "`proc_dv_code_`pk''"
    putexcel `xlc'4 = "`pk'", bold
    local ++cnum
}

local ngrp = _N
forvalues r = 1/`ngrp' {
    local rnum = `r' + 4
    putexcel A`rnum' = grp_code[`r']
    putexcel B`rnum' = grp_label[`r']

    local cnum = 4
    foreach pk of local proc_keys {
        __col2xl, num(`cnum')
        local xlc "`r(col)'"
        local val = grp_lag_`pk'[`r']
        if "`val'" != "" & "`val'" != "." {
            putexcel `xlc'`rnum' = "`val'"
        }
        local ++cnum
    }
}

di as txt "  → `ngrp' grouped rows written."


/*============================================================================
  PREPARE STRICT-GROUPED DATA
  Uses the same conceptual groups as the grouped sheet, but rows are only
  collapsed when they share IDENTICAL lag patterns across every model column.
  One row per unique (conceptual group × lag-signature vector).

  Method:
    1. Reload pre-collapse snapshot (one row per base_var, with grp_var assigned).
    2. Build a lag-signature string by concatenating all lag_{pk} values.
    3. Deduplicate on (grp_var, lag_signature): dummies with the same pattern
       merge into one row; those with differing patterns stay separate.
============================================================================*/
use `grpraw_data', clear

* ---- Build lag-pattern signature (concatenate all lag values) ----
gen str512 lag_sig = ""
foreach pk of local proc_keys {
    replace lag_sig = lag_sig + "|" + lag_`pk'
}

* ---- Build combined column labels for each (grp_var × lag-signature) --------
*
*   Col A  base_var_combined  : ALL covariate codes in the group joined with
*                               " / " — mirrors col A of the all_regressors sheet
*                               (e.g. "Deh_c4_High / Deh_c4_Low / Deh_c4_Medium")
*   Col B  bv_desc_combined   : DISTINCT descriptions joined with " / "
*                               (e.g. "Education level category / In education")
*
*   Both use sequential forvalues accumulation; max group size is computed
*   dynamically so the loop length adapts to the actual data.
*
* -- Col A : base_var_combined ------------------------------------------------
preserve
    keep grp_var lag_sig base_var
    sort grp_var lag_sig base_var
    * Determine the largest group size to set forvalues upper bound
    bysort grp_var lag_sig: gen int _gcnt = _N
    qui summarize _gcnt
    local max_bv = r(max)
    drop _gcnt
    * Accumulate: row k gets the combined string from row k-1 plus own code
    gen str2000 base_var_combined = base_var
    forvalues k = 2/`max_bv' {
        by grp_var lag_sig: replace base_var_combined = base_var_combined[_n-1] + " / " + base_var ///
            if _n == `k'
    }
    by grp_var lag_sig: keep if _n == _N   // last row = fully concatenated
    keep grp_var lag_sig base_var_combined
    tempfile bvar_map
    save `bvar_map'
restore
merge m:1 grp_var lag_sig using `bvar_map', nogenerate

* -- Col B : bv_desc_combined (distinct descriptions only) --------------------
preserve
    keep grp_var lag_sig bv_desc
    bysort grp_var lag_sig bv_desc: keep if _n == 1   // one row per distinct description
    sort grp_var lag_sig bv_desc
    bysort grp_var lag_sig: gen int _dcnt = _N
    qui summarize _dcnt
    local max_dv = r(max)
    drop _dcnt
    gen str320 bv_desc_combined = bv_desc
    forvalues k = 2/`max_dv' {
        by grp_var lag_sig: replace bv_desc_combined = bv_desc_combined[_n-1] + " / " + bv_desc ///
            if _n == `k'
    }
    by grp_var lag_sig: keep if _n == _N   // last row = fully concatenated
    keep grp_var lag_sig bv_desc_combined
    tempfile desc_map
    save `desc_map'
restore
merge m:1 grp_var lag_sig using `desc_map', nogenerate

* ---- Deduplicate: keep one row per unique (group × lag pattern) ----
duplicates drop grp_var lag_sig, force

* ---- Sort (same tiers as grouped sheet) ----
sort grp_sort grp_var lag_sig
drop grp_sort lag_sig

tempfile tgrouped_data
save `tgrouped_data'


/*============================================================================
  WRITE SHEET 3: grouped_strict
  Identical layout to grouped, but rows are merged only when all model-column
  lag values are the same.  Groups with heterogeneous lag patterns appear as
  multiple rows (same col A label, different lag values across columns D+).

  Header layout (4 rows): same as grouped and all_regressors
  Col A : covariate code(s) (base_var_combined — same codes as the
          all_regressors sheet; multiple codes merged into one row are joined
          with " / ")
  Col B : covariate name(s) (bv_desc_combined — distinct descriptions joined
          with " / ")
  Col C : row-type label / "process" in row 4
  Cols D+: one column per model
============================================================================*/
di as txt _n "Writing sheet: grouped_strict"

putexcel set "`OUTPUT_FILE'", sheet("grouped_strict") modify

* ---- Row 1 (process group name) ----
putexcel A1 = ""
putexcel B1 = ""
putexcel C1 = "process group", bold

* ---- Row 2 (dependent variable title) ----
putexcel A2 = ""
putexcel B2 = ""
putexcel C2 = "dependent variable", bold

* ---- Row 3 (dependent variable code) ----
putexcel A3 = ""
putexcel B3 = ""
putexcel C3 = "code", bold

* ---- Row 4 (model / process code) ----
putexcel A4 = "covariate code", bold
putexcel B4 = "covariate name", bold
putexcel C4 = "process",        bold

local cnum = 4
foreach pk of local proc_keys {
    __col2xl, num(`cnum')
    local xlc "`r(col)'"
    putexcel `xlc'1 = "`proc_desc_`pk''"
    putexcel `xlc'2 = "`proc_dv_title_`pk''"
    putexcel `xlc'3 = "`proc_dv_code_`pk''"
    putexcel `xlc'4 = "`pk'", bold
    local ++cnum
}

local ntgrp = _N
forvalues r = 1/`ntgrp' {
    local rnum = `r' + 4
    putexcel A`rnum' = base_var_combined[`r']
    local cdesc = bv_desc_combined[`r']
    if "`cdesc'" == "." local cdesc = ""
    putexcel B`rnum' = "`cdesc'"

    local cnum = 4
    foreach pk of local proc_keys {
        __col2xl, num(`cnum')
        local xlc "`r(col)'"
        local val = lag_`pk'[`r']
        if "`val'" != "" & "`val'" != "." {
            putexcel `xlc'`rnum' = "`val'"
        }
        local ++cnum
    }
}

di as txt "  → `ntgrp' strict-grouped rows written."


/*============================================================================
  WRITE SHEET 4: notes
============================================================================*/
di as txt _n "Writing sheet: notes"

putexcel set "`OUTPUT_FILE'", sheet("notes") modify

putexcel A1 = "SimPaths lag-structure: key and rules (`country')", bold

* ── Section 1: Lag codes ────────────────────────────────────────────────────
putexcel A3 = "1. Lag codes", bold
putexcel A4 = "Code",    bold
putexcel B4 = "Meaning", bold
putexcel A5 = "c"
putexcel B5 = "Current-period value – no lag prefix or suffix in the regressor name"
putexcel A6 = "l"
putexcel B6 = "First-order lag – regressor name ends with _L1 or starts with L1_"
putexcel A7 = "l2"
putexcel B7 = "Second-order lag – regressor name ends with _L2 or starts with L2_"
putexcel A8 = "c,l"
putexcel B8 = "Both current and first-order lagged values present for the same regressor in the same model"
putexcel A9 = "c,l2"
putexcel B9 = "Both current and second-order lagged values present"
putexcel A10 = "l,l2"
putexcel B10 = "Both first- and second-order lags present"
putexcel A11 = "c,l,l2"
putexcel B11 = "All three lag forms present"

* ── Section 2: Sheets ────────────────────────────────────────────────────────
putexcel A13 = "2. Sheets", bold
putexcel A14 = "Sheet",        bold
putexcel B14 = "Description",  bold
putexcel A15 = "all_regressors"
putexcel B15 = "One row per individual base variable found across all estimation workbooks (lag affixes, outcome-category suffixes and labour-supply alternative indices stripped). Columns A-B give the variable code and its description; column C carries the process-section label; columns D onward show lag usage per model, in schedule order."
putexcel A16 = "grouped"
putexcel B16 = "Variables collapsed to one row per conceptual group, combining the lags observed across the group's variables. Column A gives the canonical SimPaths variable code; column B gives the group label. See Section 4 for grouping rules."
putexcel A17 = "grouped_strict"
putexcel B17 = "Same conceptual grouping as the grouped sheet, but rows are only merged when ALL lag values are identical across every model column. Rows with different lag patterns within the same conceptual group remain as separate rows. Columns A-B show the combined covariate codes and descriptions of the merged variables."
putexcel A18 = "schedule_check"
putexcel B18 = "Timing audit of every (model, covariate) pair that uses a current-period value (lag = c), comparing the position in the yearly schedule of the step that runs the model with the step that produces the covariate. Positions follow documentation/SimPathsEU_ScheduleNEW.xlsx (Order EU), with the order inside a step where it matters (H1 before H2; W1*-sel before W1*; I1a/I1b before labour supply). Flags: CHECK = producer runs later, so the c value still holds last year's value; same step = producer and consumer in the same step; OK = producer runs earlier; exogenous = not produced by a behavioural process (age, gender, region, macro, pension age); choice-specific = evaluated for each hours alternative inside the labour-supply step."
putexcel A19 = "notes"
putexcel B19 = "This sheet."

* ── Section 3: Technical rules ───────────────────────────────────────────────
putexcel A21 = "3. Processing rules", bold
putexcel A22 = "Rule",        bold
putexcel B22 = "Detail",      bold
putexcel A23 = "Workbook lookup"
putexcel B23 = "Regression workbooks are read from input/`country'/, the files the model loads."
putexcel A24 = "Category stripping"
putexcel B24 = "Multi-outcome sheets embed outcome labels in regressor names. E2a: _Low and _Medium suffixes are stripped. H1: _Poor, _Fair, _Good, _VeryGood and _Excellent suffixes are stripped. This ensures Dag_Low and Dag_Medium collapse to the same base variable Dag."
putexcel A25 = "Trailing underscores"
putexcel B25 = "Proportional-odds models share some coefficients across outcomes; these are coded with a trailing underscore (e.g. PL4_). The underscore is stripped before lag detection."
putexcel A26 = "Labour-supply alternatives"
putexcel B26 = "Labour-supply utility regressors are indexed by hours alternative (Liwwh_10, eduDehC4High_Female_23, HealthSelfRatedGood_3). The index, and the _Male/_Female before it, is stripped, so each term appears once."
putexcel A27 = "Interaction terms"
putexcel B27 = "Ded_*, Deh_c4_*_Dag and Dgn_Les_c4_* style terms are flagged as interactions and grouped separately, so e.g. the capital-income lags in Ded_Ypncp_L1/L2 are not shown as education lags."
putexcel A28 = "RMSE excluded"
putexcel B28 = "reg_RMSE is a diagnostics workbook and is not a behavioural process; it is excluded throughout."
putexcel A29 = "Hyphenated sheet names"
putexcel B29 = "Employment-selection sheets are named W1fa-sel etc. in Excel. The corresponding Stata proc_key uses an underscore (W1fa_sel) for compatibility."
putexcel A30 = "Column ordering"
putexcel B30 = "Model columns follow the yearly schedule: R1a R1b | E1a E1b E2a | P1 | HO1 | H1 H2 | W1fa W1ma W1fb W1mb | W1fa_sel W1ma_sel W1fb_sel W1mb_sel | U1 U2 | F1 | I1a I1b | labour supply (7 types)."

* ── Section 4: Grouped-sheet category rules ──────────────────────────────────
putexcel A32 = "4. Grouping rules (grouped and grouped_strict sheets)", bold
putexcel A33 = "Code",         bold
putexcel B33 = "Group label",  bold
putexcel C33 = "Base-variable patterns collapsed into this group", bold

local r = 34
foreach spec in ///
    "dgn|Gender|Dgn, Dgnsp (exact match)" ///
    "dag|Age|Dag, Dag_sq, Dagsq, Dag_knot*, Dag16 etc., Rcs*" ///
    "deh|Education (in education, level)|Ded, Der, Deh_c* (attainment dummies), eduDehC4* (labour-supply alternative terms)" ///
    "dehsp|Spouse education|Dehsp*" ///
    "dehm|Maternal education|Dehm*" ///
    "dehf|Paternal education|Dehf*" ///
    "dcpst|Partnership status / household type|Dcpst*, Dhhtp*, Dcpyy, Dcpagdf, New_rel" ///
    "dnc|Children|Dnc*, D_children*" ///
    "dhe|Health status|Dhe* (own), Dhesp* (spouse), HealthSelfRated* (labour-supply alternative terms)" ///
    "dhm|Mental health|Dhm*, Dhmghq*, Ghq*" ///
    "dlltsd|Disability status|Dlltsd* (own and spouse)" ///
    "les_c4|Activity status|Les_c* (own), Lessp* (spouse), Lesdf* (couple), Pt (part-time, wage equations)" ///
    "elig_pen|Retirement age / pension eligibility|Reached_Retirement_Age*, Elig_pen*" ///
    "parents_ypnb|Co-resident parents (known, income quintile)|Parents_ypnb_Q*, Parents_known, Parents_known_Ydses_Q*" ///
    "ydses_c5|Household income / SES|Ydses*, Ypnbihs*, Yptciihs*, Ynbcpdf*" ///
    "yplgrs|Employment income|Yplgrs*" ///
    "ypncp|Capital income|Ypncp*, Ln_Ypncp*" ///
    "ypnoab|Pension income|Ypnoab*" ///
    "liwwh|Years in employment|Liwwh, LiwwhSq (years in employment; in labour-supply sheets interacted with the hours alternative)" ///
    "fullTimeHourlyEarningsPotential|Potential wage|log_hourly_wage (L1_ prefix), FullTimeHourly*" ///
    "InvMillsRatio|Inverse Mills ratio (employment selection)|InvMillsRatio, InverseMillsRatio" ///
    "IncomeDiv100|Disposable income at hours alternative|IncomeDiv100, IncomeSqDiv10000" ///
    "leisure|Leisure / hours / fixed costs at alternative|MaleLeisure*, FemaleLeisure*, Hrs_40plus*, FullFixedCost*, PartFixedCost*" ///
    "dhh_owned|Home owner|Dhh_own*, Dhhown*" ///
    "drgn1|Region|Country-specific NUTS1 region dummies: PL*, EL*, IT*, HU*, ES*" ///
    "stm|Year / time trend|Year dummies (Y2016-Y2023), Year_transformed*, Post2015, Post2020, FertilityRate, RealWageGrowth" ///
    "interactions|Interaction terms|Ded_*, Deh_c4_*_<var>, Dgn_<var> where <var> is another regressor" {
    gettoken gcode  rest : spec, parse("|")
    gettoken bar    rest : rest, parse("|")
    gettoken glabel rest : rest, parse("|")
    gettoken bar    gpats : rest, parse("|")
    putexcel A`r' = "`gcode'"
    putexcel B`r' = "`glabel'"
    putexcel C`r' = "`gpats'"
    local ++r
}

/*============================================================================
  WRITE SHEET 5: schedule_check
  For every (process, covariate) pair where the lag code includes "c"
  (current-period value), this sheet compares the position in the yearly
  schedule of the step running the model with the step producing the
  covariate. Positions are the Order EU numbers of
  documentation/SimPathsEU_ScheduleNEW.xlsx; seq orders models inside a step.

    Order EU  step                              models
     5        Updated persons                   (Parents_known lag)
     6        Aging                             (years in employment)
     8        Consider retirement               R1a, R1b
     9        ParentsIncomeQuintiles            (Parents_ypnb quintiles)
    11        InSchool                          E1a, E1b
    12        LeavingSchool                     E2a
    14        ConsiderLeavingHome               P1
    15        Homeownership                     HO1
    17        Health                            H1 (seq 1), H2 (seq 2)
    18        UpdatePotentialHourlyEarnings     W1*-sel (seq 1), W1* (seq 2)
    20-22     Cohabitation, dissolution, union matching    U1, U2
    24-25     Fertility, GiveBirth              F1
    26        LabourMarketAndIncomeUpdate       I1a/I1b (seq 1), labour supply (seq 2)

  Flag meanings:
    CHECK            Producer runs AFTER consumer → c value not yet updated;
                     effectively behaves as a lagged value
    same step        Producer and consumer at the same schedule position
    OK               Producer runs before consumer → c is already updated
    exogenous        Variable is not produced by any behavioural process
    choice-specific  Evaluated for each hours alternative inside the
                     labour-supply step
============================================================================*/
di as txt _n "Writing sheet: schedule_check"

* ---- load all_regressors data; reshape to long (one row per base_var × process) ----
use `wide_data', clear
keep base_var bv_desc lag_*

reshape long lag_, i(base_var) j(proc_key) string
rename lag_ lag_code

* drop rows where the variable does not appear in this process
drop if lag_code == "" | lag_code == "."

* keep only observations where the current-period value is used
keep if regexm(lag_code, "c")

* ---- consumer: schedule position and step label ----
gen int   consumer_step   = .
gen byte  consumer_seq    = 0
gen str60 consumer_module = ""
__cons, keys(R1a R1b)                     step(8)  seq(0) module("8 Consider retirement")
__cons, keys(E1a E1b)                     step(11) seq(0) module("11 InSchool")
__cons, keys(E2a)                         step(12) seq(0) module("12 LeavingSchool")
__cons, keys(P1)                          step(14) seq(0) module("14 ConsiderLeavingHome")
__cons, keys(HO1)                         step(15) seq(0) module("15 Homeownership")
__cons, keys(H1)                          step(17) seq(1) module("17 Health")
__cons, keys(H2)                          step(17) seq(2) module("17 Health")
__cons, keys(W1fa_sel W1ma_sel W1fb_sel W1mb_sel) step(18) seq(1) module("18 UpdatePotentialHourlyEarnings")
__cons, keys(W1fa W1ma W1fb W1mb)         step(18) seq(2) module("18 UpdatePotentialHourlyEarnings")
__cons, keys(U1 U2)                       step(20) seq(0) module("20 Cohabitation")
__cons, keys(F1)                          step(24) seq(0) module("24 Fertility")
__cons, keys(I1a I1b)                     step(26) seq(1) module("26 LabourMarketAndIncomeUpdate")
__cons, keys(`ls_keys')                   step(26) seq(2) module("26 LabourMarketAndIncomeUpdate")

* ---- producer: which step updates this covariate? ----
gen bv_upper = upper(base_var)

gen int   producer_step   = .
gen byte  producer_seq    = 0
gen str60 producer_proc   = ""
gen str60 producer_module = ""

__prod if regexm(bv_upper, "^PARENTS_KNOWN"),                       step(5)  seq(0) proc("Update persons")                 module("5 Updated persons")
__prod if regexm(bv_upper, "^LIWW"),                                step(6)  seq(0) proc("Aging (years in employment)")    module("6 Aging")
__prod if regexm(bv_upper, "^(DRTREN|DLRTRD)"),                     step(8)  seq(0) proc("R1a / R1b")                      module("8 Consider retirement")
__prod if regexm(bv_upper, "^PARENTS_YPNB"),                        step(9)  seq(0) proc("ParentsIncomeQuintiles")         module("9 ParentsIncomeQuintiles")
__prod if regexm(bv_upper, "^(DED|DER)($|_)"),                      step(11) seq(0) proc("E1a / E1b")                      module("11 InSchool")
__prod if regexm(bv_upper, "^(DEH_C|DEHSP|EDUDEHC4)"),              step(12) seq(0) proc("E2a")                            module("12 LeavingSchool")
__prod if regexm(bv_upper, "^DLFTPHM"),                             step(14) seq(0) proc("P1")                             module("14 ConsiderLeavingHome")
__prod if regexm(bv_upper, "^(DHH_OWN|DHHOWN)"),                    step(15) seq(0) proc("HO1")                            module("15 Homeownership")
__prod if regexm(bv_upper, "^(DHE|HEALTHSELFRATED)"),               step(17) seq(1) proc("H1")                             module("17 Health")
__prod if regexm(bv_upper, "^DLLTSD"),                              step(17) seq(2) proc("H2")                             module("17 Health")
__prod if inlist(bv_upper, "INVMILLSRATIO", "INVERSEMILLSRATIO"),   step(18) seq(1) proc("W1*-sel")                        module("18 UpdatePotentialHourlyEarnings")
__prod if regexm(bv_upper, "^(LOG_HOURLY|FULLTIMEHOURLY)"),         step(18) seq(2) proc("W1*")                            module("18 UpdatePotentialHourlyEarnings")
__prod if regexm(bv_upper, "^(DCPST|DCPEN|DCPEX|DCPAGDF|DCPYY|NEW_REL|DHHTP)"), step(22) seq(0) proc("U1 / U2, union matching") module("20-22 Partnership")
__prod if regexm(bv_upper, "^(DNC|D_CHILDREN)"),                    step(25) seq(0) proc("F1 / GiveBirth")                 module("24-25 Fertility")
__prod if regexm(bv_upper, "^(YPNCP|LN_YPNCP|YPNOAB|YPTCIIHS)"),    step(26) seq(1) proc("I1a / I1b")                      module("26 LabourMarketAndIncomeUpdate")
__prod if regexm(bv_upper, "^(YPLGRS|YPNBIHS|YNBCPDF|YDSES)"),      step(26) seq(2) proc("Labour supply + tax-benefit")    module("26 LabourMarketAndIncomeUpdate")
__prod if regexm(bv_upper, "^(LES_C|LESSP|LESDF)") | bv_upper == "PT", step(26) seq(2) proc("Labour supply (also 8, 11, 12)") module("26 LabourMarketAndIncomeUpdate")

* Terms evaluated for each hours alternative inside the labour-supply step
gen byte is_choice = regexm(bv_upper, "^(INCOMEDIV|INCOMESQDIV|MALELEISURE|FEMALELEISURE|HRS_40PLUS|FULLFIXEDCOST|PARTFIXEDCOST)")

drop bv_upper

* ---- flag ----
* Note: in Stata missing (.) > all real numbers, so guard with != . before < / >
gen int consumer_key = consumer_step*10 + consumer_seq
gen int producer_key = producer_step*10 + producer_seq
gen str30 flag = ""
replace flag = "exogenous"       if producer_step == .
replace flag = "OK"              if producer_step != . & producer_key < consumer_key
replace flag = "same step"       if producer_step != . & producer_key == consumer_key
replace flag = "CHECK"           if producer_step != . & producer_key > consumer_key
replace flag = "choice-specific" if is_choice
replace producer_proc   = "LS alternative (per hours option)" if is_choice
replace producer_module = "26 LabourMarketAndIncomeUpdate"    if is_choice

* sort: issues first, then same step, then OK, then the rest; break ties by schedule position then variable name
gen int flag_sort = 5
replace flag_sort = 1 if flag == "CHECK"
replace flag_sort = 2 if flag == "same step"
replace flag_sort = 3 if flag == "OK"
replace flag_sort = 4 if flag == "choice-specific"
sort flag_sort consumer_key base_var proc_key
drop flag_sort consumer_key producer_key

* ---- write to Excel ----
putexcel set "`OUTPUT_FILE'", sheet("schedule_check") modify

putexcel A1 = "Schedule vs. lag-usage check", bold
putexcel A2 = "Shows every (process, covariate) pair where a current-period value (lag = c) is used. The flag compares the schedule position (Order EU in documentation/SimPathsEU_ScheduleNEW.xlsx) of the step running the model with that of the step producing the covariate."
putexcel A3 = "Flag meanings:   CHECK = producer runs AFTER consumer (c still holds last year's value);   same step = producer and consumer at the same schedule position;   OK = producer runs before consumer;   exogenous = not produced by any behavioural process;   choice-specific = evaluated per hours alternative in the labour-supply step."

putexcel A5 = "Covariate code",    bold
putexcel B5 = "Covariate name",    bold
putexcel C5 = "Consuming process", bold
putexcel D5 = "Consumer step",     bold
putexcel E5 = "Consumer Order EU", bold
putexcel F5 = "Lag used",          bold
putexcel G5 = "Producing process", bold
putexcel H5 = "Producer step",     bold
putexcel I5 = "Producer Order EU", bold
putexcel J5 = "Flag",              bold

local nsc = _N
forvalues r = 1/`nsc' {
    local rnum = `r' + 5

    local bvcode = base_var[`r']
    putexcel A`rnum' = "`bvcode'"

    local desc = bv_desc[`r']
    if "`desc'" == "." local desc = ""
    putexcel B`rnum' = "`desc'"

    local pk   = proc_key[`r']
    putexcel C`rnum' = "`pk'"

    local cmod = consumer_module[`r']
    putexcel D`rnum' = "`cmod'"

    local cord = consumer_step[`r']
    putexcel E`rnum' = `cord'

    local lc = lag_code[`r']
    putexcel F`rnum' = "`lc'"

    local pprc = producer_proc[`r']
    putexcel G`rnum' = "`pprc'"

    local pmod = producer_module[`r']
    putexcel H`rnum' = "`pmod'"

    local pord = producer_step[`r']
    if `pord' != . putexcel I`rnum' = `pord'

    local fl = flag[`r']
    putexcel J`rnum' = "`fl'"
}

di as txt "  -> `nsc' current-lag rows written to schedule_check."

di as res _n "Lag-structure workbook written to:" _n "  `OUTPUT_FILE'"
