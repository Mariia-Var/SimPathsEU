/*******************************************************************************
* PROJECT:              SimPaths EU
* DO-FILE NAME:         00_master_ES.do
* DESCRIPTION:          Runs the simulation validation and plotting do-files.
* COUNTRY:              PL
* DATA:                 EU-SILC UID and SimPaths simulation outputs
* AUTHORS:              Ashley Burdett, Mariia Vartuzova
* LAST UPDATE:          May 2026
********************************************************************************
* NOTES:
*
*   -----------------------------------------------------------------------
*    What this file does
*   -----------------------------------------------------------------------
*   This master do-file runs the simulation validation routines for Poland.
*   It constructs validation targets from the EU-SILC unique input dataset
*   (UID), prepares the simulated data, and produces plots comparing
*   simulated outcomes against the validation targets.
*
*   The file loops over the specified alignment scenarios and generates
*   validation plots for each scenario. These validation routines are designed 
* 	for multi-run SimPaths outputs and cannot be used with single-run simulation 
* 	outputs. Plots compare the mean simulated outcomes against validation 
* 	targets and display variation across simulation runs.
*
*   -----------------------------------------------------------------------
*    Required input data
*   -----------------------------------------------------------------------
*   - ES_pooled_ipop.dta:
*     EU-SILC UID used to construct the observed validation targets.
*     Located in the directory specified by dir_init_pop_data.
*
*   - SimPaths multi-run simulation outputs:
*     CSV files from multiple simulation runs, organised into separate
*     folders for each alignment scenario:
*       dir_sim_output/<alignment_scenario>/csv/
*
*   - AlignmentStatistics.csv:
*     SimPaths alignment statistics used to construct the alignment
*     target plots.
*
*   - Any additional input files required by individual validation
*     do-files.
*
*   -----------------------------------------------------------------------
*    User configuration
*   -----------------------------------------------------------------------
*   Before running this master file, review the configuration settings
*   below. Parameters requiring user input are marked >> EDIT << in
*   the code to make them easy to locate.
*
*   1. Set dir_ind to the local SimPaths EU project directory.
*
*   2. Check dir_init_pop_data points to the folder containing the
*      ES_pooled_ipop.dta dataset.
*
*   3. Set dir_sim_output to the folder containing the SimPaths
*      simulation outputs, organised by alignment scenario.
*
*   4. Check the sample and simulation parameters, including:
*      - Minimum and maximum ages (min_age, max_age).
*      - Validation years (min_year, max_year).
*      - Simulated years (min_sim_year, max_sim_year).
*      - Number of simulation runs (max_n_runs).
*
*      Check that the labour supply category globals and weekly hours
*      thresholds match the country-specific SimPaths model. See the
*      section below for additional changes required when adapting
*      these routines to another country.
*
*   5. Update the alignments global to select the alignment scenarios
*      to be validated. The corresponding simulation output folders
*      must exist.
*
*   6. Check that the required worker do-files are available in
*      dir_do_files and select the plotting routines to be executed.
*
*   -----------------------------------------------------------------------
*    File structure and outputs
*   -----------------------------------------------------------------------
*   The master file first constructs the EU-SILC validation targets.
*   It then loops over the selected alignment scenarios, preparing
*   simulated data, constructing simulated validation statistics,
*   and generating the validation plots.
*
*   Intermediate data are stored in the validation data folder.
*   Figures are saved separately for each alignment scenario under:
*
*       path/graphs/<alignment_scenario>/
*
*   Subfolders organise plots by outcome, including employment,
*   education, income, health, poverty, and alignment targets.
* 

*   -----------------------------------------------------------------------
*    Adapting the validation routines to another country
*   -----------------------------------------------------------------------
*   These validation routines are configured for Poland. When adapting
*   them to another country, the labour supply categories must be
*   reviewed and updated to match those used in the country-specific
*   SimPaths model.
*
*   In particular:
*
*   1. Update the labour supply category globals and weekly hours
*      thresholds defined in this master file. These may differ
*      between males and females.
*
*   2. Update the construction of the labour supply category variables
*      in 02_prepare_validation_data.do and
*      03_prepare_simulation_data.do to ensure that observed and
*      simulated hours are classified consistently with the model.
*
*   3. Review the income plotting do-files, particularly histograms
*      conditional on labour supply category. Where category
*      definitions differ by gender, these comparisons should be
*      produced separately for males and females.
*
*   4. Check that plotting loops, category labels, graph names,
*      and graph-combination commands reflect the country-specific
*      labour supply categories.
*
*   Other country-specific assumptions and variable definitions
*   should also be reviewed before running the validation.
*
*******************************************************************************/
clear all

set logtype smcl
set more off
set mem 200m
set type double


/*******************************************************************************
* Ensure required user-written packages are installed
*******************************************************************************/
local ssc_pkgs "ineqdeco fre unique grc1leg2"

foreach pkg of local ssc_pkgs {
	
    capture which `pkg'
    if _rc ssc install `pkg', replace

}

* grc1leg lives on Vince Wiggins' site, not SSC
capture which grc1leg

if _rc net install grc1leg, from("http://www.stata.com/users/vwiggins/")


/*******************************************************************************
* 1 - CONFIGURATION
*******************************************************************************/

/*******************************************************************************
* DEFINE COUNTRY GLOBALS
*******************************************************************************/

global country = "PL"
global country_lower = "pl"
display in y "Country selected: ${country}"

global silc_UDB = "UDB_c"


/*******************************************************************************
* DEFINE DIRECTORIES
*******************************************************************************/

* Individual path  >> EDIT <<
global dir_ind "..."

///Users/ashleyburdett/Library/CloudStorage/Box-Box/CeMPA shared area/_SimPaths/_SimPathsEU

* Main folder containing simulation validation plot material 
global path "${dir_ind}/validation/02_simulation_output_validation/PL/longitudinal_SILC"

* Folder containing do-files 
global dir_do_files "$path/do_files"  

* Folder containing output data 
global dir_work "$path/data"
global dir_data "$path/data"

* Folder containing the UID dataset - ${country}_pooled_ipop.dta  >> EDIT <<
global dir_init_pop_data "..."

//dir_ind/input_processing/initial_populations/PL/data

* Folder containing SimPaths output: one subfolder per alignment scenario, 
* each with a csv folder  >> EDIT <<
global dir_sim_output "..."


/*******************************************************************************
* DEFINE SAMPLE PARAMETERS
*******************************************************************************/

global use_assert "0"

* Trim outliers
global trim_outliers true

* Min working age for plots
global min_age 18

* Max working age for plots
global max_age 65

* Range of calendar years included in the validation sample
global min_year 2011
global max_year 2023

global min_sim_year ${min_year}
global max_sim_year ${max_year}

* Define age to become responsible as defined in the simulation
global age_become_responsible 18

* Set labour supply categories

global ls_cat "ZERO TWENTY FORTY FIFTY"
global ls_cat_labour "TWENTY FORTY FIFTY"

* Number of simulation runs included in the multi-run outputs  >> EDIT <<
global max_n_runs 3


/*******************************************************************************
* 2 - PREPARE EU-SILC VALIDATION TARGETS
*******************************************************************************/

* Prepare SILC data
do "${dir_do_files}/03_create_EU_SILC_validation_targets.do"


/*******************************************************************************
* 3 - PROCESS SIMULATION OUTPUTS AND GENERATE VALIDATION PLOTS
*******************************************************************************/

/*******************************************************************************
* DEFINE ALIGNMENT SCENARIOS
*******************************************************************************/

* List of SimPath Set ups to loop through	>> EDIT <<
local alignments "..."

/*
alignment_00_populationOFF alignment_01_population alignment_02a_population_fertility alignment_02b_population_cohabitation alignment_02c_population_disability alignment_02d_population_inschool alignment_02e_population_retirement alignment_03_population_fertility_cohabitation alignment_04_population_fertility_cohabitation_employment
*/

foreach align in `alignments' {


/*******************************************************************************
* DEFINE ALIGNEMENT DIRECTORIES
*******************************************************************************/

	* Simulated data CSV files folder
	global dir_simulated_data "${dir_sim_output}/`align'/csv"
	display in y "Alignment scenario: `align'"
	
	* Graph storage folder
	global dir_output_files "$path/graphs/`align'"

	
/*******************************************************************************
* CREATE OUTPUT FOLDERS
*******************************************************************************/

	capture mkdir "$path/graphs"
	capture mkdir "$path/graphs/`align'"
	capture mkdir "$path/graphs/`align'/alignment_targets"
	capture mkdir "$path/graphs/`align'/children"
	capture mkdir "$path/graphs/`align'/correlations"
	capture mkdir "$path/graphs/`align'/disability"
	capture mkdir "$path/graphs/`align'/economic_activity"
	capture mkdir "$path/graphs/`align'/education"
	capture mkdir "$path/graphs/`align'/health"
	capture mkdir "$path/graphs/`align'/hours_worked"
	capture mkdir "$path/graphs/`align'/income"
	capture mkdir "$path/graphs/`align'/income/capital_income"
	capture mkdir "$path/graphs/`align'/income/pension_income"
	capture mkdir "$path/graphs/`align'/income/disposable_income"
	capture mkdir "$path/graphs/`align'/income/equivalised_disposable_income"
	capture mkdir "$path/graphs/`align'/income/gross_income"
	capture mkdir "$path/graphs/`align'/income/gross_labour_income"
	capture mkdir "$path/graphs/`align'/income/income_shares"
	capture mkdir "$path/graphs/`align'/inequality"
	capture mkdir "$path/graphs/`align'/partnership"
	capture mkdir "$path/graphs/`align'/poverty"
	capture mkdir "$path/graphs/`align'/wages"

/*******************************************************************************
* PREPARE SIMULATED DATA AND PLOT GRAPHS
*******************************************************************************/

	* Prepare simulated data
	do "${dir_do_files}/01_prepare_simulated_data.do"
	
	do "${dir_do_files}/02_create_simulated_validation_targets.do"

	* Plot figures
	do "${dir_do_files}/04_01_plot_activity_status.do"
	do "${dir_do_files}/04_02_plot_education_level.do"
	do "${dir_do_files}/04_03_plot_gross_income.do"
	do "${dir_do_files}/04_04_plot_gross_labour_income.do"
	do "${dir_do_files}/04_05_plot_capital_income.do"
	do "${dir_do_files}/04_07_plot_disposable_income.do"
	do "${dir_do_files}/04_08_plot_equivalised_disposable_income.do"
	do "${dir_do_files}/04_09_plot_hourly_wages.do"
	do "${dir_do_files}/04_10_0_plot_hours_worked.do"
	do "${dir_do_files}/04_10_1_plot_hours_worked_discrete.do"
	do "${dir_do_files}/04_11_plot_income_shares.do"
	do "${dir_do_files}/04_12_plot_partnership_status.do"
	do "${dir_do_files}/04_13_plot_health.do"	
	do "${dir_do_files}/04_14_plot_at_risk_of_poverty.do"
	do "${dir_do_files}/04_15_plot_inequality.do"
	do "${dir_do_files}/04_16_plot_number_children.do"
	do "${dir_do_files}/04_17_plot_disability.do"

	do "${dir_do_files}/04_18_plot_alignment_targets.do"
	
}	
	
