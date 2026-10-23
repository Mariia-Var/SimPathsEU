**************************************************************************
* 			Project: Simpaths EU 
*           EU SILC (ES_2024_b1_2015_03_e2)
*           Master file using std model plus single adult chidren (split) hhs for Spain
*           
*           Author: Zhechun He, Daria Popova 
*           Credit: Matteo Richiardi, Francesco Figari   
*           Latest revision: Daria Popova   
*           Date revised: 16 Oct 2026
************************************************************************
//note: "_indep" means singles are without partner, "_dep" means singles are not real singles, but live with non-flexible partner
//note: wage1:predicted wage for everyone. wage2:predicted wage for non-workers only. In the ls estimation, only wage1 is used.
************************************************************************


clear all
set more off
set type double
set maxvar 30000
set matsize 1000
//version 14 

/*Save add_partner_variables.ado add_mother_variables.ado and add_father_variables.ado in your ADO directory*/

*directories
//global path "D:\Dasha\ESSEX\_SimPaths\_SimPaths_EU\ES\labour_supply"
global path "D:\Dasha\ESSEX\_SimPaths\_SimPaths_EU\ES\labour_supply"
global do_files "${path}\do-files" 
global do_files_std "${path}\do-files\std singles and couples data preparation" 
global do_files_adult_ch "${path}\do-files\adult children data preparation"
global do_files_specifications "${path}\do-files\model specifications"


global local_data "${path}\data" //folder to store data produced
global log "${path}\log"
 
global results_wi "${path}\results\wage imputation" //folder to store wage imputation results and graphs 
global results "${path}\results" //folder to store LS results  

global summary_table "${path}\results\summary_table" //folder to store general summary tables for all models 


**********************************************************************************************

global em_models "${path}/EUROMOD_RELEASES_J2.0+"  //folder with the input, output etc. EUROMOD folders
global em_exe "C:\Program Files\EUROMOD\Executable\EM_ExecutableCaller.exe"  //executable for EUROMOD

global em_original "${em_models}\Input\original" //EUROMOD original data folder

global em_input "${em_models}\Input\" //EUROMOD input folder
global em_output "${em_models}\Output\"  //EUROMOD output folder

global file_input = "ES_2024_b1_2015_03_e2"
global file_output="es_2023_std" //here output file is 2023 because 2023 system will be used with the 2024 data (2023 earnings)
global policy_year ="ES_2023"
global income_year 2023 

global impmethod "1" //predicted wages for everyone 
*global impmethod "2" //predicted wages for non-working, observed wages for working  

*=======================================================================
* Globals used in Simpaths   

global age_seek_employment 16 
	
global age_force_retire 75     

global max_lhw 126  //ensure lhw is not above weekly maximum of 168 minus 6*7 hours of sleep

global age_max_dep_child 17     

global adult_child_age_cap 45     


*-----------------------------------------------------------------------------------------------
* HOURS DISCRETISATION – Spain 2023
*-----------------------------------------------------------------------------------------------
* !  If you are changing hours discretisation, don't forget to update the code in the input data construction do-file !
* ! Update label for couple alternatives !

/*
global n_choices      4                                    // 1 non-work + 3 work brackets
global n_workchoices  = $n_choices - 1                     // work choices only
global n_draws        = 10                              // modify when computing elasticity100 


* Minimum hours defining each bracket

* Women
//global min_hours_1_0  = 1         // Inclusive [1,35] = part-time
global min_hours_1_0  = 6         // Inclusive [6,35] = part-time
global min_hours_2_0  = 36        // Inclusive [36,40] = full-time
global min_hours_3_0  = 41        // Inclusive [41,+∞) = overtime

* Men
//global min_hours_1_1  = 1         // Inclusive [1,35] = part-time
global min_hours_1_1  = 6         // Inclusive [6,35] = part-time
global min_hours_2_1  = 36        // Inclusive [36,40] = full-time
global min_hours_3_1  = 41        // Inclusive [41,+∞) = overtime


* Representative hours

* Discretisation of weekly labour market hours:
* Part-time: 1-35 hours, represented by 30 hours
* Full-time: 36-40 hours, represented by 40 hours
* Overtime: 41+ hours, represented by 50 hours


* Women
global hours_0_0 = 0
global hours_1_0 = 30         // part-time
global hours_2_0 = 40         // full-time
global hours_3_0 = 50         // overtime

* Men
global hours_0_1 = 0
global hours_1_1 = 30         // part-time
global hours_2_1 = 40         // full-time
global hours_3_1 = 50         // overtime



global n_choices      5                                    // 1 non-work + 4 work brackets
global n_workchoices  = $n_choices - 1                     // work choices only
global n_draws=10  //modify when computing elasticity100


* Minimum hours defining each bracket

* women 
global min_hours_1_0  = 6         // Inclusive [6,25] = part time 1
global min_hours_2_0  = 26        // Inclusive [26,35] = part time 2
global min_hours_3_0  = 36        // Inclusive [36,40] = full time
global min_hours_4_0  = 41        // Inclusive [41,+∞) = overtime

* men 
global min_hours_1_1  = 6         // Inclusive [6,25] = part time 1
global min_hours_2_1  = 26        // Inclusive [26,35] = part time 2
global min_hours_3_1  = 36        // Inclusive [36,40] = full time
global min_hours_4_1  = 41        // Inclusive [41,+∞) = overtime


* representative hours 

* Discretisation of weekly labour market hours:
/*Representative hours were selected based on the modal number of hours 
worked within each discretized category, calculated separately for women and men. 
This approach assigns the most commonly observed working hours to each category, 
while allowing for differences in the distribution of hours by gender. 
The resulting representative values are 0, 25, 35, 40 and 50 hours for women, 
and 0, 20, 35, 40 and 50 hours for men. 
*/

* Women
global hours_0_0 = 0+
global hours_1_0 = 25 //low part-time
global hours_2_0 = 35 //substantial part-time
global hours_3_0 = 40 
global hours_4_0 = 50

* Men
global hours_0_1 = 0
global hours_1_1 = 25 //low part-time
global hours_2_1 = 35 //substantial part-time
global hours_3_1 = 40
global hours_4_1 = 50
*/

*-----------------------------------------------------------------------------------------------
* 6 choices: non-work + 5 work brackets
* Representative hours are shown below.
*-----------------------------------------------------------------------------------------------

global n_choices      6
global n_workchoices  = $n_choices - 1
global n_draws        = 10  // modify when computing elasticity100 


*-----------------------------------------------------------------------------------------------
* Minimum hours defining each bracket
*-----------------------------------------------------------------------------------------------

* Women
global min_hours_1_0  = 6          // [6,25]    low part-time
global min_hours_2_0  = 26         // [26,34]   higher part-time
global min_hours_3_0  = 35         // [35,39]   near full-time
global min_hours_4_0  = 40         // [40,40]   full-time
global min_hours_5_0  = 41         // [41,+∞)   overtime


* Men
global min_hours_1_1  = 6          // [6,34]    part-time
global min_hours_2_1  = 35         // [35,39]   near full-time
global min_hours_3_1  = 40         // [40,40]   full-time
global min_hours_4_1  = 41         // [41,55]   overtime
global min_hours_5_1  = 56         // [56,+∞)   high overtime


*-----------------------------------------------------------------------------------------------
* Representative hours
*-----------------------------------------------------------------------------------------------

* Women
global hours_0_0 = 0
global hours_1_0 = 20         // 6-25
global hours_2_0 = 30         // 26-34
global hours_3_0 = 37         // 35-39
global hours_4_0 = 40         // 40
global hours_5_0 = 50         // 41+


* Men
global hours_0_1 = 0
global hours_1_1 = 20         // 6-34
global hours_2_1 = 37         // 35-39
global hours_3_1 = 40         // 40
global hours_4_1 = 50         // 41-55
global hours_5_1 = 60         // 56+

* globals for graphs 
global graph_singles_women  "0 20 30 37 40 50"
global graph_singles_men    "0 20 37 40 50 60"

global graph_couples ""
local i = 1

foreach w of global graph_singles_women {
    foreach m of global graph_singles_men {
        global graph_couples `"${graph_couples} `i' "`w'/`m'""'
        local ++i
    }
}

*=======================================================================
* Set Excel file for LS utility 

* Info sheet

*=======================================================================
* Set Excel file for LS utility
*=======================================================================

* Info sheet

putexcel set "$results/reg_labourSupplyUtility_ES", sheet("Info") replace

putexcel A1 = ("Description:")
putexcel B1 = ("Regression estimates used by the labour supply process for the following subsamples:")
putexcel B2 = ("1- Single females: Single_Females")
putexcel B3 = ("2- Single males: Single_Males")
putexcel B4 = ("3- Couples with two labour flexible: Couples")
putexcel B5 = ("4- Singles with dependent, females: SingleDep_Females")
putexcel B6 = ("5- Singles with dependent, males: SingleDep_Males")
putexcel B7 = ("6- Single adult children, females: SingleAC_Females")
putexcel B8 = ("7- Single adult children, males: SingleAC_Males")

putexcel A10 = ("Notes:")
putexcel B10 = ("Discretisation of weekly labour market hours:")
putexcel B11 = ("6 choices: non-work + 5 work brackets")
putexcel B12 = ("Numbers after '=' denote representative weekly hours for each bracket")

* Women
putexcel B14 = ("Women:")
putexcel B15 = ("Choice 0: 0-5 hours = 0")
putexcel B16 = ("Choice 1: 6-25 hours = 20")
putexcel B17 = ("Choice 2: 26-34 hours = 30")
putexcel B18 = ("Choice 3: 35-39 hours = 37")
putexcel B19 = ("Choice 4: 40 hours = 40")
putexcel B20 = ("Choice 5: 41+ hours = 50")

* Men
putexcel B21 = ("Men:")
putexcel B22 = ("Choice 0: 0-5 hours = 0")
putexcel B23 = ("Choice 10: 6-34 hours = 20")
putexcel B24 = ("Choice 20: 35-39 hours = 37")
putexcel B25 = ("Choice 30: 40 hours = 40")
putexcel B26 = ("Choice 40: 41-55 hours = 50")
putexcel B27 = ("Choice 50: 56+ hours = 60")

putexcel B28 = ("Choice numbers identify alternatives for women and men; numbers after '=' are representative weekly hours.")

putexcel B31 = ("FullFixedCost is defined as hours >= 40; PartFixedCost as hours 6-39")

putexcel B33 = ("Case-specific regressors are allowed to have different effects for different labour-supply choices.")
putexcel B34 = ("The number after the final underscore identifies the labour-supply choice (alternative) to which the coefficient applies.")
putexcel B35 = ("For example, eduDehC4Medium_Male_55 is the coefficient for medium male education for labour-supply choice 55.")
putexcel B36 = ("This is why the same variable may appear with different numbers, such as _1, _2, ... _55.")

putexcel A40 = ("Last update: 16 Oct 2026 by Daria Popova")


*=======================================================================
*           std singles and couples
*=======================================================================
/*
//-input and output data in EM
do "$do_files_std\1-input and output data-std model.do"  //for std singles and couples, get wage estimates, impute wages in two ways, run EM

//-target samples
do "$do_files_std\2a-singles sample-std model.do"  //get sample for single and generate the vbls needed for ls (std singles)

do "$do_files_std\2b-couples sample-std model.do"  //get sample for couple and generate the vbls needed for ls (std couples)

//-run EM in preparation for computing elasticity
do "$do_files_std\3a-EM single wage elasticity-std model.do" //run EM to get the ils_dispy for sample of singles resulting from a 10% increase in gross wage (std singles)

do "$do_files_std\3b-EM couple wage elasticity-std model.do" //run EM to get the ils_dispy for sample of couples resulting from a 10% increase in gross wage (std couples)


*=======================================================================
*           single adult children (split hhs)
*=======================================================================

//-input and output data in EM
do "$do_files_adult_ch\1-input and output data-dropped sample.do"  //for adult children, split households, run EM

//-target samples
do "$do_files_adult_ch\2-singles sample-dropped sample.do"  //get sample for single and generate the vbls needed for ls (single adult children)

//-run EM in preparation for computing elasticity
do "$do_files_adult_ch\3-EM single wage elasticity-adult_ch.do" //run EM to get the ils_dispy for sample of singles resulting from a 10% increase in gross wage 

*/
/*
*=======================================================================
*           LS models -asclogit - baseline specification 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v1" //folder to store LS results - baseline model with predicted wages for everyone 

global sheet "LS_v1"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v1.do"  

do  "$do_files_specifications\4b-singles_dep_elast-std model - v1.do"  

do  "$do_files_specifications\4c-couples elast-std model - v1.do"  

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v1.do" 
/**/

*=======================================================================
*           LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v2" //folder to store LS results   

global sheet "LS_v2"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v2.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v2.do"  

do  "$do_files_specifications\4c-couples elast-std model - v2.do"  

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v2.do" 
/**/

*=======================================================================
*           LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v3" //folder to store LS results 

global sheet "LS_v3"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v3.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v3.do" 

do  "$do_files_specifications\4c-couples elast-std model - v3.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v3.do" 
/**/

*=======================================================================
*            LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v4" //folder to store LS results 

global sheet "LS_v4"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v4.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v4.do" 

do  "$do_files_specifications\4c-couples elast-std model - v4.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v4.do" 
/**/


*=======================================================================
*            LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v5" //folder to store LS results  

global sheet "LS_v5"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v5.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v5.do" 

do  "$do_files_specifications\4c-couples elast-std model - v5.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v5.do" 
/**/

*=======================================================================
*            LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v6" //folder to store LS results  

global sheet "LS_v6"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v6.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v6.do" 

do  "$do_files_specifications\4c-couples elast-std model - v6.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v6.do" 
/**/


*=======================================================================
*           LS models -asclogit - 
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v7" //folder to store LS results  

global sheet "LS_v7"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v7.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v7.do" 

do  "$do_files_specifications\4c-couples elast-std model - v7.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v7.do" 
/**/

*=======================================================================
*            LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v8" //folder to store LS results   

global sheet "LS_v8"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v8.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v8.do" 

do  "$do_files_specifications\4c-couples elast-std model - v8.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v8.do" 
/**/

*=======================================================================
*           LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v9" //folder to store LS results 

global sheet "LS_v9"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v9.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v9.do" 

do  "$do_files_specifications\4c-couples elast-std model - v9.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v9.do" 
/**/

*=======================================================================
*           LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v10" //folder to store LS results 

global sheet "LS_v10"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v10.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v10.do" 

do  "$do_files_specifications\4c-couples elast-std model - v10.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v10.do" 
/**/

*=======================================================================
*           LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v11" //folder to store LS results 

global sheet "LS_v11"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v11.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v11.do" 

do  "$do_files_specifications\4c-couples elast-std model - v11.do" 

do "$do_files_specifications\4d-singles_indep_elast-adult_ch - v11.do" 
/**/

*=======================================================================
*           LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v12" //folder to store LS results  

global sheet "LS_v12"


do  "$do_files_specifications\4a-singles_indep_elast-std model - v12.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v12.do" 

do  "$do_files_specifications\4c-couples elast-std model - v12.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v12.do" 
/**/

*=======================================================================
*           LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v13" //folder to store LS results  

global sheet "LS_v13"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v13.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v13.do" 

do  "$do_files_specifications\4c-couples elast-std model - v13.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v13.do" 
/**/

*=======================================================================
*            LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v14" //folder to store LS results 

global sheet "LS_v14"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v14.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v14.do" 

do  "$do_files_specifications\4c-couples elast-std model - v14.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v14.do" 
/**/

*=======================================================================
*           LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v15" //folder to store LS results  
global sheet "LS_v15"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v15.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v15.do" 

do  "$do_files_specifications\4c-couples elast-std model - v15.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v15.do" 
/**/

*=======================================================================
*           LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v16" //folder to store LS results 
global sheet "LS_v16"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v16.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v16.do" 

do  "$do_files_specifications\4c-couples elast-std model - v16.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v16.do" 
/**/

*=======================================================================
*           LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v17" //folder to store LS results  
global sheet "LS_v17"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v17.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v17.do" 

do  "$do_files_specifications\4c-couples elast-std model - v17.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v17.do" 
/**/

*=======================================================================
*            LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v18" //folder to store LS results 
global sheet "LS_v18"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v18.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v18.do" 

do  "$do_files_specifications\4c-couples elast-std model - v18.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v18.do" 
/**/

*=======================================================================
*            LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v19" //folder to store LS results  
global sheet "LS_v19"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v19.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v19.do" 

do  "$do_files_specifications\4c-couples elast-std model - v19.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v19.do" 
/**/

*=======================================================================
*            LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v20" //folder to store LS results 
global sheet "LS_v20"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v20.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v20.do" 

do  "$do_files_specifications\4c-couples elast-std model - v20.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v20.do" 
/**/

*=======================================================================
*            LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v21" //folder to store LS results  
global sheet "LS_v21"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v21.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v21.do" 

do  "$do_files_specifications\4c-couples elast-std model - v21.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v21.do" 
/**/

*=======================================================================
*            LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v22" //folder to store LS results   
global sheet "LS_v22"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v22.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v22.do" 

do  "$do_files_specifications\4c-couples elast-std model - v22.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v22.do" 
/**/

*=======================================================================
*            LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v23" //folder to store LS results   
global sheet "LS_v23"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v23.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v23.do" 

do  "$do_files_specifications\4c-couples elast-std model - v23.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v23.do" 
/**/


*=======================================================================
*            LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v24" //folder to store LS results   
global sheet "LS_v24"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v24.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v24.do" 

do  "$do_files_specifications\4c-couples elast-std model - v24.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v24.do" 

/**/
*=======================================================================
*            LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_v25" //folder to store LS results   
global sheet "LS_v25"

do  "$do_files_specifications\4a-singles_indep_elast-std model - v25.do" 

do  "$do_files_specifications\4b-singles_dep_elast-std model - v25.do" 

do  "$do_files_specifications\4c-couples elast-std model - v25.do" 

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - v25.do" 
/**/
*/

*=======================================================================
*           LS models -asclogit -
*=======================================================================
*These globals have to be updated for the version of the LS model 
global results_ls "${path}/results\LS_final" //folder to store LS results 
global sheet "LS_final"

do  "$do_files_specifications\4a-singles_indep_elast-std model - final.do" //v19

do  "$do_files_specifications\4b-singles_dep_elast-std model - final.do" //v19

do  "$do_files_specifications\4c-couples elast-std model - final.do" //v22

do  "$do_files_specifications\4d-singles_indep_elast-adult_ch - final.do" //v11

/**/


