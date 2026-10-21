***************************************************************************************
* PROJECT: ESPON: construct a cross-sectional panel dataset deom EU-SILC database 
* **************************************************************************************
version 14 
clear
set logtype smcl
set more off
set mem 200m
set type double

global path "C:\Dasha\ESSEX\_SimPaths\_SimPaths_EU\ES\labour_supply"

*open original SILC dataset in Stata 
insheet using "${path}\data\EU-SILC-2024-orig\ES_EMSD2_2024.txt", clear 

*rename variables created by Estat 
rename idperson_e idperson 
rename idhh_e idhh 
rename dgn_e dgn 
rename dag_e dag 
rename drgn1_e drgn1


/**********************************Health status*******************************/
/*
. fre ph010

ph010 -- PH010
-----------------------------------------------------------
              |      Freq.    Percent      Valid       Cum.
--------------+--------------------------------------------
Valid   1     |      10113      13.91      16.52      16.52
        2     |      32591      44.83      53.24      69.76
        3     |      13891      19.11      22.69      92.46
        4     |       3584       4.93       5.85      98.31
        5     |       1034       1.42       1.69     100.00
        Total |      61213      84.20     100.00           
Missing .     |      11489      15.80                      
Total         |      72702     100.00                      
-----------------------------------------------------------
*/

* reverse code so 5 = excellent and higher number means better health
recode ph010 (5 = 1 "Poor") ///
	(4 = 2 "Fair") ///
	(3 = 3 "Good") ///
	(2 = 4 "Very good") ///
	(1 = 5 "Excellent") ///
	, into(dhe)
la var dhe "Health status"
fre dhe 

keep idperson idhh dhe 
sort idhh idperson

save "${path}\data\temp_dhe.dta", replace

