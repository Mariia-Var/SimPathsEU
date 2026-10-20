/*******************************************************************************
* PROJECT:        SimPaths EU
* SECTION:        Additional series
* OBJECT:         Master file for constructing Spain time-series inputs
* AUTHORS:        Ashley Burdett
* LAST UPDATE:    10/08/2026
* COUNTRY:        Spain
********************************************************************************
* NOTES:
*
* This master do-file constructs the additional time-series inputs required
* by SimPaths for Spain. It defines the project directories and then calls
* each series-specific do-file in the required order.
*
* Directory structure:
*
*   time_series/
*       input_data/        Shared raw source data (Eurostat, etc.)
*       ES/                Spain-specific files and outputs
*           do_files/
*           data/
*
* Before running:
*   1. Update the directory globals below if required.
*   2. Ensure the shared input_data folder contains all required raw data
*      (see individual do-files for details).
*   3. Run this file from start to finish.
*
* The following series are constructed:
*   - Real GDP index
*   - Inflation (HICP) index
*   - Real wage index and annual real wage growth
*   - Population series and projections (by region, age and year)
*   - Fertility rate
*   - Mortality rates (by age and year)
*
* Note:
*   inflation.do must be run before real_wage_growth.do because the latter
*   uses the saved inflation dataset created by the former.
*******************************************************************************/

clear all
set more off
macro drop _all 
set type double
set maxvar 30000
set matsize 1000


***************************** SET MACROS ***************************************

global country "ES"


************************* SET DIRECTORIES **************************************

* Working directory which contains sub-folders and will contain formatted output 
global dir_work "/Users/ashleyburdett/Library/CloudStorage/Box-Box/CeMPA shared area/_SimPaths/_SimPathsEU/input_processing/time_series/${country}"

* Directory which contains raw data 
global dir_input_data "/Users/ashleyburdett/Library/CloudStorage/Box-Box/CeMPA shared area/_SimPaths/_SimPathsEU/input_processing/time_series/input_data"

* Directory which contains do files
global dir_do "$dir_work/do_files"

* Directory which contains intermediate data
global dir_data "$dir_work/data"


***************************** CALL FILES ***************************************

do "$dir_do/RGDP.do"

do "$dir_do/inflation.do"

do "$dir_do/real_wage_growth.do"

do "$dir_do/population_projections.do"

do "$dir_do/fertility_rate.do"

do "$dir_do/mortality_rate.do"


******************************* TIDY UP ****************************************

erase "$dir_do/inflation.dta"
erase "$dir_do/mortality_rate.dta"
erase "$dir_do/population_projections.dta"
erase "$dir_do/total_fertility_rate.dta"
