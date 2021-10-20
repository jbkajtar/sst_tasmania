% JBK 2021-09-16
% post-process SST indices from CMIP6
% subtract mean bias in baseline climatology period
% DEPENDENCIES:
% + requires 'ncdateread' from Climate Data Toolbox (https://github.com/chadagreene/CDT)

clear all;

script_name='pp_cmip6_sst_2-mean_bias.m';

mip='cmip6';

%scen_f='ssp126';
scen_f='ssp585';

scen=['historical+' scen_f];

% set paths
sourcepath=[''];  % source directory of calendar corrected SST indices (from 'pp_cmip6_sst_1-raw.m')
inpath=[sourcepath];
outpath=[sourcepath];

% baseline climatology period
clim_b=[1983 2012];
clim_time=[datetime(clim_b(1),1,1):datetime(clim_b(2),12,31)]';

% input file: raw SST with corrected calendar
infile=[inpath 'sst_indices.raw.tas.cmip6.' scen '.nc'];

% read data
sst=ncread(infile,'sst');
time=ncdateread(infile,'time');
model_name=ncread(infile,'model_name');
abbrevs=ncread(infile,'abbrevs');
region=ncread(infile,'region');
names=ncread(infile,'names');

% convert labels to strings
regcode=deblank(string(abbrevs));
modcode=deblank(string(model_name));

% compute bias in mean temperature over baseline climatology period
[t1,t2]=findrange(time,clim_time(1),clim_time(end));
sst_mean=mean(sst(:,:,t1:t2),3);
sst_mean_bias=sst_mean-sst_mean(1,:);

% mean-bias correction
sst_corr=sst-sst_mean_bias;

% additional variables for netCDF storage
time_dates=time;
time=int64(days(time_dates-datetime(1982,1,1)));  % convert to days since 1982-01-01
sst=sst_corr;
clear sst_corr;

% write to netCDF
f1=[outpath 'sst_indices.mean_bias_corrected.tas.cmip6.' scen '.nc'];
fmt='netcdf4_classic';

nccreate(f1,'time', 'Dimensions',{'time',length(time)},'Datatype','int32','Format',fmt);
ncwrite(f1,'time',time);
ncwriteatt(f1,'time','units','days since 1982-01-01');
ncwriteatt(f1,'time','calendar','proleptic_gregorian');
ncwriteatt(f1,'time','standard_name','time');
ncwriteatt(f1,'time','axis','T');

nccreate(f1,'region', 'Dimensions',{'region',length(region)},'Datatype','int32','Format',fmt);
ncwrite(f1,'region',region);
ncwriteatt(f1,'region','long_name','region_index');

nccreate(f1,'model_name', 'Dimensions',{'model_name',size(model_name,1),'charlen1',size(model_name,2)}, 'Datatype','char', 'Format',fmt);
ncwrite(f1,'model_name',model_name);
ncwriteatt(f1,'model_name','units','1');
ncwriteatt(f1,'model_name','long_name','Names of observational (NOAA_OISST) or model data sources');

nccreate(f1,'abbrevs', 'Dimensions',{'region',length(region),'charlen2',size(abbrevs,2)}, 'Datatype','char', 'Format',fmt);
ncwrite(f1,'abbrevs',abbrevs);
ncwriteatt(f1,'abbrevs','units','1');
ncwriteatt(f1,'abbrevs','long_name','Abbreviations for index regions');

nccreate(f1,'names', 'Dimensions',{'region',length(region),'charlen3',size(names,2)}, 'Datatype','char', 'Format',fmt);
ncwrite(f1,'names',names);
ncwriteatt(f1,'names','units','1');
ncwriteatt(f1,'names','long_name','Names of index regions');

nccreate(f1,'sst', 'Dimensions',{'model_name',size(model_name,1),'region',length(region),'time',length(time)}, 'Datatype','single', 'Format',fmt, 'DeflateLevel',5);
ncwrite(f1,'sst',sst);
ncwriteatt(f1,'sst','units','degree_C');
ncwriteatt(f1,'sst','standard_name','sea_surface_temperature');
ncwriteatt(f1,'sst','long_name',['Area-average mean-bias corrected sea surface temperature, for Tasmanian regions. Mean bias is computed over the baseline period of ' datestr(clim_time(1),'yyyy-mm-dd') ' to ' datestr(clim_time(end),'yyyy-mm-dd')]);
ncwriteatt(f1,'sst','coverage_content_type','modelResult');


