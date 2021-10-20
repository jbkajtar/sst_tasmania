# JBK 2021-08-26
# compute SST area averages for Tasmanian subregions
# 1. read SST data from observations and CMIP6 (historical and future)
# 2. trim to required regions
# 3. compute area averages
# 4. store required data to netCDF
# OUTPUT: sst_indices/sst_indices.tas.<model>.<scenario>.<variant>.nc

# load required modules
import numpy as np
import xarray as xr
import pandas
import glob
from datetime import date
import time
import cftime
import regionmask

# set paths and filenames
inpath = ''     # location of model source list
sstpath = ''    # pre-processed observed and CMIP6 SST (from 'store_tas_region_sst.py')
gridpath = ''   # pre-processed CMIP6 grids (from 'store_tas_areacello.py')
outpath = ''    # output directory

# define which scenarios to use
scen_h = 'historical'
scen_f = 'ssp585'        # ssp126 or ssp585

# define bounds of stored region
reg_lab = 'tas'
reg_bnds = [138, 155, -49, -35]   # 138E-155E, 49S-35S

# define bounds of index regions
rb1 = np.array([142, 151, -45, -39])        # whole region
rb2 = np.array([146.5, 149.5, -44.5, -42])  # SE
rb3 = np.array([146.5, 149.5, -42, -39.5])  # NE
rb4 = np.array([143.5, 146.5, -44.5, -42])  # SW
rb5 = np.array([143.5, 146.5, -42, -39.5])  # NW

tas_all = np.array([[rb1[0],rb1[2]], [rb1[0],rb1[3]], [rb1[1],rb1[3]], [rb1[1],rb1[2]]])
tas_se = np.array([[rb2[0],rb2[2]], [rb2[0],rb2[3]], [rb2[1],rb2[3]], [rb2[1],rb2[2]]])
tas_ne = np.array([[rb3[0],rb3[2]], [rb3[0],rb3[3]], [rb3[1],rb3[3]], [rb3[1],rb3[2]]])
tas_sw = np.array([[rb4[0],rb4[2]], [rb4[0],rb4[3]], [rb4[1],rb4[3]], [rb4[1],rb4[2]]])
tas_nw = np.array([[rb5[0],rb5[2]], [rb5[0],rb5[3]], [rb5[1],rb5[3]], [rb5[1],rb5[2]]])

# define headers and index names
idx_head = "Tasmanian case study regions"
idx_name = ["Whole Tas region", "SE Tas", "NE Tas", "SW Tas", "NW Tas"]
idx_code = ["tas_all", "tas_se", "tas_ne", "tas_sw", "tas_nw"]

# create regionmask
index_masks = regionmask.Regions([tas_all, tas_se, tas_ne, tas_sw, tas_nw], names=idx_name, abbrevs=idx_code, name=idx_head)

# read model lists
# model list .txt files should have OBS path as first entry
modfile_h = open(inpath + 'cmip6_gadi_' + scen_h + '.txt', "r")
modfile_f = open(inpath + 'cmip6_gadi_' + scen_f + '.txt', "r")
modlist_h = modfile_h.read().splitlines()
modlist_f = modfile_f.read().splitlines()
modfile_h.close()
modfile_f.close()

nmods = len(modlist_h)
modcode = ["" for x in range(nmods)]  # initialise modcode array
modname = ["" for x in range(nmods)]  # initialise modname array

# range of models to process in this run
m_which = range(0,nmods)

# store model names
for m in m_which:
 
 # split path names to retrieve model parameters
 modcode_h = modlist_h[m].split("/")
 modcode_f = modlist_f[m].split("/")
 
 if m == 0:
  # set OBS label, e.g. NOAA_OISST.AVHRR.v2-1_modified
  modname[m] = modcode_h[4]
  modcode[m] = '.'.join(modcode_h[4:7])
 else:
  # set model label, e.g. <source_id>.historical+ssp126.<variant_label>
  modname[m] = modcode_h[8]
  modcode[m] = modcode_h[8] + '.' + scen_h + '+' + scen_f + '.' + modcode_h[10]
  # check the model names and experiment IDs are the same, only for CMIP6 (skip OBS)
  if not(modcode_h[8] == modcode_f[8]) or not(modcode_h[10] == modcode_f[10]):
   print('--> ERROR: problem in file paths!')

print('PROCESS LIST')
for m in m_which:
 print('[' + str(m) + ']: ' + modcode[m])

# loop over all models in list
for m in m_which:
 
 print('Processing... ' + modcode[m])
 
 # specify input file name of SST from pre-processed data files
 infile = sstpath + 'sst.' + reg_lab + '.' + modcode[m] + '.nc'
 
 # create output filename
 outfile = outpath + 'sst_indices.' + reg_lab + '.' + modcode[m]

 # load data
 print('Loading data... ')
 start = time.time()
 ds = xr.open_dataset(infile)
 end = time.time()
 print(end - start)
 
 # store min and max lon, may be required for rotated lon coords
 min_lon = np.min(ds.lon.values)
 max_lon = np.max(ds.lon.values)
 
 print(min_lon)
 print(max_lon)
 
 # create mask for dataset
 mask = index_masks.mask_3D(ds)
 
 # compute SST indices
 print('Computing indices... ')
 start = time.time()

 if m == 0:
  # for OBS, calculate weights from cos(lat)
  weights = np.cos(np.deg2rad(ds.lat))
  dim = ds.sst.dims   # read dimension names
 else:
  # for models, load preprocessed model areacello
  gridfile = sorted(glob.glob(gridpath + 'areacello.' + reg_lab + '.' + modname[m] + '.*.nc'))
  dg = xr.open_mfdataset(gridfile)
  dim = dg.areacello.dims   # read dimension names
  
  # calculate weights based on native cell areas
  weights = dg.areacello / dg.areacello.max(dim=(dim[-2], dim[-1]))
  weights = weights.fillna(0)
  weights = weights.values
 
 sst_ts = ds.weighted(mask * weights).mean(dim=(dim[-2], dim[-1]))
 end = time.time()
 print(end - start)
 
 # create xarray dataset for processed results
 ds_out = sst_ts
 ds_out.attrs = {}   # clear attributes
 
 # set coverage_content_type: https://wiki.esipfed.org/Concepts_Glossary
 if m == 0:
  cct = "physicalMeasurement"
 else:
  cct = "modelResult"
 
 # set attributes of variables
 ds_out['region'] = ds_out.region.assign_attrs(long_name="region index")
 ds_out['sst'] = ds_out.sst.assign_attrs(units=ds.sst.attrs['units'], standard_name="sea_surface_temperature", long_name="Area-average sea surface temperature", coverage_content_type=cct)
 
 # set global attributes
 #ds_out.attrs['source_code'] = "https://github.com/jbkajtar/sst_tasmania"
 ds_out.attrs['title'] = "Sea surface temperature indices for the Tasmanian region (138E-155E, 49S-35S)"
 #ds_out.attrs['summary'] = "Data generated for "Assessment and communication of risks to Tasmanian aquaculture and fisheries from marine heatwaves: Technical Report" (2021)"
 ds_out.attrs['source_data'] = modcode[m]
 ds_out.attrs['keywords'] = "marine heatwave; extreme event; impact; ocean warming; Tasmania; CMIP6 projections"
 ds_out.attrs['Conventions'] = "ACDD-1.3"
 
 # save dataset to netcdf file
 print('Saving data... ')
 start = time.time()
 ds_out.to_netcdf(outfile + '.nc', encoding={'abbrevs':{'dtype':'S1'}, 'names':{'dtype':'S1'}})
 end = time.time()
 print(end - start)


