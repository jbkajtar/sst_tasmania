% JBK 2021-09-16
% post-process SST indices from CMIP6
% subtract seasonal cycle amplitude bias in baseline climatology period
% DEPENDENCIES:
% + requires 'ncdateread' from Climate Data Toolbox (https://github.com/chadagreene/CDT)

clear all;

script_name='p44/pp_cmip6_sst_3-seasonal_bias.m';

mip='cmip6';

%scen_f='ssp126';
scen_f='ssp585';

scen=['historical+' scen_f];

% set paths
sourcepath=[''];   % source directory of mean-bias corrected SST indices (from 'pp_cmip6_sst_2-mean_bias.m')
inpath=[sourcepath];
outpath=[sourcepath];

% baseline climatology period
clim_b=[1983 2012];
clim_time=[datetime(clim_b(1),1,1):datetime(clim_b(2),12,31)]';

% input file: mean-bias corrected SST with corrected calendar
infile=[inpath 'sst_indices.mean_bias_corrected.tas.cmip6.' scen '.nc'];

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

% correct only the amplitude (peak-to-peak) bias in the seasonal cycle
% this is done by matching the standard deviation of the seasonal cycle anomaly to OBS
% compute the seasonal cycle in the baseline period
[~,sst_sc]=daily_climatology(sst,time,clim_time(1),clim_time(end),'standard');

% store the seasonal cycle as an anomaly
sst_sc_anom=sst_sc-mean(sst_sc,3);

% compute the bias in the standard deviation of the seasonal cycle anomaly
sst_sc_std_bias=std(sst_sc_anom,0,3)./std(sst_sc_anom(1,:,:),0,3);

% the desired sst seasonal cycle, with std corrected
sst_sc_adjusted=(sst_sc_anom./sst_sc_std_bias)+mean(sst_sc,3);

% compute the bias in seasonal cycle
sst_sc_bias=sst_sc-sst_sc_adjusted;

% create temporary seasonal cycles for leap year
% fill in Feb 29 with average of Feb 28 and Mar 1
sst_sc_bias_ly=cat(3,sst_sc_bias(:,:,1:59),mean(sst_sc_bias(:,:,[59 60]),3),sst_sc_bias(:,:,60:end));

% remap seasonal cycle bias to whole time-series
kk=find(month(time)==1 & day(time)==1);  % find all Jan 1
clear sst_sc_bias_ts;

% for standard calendar, need to treat leap years separately
dy=365;
ily=leapyear(year(time(kk)));  % check which years are leap years
for ii=1:numel(kk)
 if ily(ii)==1   % map leap years
  sst_sc_bias_ts(:,:,kk(ii):kk(ii)+dy)=sst_sc_bias_ly;
 else            % map non leap years
  sst_sc_bias_ts(:,:,kk(ii):kk(ii)+(dy-1))=sst_sc_bias;
 end
end

% new sst timeseries with seasonal cycle standard deviation correction applied
sst_corr=sst-sst_sc_bias_ts;

% additional variables for netCDF storage
time_dates=time;
time=int64(days(time_dates-datetime(1982,1,1)));  % convert to days since 1982-01-01
sst=sst_corr;
clear sst_corr;

% write to netCDF
f1=[outpath 'sst_indices.mean+seasonal_bias_corrected.tas.cmip6.' scen '.nc'];
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
ncwriteatt(f1,'sst','long_name',['Area-average seasonal cycle amplitude bias corrected sea surface temperature, for Tasmanian regions. Seasonal cycle amplitude bias is computed over the baseline period of ' datestr(clim_time(1),'yyyy-mm-dd') ' to ' datestr(clim_time(end),'yyyy-mm-dd') '. Data is also mean-bias corrected.']);
ncwriteatt(f1,'sst','coverage_content_type','modelResult');


