# JBK 2021-08-25
# store raw SST for Tasmanian region
# 1. read SST data from observations and CMIP6 (historical and future)
# 2. trim to required regions
# 3. store required data in single netCDF
# OUTPUT: sst/sst.tas.<model>.<scenario>.<variant>.nc

# load required modules
import numpy as np
import xarray as xr
import pandas
import glob
from datetime import date
import time
import cftime
import dask
from dask.diagnostics import ProgressBar

# set paths and filenames
inpath = ''   # location of model source list
outpath = ''  # output directory

# allow large chunks and silence the warning
# https://docs.dask.org/en/latest/array-slicing.html
dask.config.set({"array.slicing.split_large_chunks": False})

# define which scenarios to use
scen_h = 'historical'
scen_f = 'ssp126'        # ssp126 or ssp585

# define bounds of stored region
reg_lab = 'tas'
reg_bnds = [138, 155, -49, -35]   # 138E-155E, 49S-35S

# read model lists
# model list .txt files should have OBS path as first entry
modfile_h = open(inpath + 'cmip6_gadi_' + scen_h + '.txt', "r")
modfile_f = open(inpath + 'cmip6_gadi_' + scen_f + '.txt', "r")
modlist_h = modfile_h.read().splitlines()
modlist_f = modfile_f.read().splitlines()
modfile_h.close()
modfile_f.close()

nmods = len(modlist_h)

# range of models to process in this run
m_which = range(0,nmods)
print('PROCESS LIST')
for m in m_which:
 print('[' + str(m) + ']: ' + modlist_h[m])

# loop over all models in list
for m in m_which:
 
 # split path names to retrieve model parameters
 modcode_h = modlist_h[m].split("/")
 modcode_f = modlist_f[m].split("/")
 
 if m == 0:
  # set OBS label, e.g. NOAA_OISST.AVHRR.v2-1_modified
  modname = modcode_h[4]
  modcode = '.'.join(modcode_h[4:7])
 else:
  # set model label, e.g. <source_id>.historical+ssp126.<variant_label>
  modname = modcode_h[8]
  modcode = modcode_h[8] + '.' + scen_h + '+' + scen_f + '.' + modcode_h[10]
  # check the model names and experiment IDs are the same, only for CMIP6 (skip OBS)
  if not(modcode_h[8] == modcode_f[8]) or not(modcode_h[10] == modcode_f[10]):
   print('--> ERROR: problem in file paths!')
 
 print('Processing... ' + modcode)
 
 # read netcdf filenames from historical and scenario paths
 filenames_h = sorted(glob.glob(modlist_h[m] + '*.nc'))
 filenames_f = sorted(glob.glob(modlist_f[m] + '*.nc'))
 infiles = filenames_h + filenames_f
 infiles = list(dict.fromkeys(infiles))  # remove duplicates, for OBS
 
 # create output filename
 outfile = outpath + 'sst.' + reg_lab + '.' + modcode

 # ----------------------------------------------------------------------
 # Handle some CMIP6 exceptions
 #-----------------------------------------------------------------------
 # EXCEPTION: for IPSL-CM6A-LR, ssp126, there is a problem in the time array in
 # tos_Oday_IPSL-CM6A-LR_ssp126_r1i1p1f1_gn_21010101-23001231.nc, v20190903
 if modcode_f[8]=='IPSL-CM6A-LR' and modcode_f[9]=='ssp126':
  if modcode_f[10]=='r1i1p1f1' and modcode_f[14]=='v20190903':
   infiles=infiles[0:2]
 
 # EXCEPTION: for IPSL-CM6A-LR, ssp585, there is a problem in the time array in
 # tos_Oday_IPSL-CM6A-LR_ssp585_r1i1p1f1_gn_21010101-23001231.nc, v20190903
 if modcode_f[8]=='IPSL-CM6A-LR' and modcode_f[9]=='ssp585':
  if modcode_f[10]=='r1i1p1f1' and modcode_f[14]=='v20190903':
   infiles=infiles[0:2]
 
 # EXCEPTION: for MRI-ESM2-0, ssp126, there is a problem in the time array in
 # tos_Oday_MRI-ESM2-0_ssp126_r1i1p1f1_gn_22510101-23001231.nc, v20210329
 if modcode_f[8]=='MRI-ESM2-0' and modcode_f[9]=='ssp126':
  if modcode_f[10]=='r1i1p1f1' and modcode_f[14]=='v20210329':
   infiles=infiles[0:5]
 
 # EXCEPTION: for MRI-ESM2-0, ssp585, there is a problem in the time array in
 # tos_Oday_MRI-ESM2-0_ssp585_r1i1p1f1_gn_22510101-23001231.nc, v20210329
 if modcode_f[8]=='MRI-ESM2-0' and modcode_f[9]=='ssp585':
  if modcode_f[10]=='r1i1p1f1' and modcode_f[14]=='v20210329':
   infiles=infiles[0:5]
   
 # ----------------------------------------------------------------------
 # End of CMIP6 exceptions
 #-----------------------------------------------------------------------
 
 # load data
 print('Loading data... ')
 start = time.time()
 ds = xr.open_mfdataset(infiles,combine='nested',concat_dim='time')
 end = time.time()
 print(end - start)
 
 # remove duplicate times if historial and scenario runs have overlapping elements
 # this is the case for CESM2/historical/r4i1p1f1/Oday/tos/gn/v20190308,
 # CESM2/ssp126/r4i1p1f1/Oday/tos/gn/v20200528/,
 # and CESM2/ssp585/r4i1p1f1/Oday/tos/gn/v20200528/
 _, index = np.unique(ds['time'], return_index=True)   # set of unique times
 ds = ds.isel(time=index)   # keep only unique times
 
 # rename tos variable in CMIP6 models to sst
 if m != 0:
  ds = ds.rename_vars({'tos':'sst'})
 
 # rename coords if not lat/lon
 if hasattr(ds,'longitude'):
  if hasattr(ds,'lon'):
   print('Warning: this model has both lon and longitude arrays..')
   print('Deleting longitude and latitude...')
   ds = ds.drop_vars({'latitude','longitude'})
  else:
   ds = ds.rename_vars({'longitude':'lon','latitude':'lat'})
 elif hasattr(ds,'nav_lon'):
  ds = ds.rename_vars({'nav_lon':'lon','nav_lat':'lat'})
 
 # store min and max lon, may be required for rotated lon coords
 min_lon = np.min(ds.lon.values)
 max_lon = np.max(ds.lon.values)
 
 print(min_lon)
 print(max_lon)
 
 # trim to required region
 # first case: lon is [0:360]
 if (max_lon > reg_bnds[1]):
  da = ds.where((ds.lon > reg_bnds[0]) & (ds.lon < reg_bnds[1])
    & (ds.lat > reg_bnds[2]) & (ds.lat < reg_bnds[3]), drop=True)
 # second case: lon is [-180:180]
 elif (max_lon > reg_bnds[0]) & (max_lon < reg_bnds[1]):
  da = ds.where(((ds.lon > reg_bnds[0]) | (ds.lon < reg_bnds[1]-360))
    & (ds.lat > reg_bnds[2]) & (ds.lat < reg_bnds[3]), drop=True)
  da = da.assign_coords(lon=(da.lon % 360))  # wrap to [0:360]
 # third case: lon is [-300:60]
 elif (max_lon < reg_bnds[0]):
  da = ds.where((ds.lon > reg_bnds[0]-360) & (ds.lon < reg_bnds[1]-360)
    & (ds.lat > reg_bnds[2]) & (ds.lat < reg_bnds[3]), drop=True)
  da = da.assign_coords(lon=(da.lon % 360))  # wrap to [0:360]
 
 # trim time, and store start and end of time array as labels
 # start at 1 Jan 1982
 # end at 31 Dec 2020 for OBS
 # end at 31 Dec 2100 for models
 # first case: time array is numpy.datetime64
 if np.issubdtype(da.time.dtype, np.datetime64):
  print('Time array: numpy.datetime64')
  da = da.where(da.time >= np.datetime64('1982-01-01T00:00:00'), drop=True)
  if m == 0:    # end at 31 Dec 2020 for OBS
   da = da.where(da.time <= np.datetime64('2020-12-31T23:59:59'), drop=True)
  else:         # end at 31 Dec 2100 for models
   da = da.where(da.time <= np.datetime64('2100-12-31T23:59:59'), drop=True)
   
  tlab1 = np.datetime_as_string(da.time.values[0], unit='Y')
  tlab2 = np.datetime_as_string(da.time.values[-1], unit='Y')
  date_start = np.datetime_as_string(da.time.values[0])
  date_end = np.datetime_as_string(da.time.values[-1])
 else:
  # second case: time array is 365Day calendar
  if type(da.time.values[0]) is cftime.DatetimeNoLeap:
   print('Time array: 365Day calendar')
   da = da.where(da.time >= cftime.DatetimeNoLeap(1982,1,1,0,0,0), drop=True)
   da = da.where(da.time <= cftime.DatetimeNoLeap(2100,12,31,23,59,59), drop=True)
  # third case: time array is 360Day calendar
  elif type(da.time.values[0]) is cftime.Datetime360Day:
   print('Time array: 360Day calendar')
   da = da.where(da.time >= cftime.Datetime360Day(1982,1,1,0,0,0), drop=True)
   da = da.where(da.time <= cftime.Datetime360Day(2100,12,30,23,59,59), drop=True)
  else:
   print('Time array: Not determined (ERROR!)')
  
  tlab1 = da.time.values[0].strftime('%Y')
  tlab2 = da.time.values[-1].strftime('%Y')
  date_start = da.time.values[0].strftime()
  date_end = da.time.values[-1].strftime()
 
 # year span label
 tlab = tlab1 + '-' + tlab2
 print(tlab)
 print('Start: ' + date_start)
 print('End: ' + date_end)
 
 # clear all variables except 'sst'
 varlist = list(ds.data_vars)   # first get the variable list
 varlist.remove('sst')  # remove 'sst' from the list, which will be kept
 da = da.drop_vars(varlist)
 
 # remove zlev parameter from OBS data
 if m == 0:
  da = da.sel(zlev=0, drop=True)
 
 # set zero values to nan (since land is zero in some models)
 da['sst'] = da.sst.where(da.sst > 0)
  
 print('SST dimensions: ')
 print(da.sst.dims)
 
 # create xarray dataset for processed results
 ds_out = da
 ds_out.attrs = {}  # clear attributes
 
 # set coverage_content_type: https://wiki.esipfed.org/Concepts_Glossary
 if m == 0:
  cct = "physicalMeasurement"
 else:
  cct = "modelResult"
 
 # set attributes of variables
 ds_out['sst'] = ds_out.sst.assign_attrs(units=da.sst.attrs['units'], standard_name="sea_surface_temperature", long_name="Sea surface temperature", coverage_content_type=cct)
 
 # set global attributes
 #ds_out.attrs['source_code'] = "https://github.com/jbkajtar/sst_tasmania"
 ds_out.attrs['title'] = "Sea surface temperature data for the Tasmanian region (138E-155E, 49S-35S)"
 #ds_out.attrs['summary'] = "Data generated for "Assessment and communication of risks to Tasmanian aquaculture and fisheries from marine heatwaves: Technical Report" (2021)"
 ds_out.attrs['source_data'] = modcode
 ds_out.attrs['keywords'] = "marine heatwave; extreme event; impact; ocean warming; Tasmania; CMIP6 projections"
 ds_out.attrs['Conventions'] = "ACDD-1.3"
 
 # save dataset to netcdf file
 # save compressed dataset to netcdf file
 comp = dict(zlib=True, complevel=5)
 encoding = {var: comp for var in ds_out.data_vars}
 print('Saving data... ')
 start = time.time()
 ds_out.to_netcdf(outfile + '.nc', encoding=encoding)
 end = time.time()
 print(end - start)

