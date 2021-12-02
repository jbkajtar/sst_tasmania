# Tasmanian region sea surface temperature processing (sst_tasmania)

Code for processing sea surface temperature data from observational and CMIP6 data for:

Kajtar, J.B. and Holbrook, N.J. (2021): "Future projections of marine heatwave hazards to aquaculture and fisheries in Tasmania", Institute for Marine and Antarctic Studies, University of Tasmania, Australia. 36pp. ISBN: 978-1-922708-06-9. http://ecite.utas.edu.au/147866.

This code has been written to process sea surface temperature (SST) for the Tasmanian region (138°E-155°E, 49°S-35°S). Daily sea surface temperature data, from both observations and models, are processed. The observed sea surface temperature data is from NOAA 0.25° daily Optimum Interpolation Sea Surface Temperature (OISST) over the period 1982-2020 (Huang et al. 2020). The modelled sea surface temperature data is from 25 model simulations as part of the Coupled Model Intercomparison Project, Phase 6 (CMIP6; Eyring et al. 2016) over the period 1982-2100, where two future scenarios have been analysed. Sea surface temperature data are provided on a native grid point basis across the domain. Area-averaged timeseries are also provided for five subdomains.

The data is publicly and freely available to download at https://doi.org/10.25959/F33G-8234.

# Contents

|Directory         |Description|
|------------------|-----------|
|code              |Code for storing SST in Tasmanian domain and compute indices|
|post-processing   |Code for post-processing data|
|sources           |Primary data source list|

# code

Python code for reading and storing SST data from observations and models. Primary data source paths must first be specified in the files obtained from the 'sources' directory.

|File              |Description|
|------------------|-----------|
|store_tas_region_sst.py     |Read and store SST for the Tasmanian region|
|store_tas_areacello.py      |Store CMIP6 native grid cell areas for the Tasmanian region|
|compute_tas_sst_indices.py  |Compute area-average SST timeseries for Tasmanian subdomains|

# post-processing

MATLAB code for post-processing of SST data.

|File              |Description|
|------------------|-----------|
|daily_climatology.m             |Function to compute a daily climatology from a temperature time-series|
|findrange.m                     |Function to find a range in an array|
|pp_cmip6_sst_1-raw.m            |Post-processing of SST indices: common calendar, and store data in single file|
|pp_cmip6_sst_2-mean_bias.m      |Post-processing of SST indices: subtract mean bias from model data|
|pp_cmip6_sst_3-seasonal_bias.m  |Post-processing of SST indices: subtract seasonal cycle bias from model data|
|pp_mean_sst_field.m             |Post-processing of SST fields: compute long-term mean|

# sources

Files that specify the locations of the primary source data, to be adapted by the user. The sst_tasmania code reads data from these specified paths. One path per line in each file. Also provided here are the full details of CMIP6 realisations analysed in Kajtar and Holbrook (2021), along with primary source references.

|File              |Description|
|------------------|-----------|
|sst_tasmania_cmip6_data_references.csv  |CMIP6 source list|
|cmip6_gadi_areacello.txt   |Source list for areacello|
|cmip6_gadi_historical.txt  |Source list for historical data|
|cmip6_gadi_ssp126.txt      |Source list for SSP1-2.6 scenario data|
|cmip6_gadi_ssp585.txt      |Source list for SSP5-8.5 scenario data|

# References

Eyring, V., Bony, S., Meehl, G.A., Senior, C.A., Stevens, B., Stouffer, R.J., Taylor, K.E. (2016): Overview of the Coupled Model Intercomparison Project Phase 6 (CMIP6) experimental design and organization. Geosci. Model Dev., 9, 1937–1958. https://doi.org/10.5194/gmd-9-1937-2016

Huang, B., Liu, C., Banzon, V.F., Freeman, E., Graham, G., Hankins, B., Smith, T.M., Zhang, H.-M. (2020): NOAA 0.25-degree Daily Optimum Interpolation Sea Surface Temperature (OISST), Version 2.1. NOAA National Centers for Environmental Information. https://doi.org/10.25921/RE9P-PT57

Kajtar, J.B. and Holbrook, N.J. (2021): "Future projections of marine heatwave hazards to aquaculture and fisheries in Tasmania", Institute for Marine and Antarctic Studies, University of Tasmania, Australia. 36pp. ISBN: 978-1-922708-06-9. http://ecite.utas.edu.au/147866 

Kajtar, J.B. (2021): Tasmanian region daily sea surface temperature from observations and CMIP6 models [Data set]. Institute for Marine and Antarctic Studies (IMAS), University of Tasmania (UTAS). https://doi.org/10.25959/F33G-8234

# Acknowledgements

We thank the Tasmanian Government’s Department of Premier and Cabinet (DPAC) and the Tasmanian Climate Change Office (TCCO) for funding and supporting this project through the Climate Research Grants Program. We acknowledge the World Climate Research Programme's Working Group on Coupled Modelling, which is responsible for CMIP, and we thank the climate modelling groups for producing and making available their model output. CMIP6 model outputs were made available with the assistance of resources from the National Computational Infrastructure (NCI), which is supported by the Australian Government. NOAA High Resolution SST data were provided by the NOAA National Centers for Environmental Information.
