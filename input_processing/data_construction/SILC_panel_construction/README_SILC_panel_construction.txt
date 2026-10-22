Construction of the EU-SILC Longitudinal Panel

Date: 6/6/26
Author: A Burdett

Many SimPaths inputs are based on longitudinal EU-SILC data. A formatted version of these data is used to construct the unique input dataset (UID), which is used for estimating processes and initialising
the simulation. These data are processed using the GESIS compilation program (eusilcpanel_2020), which combines the raw longitudinal EU-SILC files into harmonised panel datasets (D, H, R and P).

The downloadable version of the GESIS program constructs harmonised longitudinal datasets (D, H, P and R) containing all available panel observations for survey years 2005–2020. For SimPaths, we use an
extended version of the compilation program that has been updated to process the 2024 EU-SILC longitudinal release, producing equivalent datasets covering 2005–2023.

One important complication is that some variables used in the estimation (most notably the economic activity and education variables) change names and coding from 2021 onwards. Because the GESIS 
longitudinal compilation is constructed by appending complete panels backwards through time, observations prior to 2021 for individuals whose panel extends into 2021 or later are compiled using the 
post-2021 variable definitions. As a result, the pre-2021 values of these variables are missing for those individuals.

To overcome this issue, the SimPaths data construction combines information from two compiled GESIS panels:

	•	2005–2020 panel: constructed using the original GESIS compilation program and the earlier EU-SILC longitudinal release.
	•	2005–2023 panel: constructed using the extended GESIS compilation program and the 2024 EU-SILC longitudinal release.

The variables affected by the post-2020 coding changes are taken from the 2005–2020 panel and merged into the extended 2005–2023 panel. This preserves complete historical information for these variables while allowing the panel to be extended through to 2023.

The resulting datasets (D, H, R and P) are then combined to construct the UID using the do-files contained in the “data_construction” folder. The UID forms the basis for simulation initialisation, 
process estimation and validation of the simulated output. 

Workflow summary: 

1. Obtain the required longitudinal EU-SILC releases. 

2. Run the GESIS compilation program using the earlier longitudinal release to produce the harmonised 2005-2020 D, H, R, and P datasets. 

3. Run the extended version of the GESIS compilation program using the 2024 longitudinal release to produce the harmonised 2005-2023 D, H, R, and P datasets. 

4. Run the SimPaths UID construction files contained in the ”data_construction” folder to create the final UID. During this process, the variables affected by the post-2020 coding changes are merged 
from the 2005-2020 dataset into the 2005-2023 dataset. 

Links: 
GESIS EU-SILC panel compilation program (eusilcpanel_2020) - https://www.gesis.org/en/missy/materials/EU-SILC/tools/datahandling

