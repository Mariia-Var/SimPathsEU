/**************************************************************************************************
* PROJECT:         Project: Simpaths_EU   
* DO-FILE:         lhw_checks 
*
* PURPOSE:
*   - Generate empirical distributions of observed weekly hours of work for labour supply estimation.
**************************************************************************************************/

global country ES
 
global path "D:\Dasha\ESSEX\_Simpaths\_Simpaths_EU\ES\labour_supply"

global results "${path}\results" //folder to store LS results  

global graphs "${path}\results\hours"


****************
* Info sheet  *
****************

putexcel set "${results}/hours_distributions_${country}.xlsx", ///
    sheet("Info") replace 

putexcel A1 = "Country"
putexcel B1 = "ES"	

putexcel A2 = "Dataset"
putexcel B2 = "EU SILC (ES_2024_b1_2015_03_e2)"	
	
putexcel A4 = "lhw"
putexcel B4 = "Observed weekly hours of work of labour supply flexible individuals aged 16-75 years, before data are discretised and reshaped"

putexcel A5 = "frequency"
putexcel B5 = "Share of individuals in the relevant sample working exactly the reported number of observed hours. Values range from 0 to 1."

putexcel A8 = "Sheet"
putexcel B8 = "Sample"

putexcel A9 = "Single_indep_male"
putexcel B9 = "Independent single men"

putexcel A10 = "Single_indep_female"
putexcel B10 = "Independent single women"

putexcel A11 = "Single_indep_all"
putexcel B11 = "All independent singles"

putexcel A12 = "Couple_male"
putexcel B12 = "Men in couples with two flexible individuals"

putexcel A13 = "Couple_female"
putexcel B13 = "Women in couples with two flexible individuals"

putexcel A14 = "Couple_all"
putexcel B14 = "All individuals in couples with two flexible individuals"

putexcel A15 = "Single_dep_male"
putexcel B15 = "Men in couples with a dependent partner"

putexcel A16 = "Single_dep_female"
putexcel B16 = "Women in couples with a dependent partner"

putexcel A17 = "Single_dep_all"
putexcel B17 = "All individuals in couples with a dependent partner"

putexcel A18 = "Adult_child_male"
putexcel B18 = "Male adult children"

putexcel A19 = "Adult_child_female"
putexcel B19 = "Female adult children"

putexcel A20 = "Adult_child_all"
putexcel B20 = "All adult children"

putexcel A21 = "All_male"
putexcel B21 = "All men across the combined samples"

putexcel A22 = "All_female"
putexcel B22 = "All women across the combined samples"

putexcel A23 = "All"
putexcel B23 = "All individuals across the combined samples"


************************
* Independent singles  *
************************

use "${path}\data\beforeReshape.dta", clear
keep if (dag>=16 & dag <=75)   

// graphs

histogram lhw if temp_singles_indep == 1, ///
    percent subtitle("Independent singles") ylabel(0(10)60)
graph export "${graphs}/lhw_temp_singles_indep.png", as(png) replace

histogram lhw if dgn == 1 & temp_singles_indep == 1, ///
    percent subtitle("Independent singles, men") ylabel(0(10)60)
graph export "${graphs}/lhw_temp_singles_indep_1.png", as(png) replace

histogram lhw if dgn == 0 & temp_singles_indep == 1, ///
    percent subtitle("Independent singles, women") ylabel(0(10)60)
graph export "${graphs}/lhw_temp_singles_indep_0.png", as(png) replace


// males
preserve
keep if temp_singles_indep == 1 & dgn == 1

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("Single_indep_male") firstrow(variables) sheetreplace

restore


// females
preserve
keep if temp_singles_indep == 1 & dgn == 0

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("Single_indep_female") firstrow(variables) sheetreplace

restore


// all
preserve
keep if temp_singles_indep == 1

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("Single_indep_all") firstrow(variables) sheetreplace

restore


*************
* couples   *
*************

// graphs

histogram lhw if temp_couples == 1, ///
    percent subtitle("Couples") ylabel(0(10)60)
graph export "${graphs}/lhw_temp_couples.png", as(png) replace

histogram lhw if dgn == 1 & temp_couples == 1, ///
    percent subtitle("Couples, men") ylabel(0(10)60)
graph export "${graphs}/lhw_temp_couples_1.png", as(png) replace

histogram lhw if dgn == 0 & temp_couples == 1, ///
    percent subtitle("Couples, women") ylabel(0(10)60)
graph export "${graphs}/lhw_temp_couples_0.png", as(png) replace


// males
preserve
keep if temp_couples == 1 & dgn == 1

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("Couple_male") firstrow(variables) sheetreplace

restore


// females
preserve
keep if temp_couples == 1 & dgn == 0

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("Couple_female") firstrow(variables) sheetreplace

restore


// all
preserve
keep if temp_couples == 1

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("Couple_all") firstrow(variables) sheetreplace

restore


*************************
* single with dependent *
*************************

// graphs

histogram lhw if temp_singles_dep == 1, ///
    percent subtitle("Single with dependent children") ylabel(0(10)60)
graph export "${graphs}/lhw_temp_singles_dep.png", as(png) replace

histogram lhw if dgn == 1 & temp_singles_dep == 1, ///
    percent subtitle("Single with dependent children, men") ylabel(0(10)60)
graph export "${graphs}/lhw_temp_singles_dep_1.png", as(png) replace

histogram lhw if dgn == 0 & temp_singles_dep == 1, ///
    percent subtitle("Single with dependent children, women") ylabel(0(10)60)
graph export "${graphs}/lhw_temp_singles_dep_0.png", as(png) replace


// males
preserve
keep if temp_singles_dep == 1 & dgn == 1

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("Single_dep_male") firstrow(variables) sheetreplace

restore


// females
preserve
keep if temp_singles_dep == 1 & dgn == 0

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("Single_dep_female") firstrow(variables) sheetreplace

restore


// all
preserve
keep if temp_singles_dep == 1

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("Single_dep_all") firstrow(variables) sheetreplace

restore


******************
* adult children *
******************

use "${path}\data\beforeReshape-dropped_sample.dta", clear
keep if (dag>=16 & dag <=75)


// graphs

histogram lhw, ///
    percent subtitle("Adult children") ylabel(0(10)60)
graph export "${graphs}/lhw_adult_children.png", as(png) replace

histogram lhw if dgn == 1, ///
    percent subtitle("Adult children, men") ylabel(0(10)60)
graph export "${graphs}/lhw_adult_children_1.png", as(png) replace

histogram lhw if dgn == 0, ///
    percent subtitle("Adult children, women") ylabel(0(10)60)
graph export "${graphs}/lhw_adult_children_0.png", as(png) replace


// males
preserve
keep if dgn == 1

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("Adult_child_male") firstrow(variables) sheetreplace

restore


// females
preserve
keep if dgn == 0

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("Adult_child_female") firstrow(variables) sheetreplace

restore


// all
preserve

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("Adult_child_all") firstrow(variables) sheetreplace

restore


******************
* all individuals *
******************

use "${path}\data\beforeReshape.dta", clear
keep if (dag>=16 & dag <=75)

tempfile main_sample
save `main_sample'

use "${path}\data\beforeReshape-dropped_sample.dta", clear
keep if (dag>=16 & dag <=75)

append using `main_sample'


// males
preserve
keep if dgn == 1

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("All_male") firstrow(variables) sheetreplace

restore


// females
preserve
keep if dgn == 0

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("All_female") firstrow(variables) sheetreplace

restore


// all
preserve

contract lhw
egen total = total(_freq)
gen frequency = _freq / total

keep lhw frequency
sort lhw

export excel using "${results}/hours_distributions_${country}.xlsx", ///
    sheet("All") firstrow(variables) sheetreplace

restore
