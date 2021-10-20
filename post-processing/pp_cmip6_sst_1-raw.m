% JBK 2021-09-02
% post-process SST indices from CMIP6
% interpolate data to common Gregorian calendar, store all data in one file

clear all;

script_name='p44/pp_cmip6_sst_1-raw.m';

mip='cmip6';

%scen_f='ssp126';
scen_f='ssp585';

scen=['historical+' scen_f];

% set paths
sourcepath=[''];  % source directory of SST indices (from 'compute_tas_sst_indices.py')
inpath=[sourcepath 'sst_indices/'];
outpath=[sourcepath];

% baseline climatology period
clim_b=[1983 2012];
clim_time=[datetime(clim_b(1),1,1):datetime(clim_b(2),12,31)]';

% span of analysis
yrs=[1982 2100];
yrlab=[num2str(yrs(1)) '-' num2str(yrs(2))];
time_span=[datetime(yrs(1),1,1) datetime(yrs(2),12,31)];
ny=yrs(2)-yrs(1)+1;
time=[datetime(1982,1,1):datetime(2100,12,31)]';  % common time array

% read models in path
dirlist=dir([inpath 'sst_indices.tas.*' scen '*.nc']);
mmax=length(dirlist)+1;  % +1 for observations

% store full paths to data, but use observations as first set
infiles{1}=[inpath 'sst_indices.tas.NOAA_OISST.AVHRR.v2-1_modified.nc'];
infiles(2:mmax)=strcat(inpath,{dirlist.name});

% initialise array
sst_idx=nan(mmax,5,length(time));

for m=1:mmax

 % model label
 if m==1
  modname='NOAA_OISST';
  abbrevs=ncread(infiles{m},'abbrevs')';
  reg_code=deblank(string(abbrevs));
  region=ncread(infiles{m},'region');
  names=ncread(infiles{m},'names')';
 else
  modname=strrep(dirlist(m-1).name,['sst_indices.tas.'],'');
  modname=strrep(modname,['.' scen],'');
  modname=regexprep(modname,'.r\w*i\w*p\w*.nc','');
 end
  
 disp([num2str(m) ': ' modname]);
 modcode{m}=modname;

 % load data
 sst1=ncread(infiles{m},'sst');
 time_days=ncread(infiles{m},'time');
  
 % read calendar information
 time_cal=ncreadatt(infiles{m},'time','calendar');
 time_unt=ncreadatt(infiles{m},'time','units');
 time_unt=strrep(time_unt,'days since ','');
 disp(time_cal)
 time_unt=datetime(regexprep(time_unt,'T',' '));
 time_unt=dateshift(time_unt,'start','day');  % shift to midnight

 % create correct time array based on calendar type, rename calendars
 if strcmp(time_cal,'360_day')
  time_calendar='360';
  cal_basis=4;
  last_doy=time(end)-1;
 elseif any(strcmp(time_cal,{'365_day','noleap'}))
  time_calendar='noleap';
  cal_basis=7;
  last_doy=time(end);
 elseif any(strcmp(time_cal,{'gregorian','proleptic_gregorian','standard'}))
  time_calendar='standard';
  cal_basis=0;
  if strcmp(modcode{m},'NOAA_OISST')
   last_doy=datetime(2020,12,31);
  else
   last_doy=time(end);
  end
 end
 
 if daysadd(time_unt,double(time_days(end)),cal_basis)~=last_doy;
  error('ERROR: problem in time array!');
 end

 % interpolate to standard calendar
 clear sst_i;
 if strcmp(time_calendar,'360')
  % for 360 day calendars, interpolate entire time-series
  time1=linspace(time(1),time(end),length(time_days));
  sst_i=interp1(time1,sst1',time,'pchip')';   % pchip slightly improved than linear
 elseif strcmp(time_calendar,'noleap')
  % for noleap calendars, interpolate only to Feb 29
  time1=daynoleap2datenum(double(time_days),year(time_unt),'dt');
  % copy values to correct dates
  [~,I,~]=intersect(time,time1);
  sst_i(:,I)=sst1;
  tt=find(month(time)==2 & day(time)==29);  % find all leap days
  sst_i(:,tt)=mean(cat(3,sst_i(:,tt-1),sst_i(:,tt+1)),3);
 else
  % otherwise, no correction required
  sst_i=sst1;
 end

 % store in global array
 sst_idx(m,:,1:length(sst_i))=sst_i;
end

% additional variables for netCDF storage
model_name=char(modcode);
time_dates=time;
time=int64(days(time_dates-datetime(1982,1,1)));  % convert to days since 1982-01-01
sst=sst_idx;
clear sst_idx;

% write to netCDF
f1=[outpath 'sst_indices.raw.tas.cmip6.' scen '.nc'];
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
ncwriteatt(f1,'sst','long_name','Area-average raw sea surface temperature, for Tasmanian regions, with common calendar');
ncwriteatt(f1,'sst','coverage_content_type','modelResult');
