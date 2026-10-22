/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         01_prepare_simulated_data.do
* DESCRIPTION:          Imports and prepares SimPaths simulation output data.
* COUNTRY:              ES
* DATA:                 SimPaths multi-run simulation outputs
* AUTHORS:              Patryk Bronka, Ashley Burdett
* LAST UPDATE:          21 October 2026
********************************************************************************
* NOTES:
*
*   -----------------------------------------------------------------------
*    What this file does
*   -----------------------------------------------------------------------
*   This do-file imports and prepares the SimPaths simulation outputs
*   required for validation. It retains the relevant variables from the
*   household, benefit-unit, and person files and restricts observations
*   to the specified maximum simulation year.
*
*   The person and benefit-unit datasets are merged using the run,
*   time, and benefit-unit identifiers. The resulting dataset is saved
*   for use by the subsequent validation routines.
*
*   -----------------------------------------------------------------------
*    Required input data
*   -----------------------------------------------------------------------
*   The following multi-run simulation output files are required:
*
*   - Household.csv
*   - BenefitUnit.csv
*   - Person.csv
*
*   These files must be located in the directory specified by
*   dir_simulated_data, defined in the master file for each alignment
*   scenario:
*
*       dir_sim_output/<alignment_scenario>/csv/
*
*
*******************************************************************************/

* Import required variables from household file
import delimited "$dir_simulated_data/Household.csv", case(preserve) clear 

keep run time id_Household

rename id_Household idHh  

keep if time <= ${max_year}

save "$dir_data/household_validation", replace


* Import required variables from benefit unit file
import delimited "$dir_simulated_data/BenefitUnit.csv", case(preserve) clear

keep run time idHh id_BenefitUnit yDispMonth yDispEquivYear yGrossMonth 
	
rename id_BenefitUnit idBu

keep if time <= ${max_year}	

save "$dir_data/benefitunit_validation", replace


* Import required variables from person file
import delimited "$dir_simulated_data/Person.csv", case(preserve) clear

keep run time id_Person idPartner idBu idMother idFather demAge ///
	demMaleFlag demPartnerStatus labC4 eduHighestC4 ///
	healthDsblLongtermFlag healthSelfRated ///
	yNonBenPersGrossMonth yEmpPersGrossMonth yCapitalPersMonth ///
	yPensPersGrossMonth yMiscPersGrossMonth ///
	labHrsWorkWeek labHrsWorkEnumWeek labHrsWorkWeek ///
	labWageHrly
	
rename id_Person idPers

keep if time <= ${max_year}
										
save "$dir_data/person_validation", replace


* Merge data sets 
use "$dir_data/person_validation", clear

merge m:1 run time idBu using "$dir_data/benefitunit_validation", ///
	nogen keep(matched)

save "$dir_data/loaded_simulation_data.dta", replace 


* Tidy up 
erase "${dir_data}/household_validation.dta"
erase "${dir_data}/person_validation.dta"
erase "${dir_data}/benefitunit_validation.dta"
