% JBK 2021-09-24
% read SST fields, in OBS and models
% store 1983-2012 mean SST, for plotting Fig. 1 and 2 in technical report

clear all;

script_name='pp_mean_sst_field.m';

scen_f='ssp126';

scen=['historical+' scen_f];

% set paths
sourcepath=[''];   % source directory of data
inpath=[sourcepath 'sst/'];
outpath=[sourcepath 'mean_sst_field/'];

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
dirlist=dir([inpath 'sst.tas.*' scen '*.nc']);
mmax=length(dirlist)+1;  % +1 for observations

% store full paths to data, but use observations as first set
infiles{1}=[inpath 'sst.tas.NOAA_OISST.AVHRR.v2-1_modified.nc'];
infiles(2:mmax)=strcat(inpath,{dirlist.name});

for m=1:mmax

 % model label
 modcode=strrep(infiles{m},[inpath 'sst.tas.'],'');
 modcode=strrep(modcode,['.nc'],'');

 disp([num2str(m) ': ' modcode]);

 % load data
 sst1=ncread(infiles{m},'sst');
 lat=ncread(infiles{m},'lat');
 lon=ncread(infiles{m},'lon');
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
  last_cdoy=clim_time(end)-1;
 elseif any(strcmp(time_cal,{'365_day','noleap'}))
  time_calendar='noleap';
  cal_basis=7;
  last_doy=time(end);
  last_cdoy=clim_time(end);
 elseif any(strcmp(time_cal,{'gregorian','proleptic_gregorian','standard'}))
  time_calendar='standard';
  cal_basis=0;
  if strcmp(modcode,'NOAA_OISST.AVHRR.v2-1_modified')
   last_doy=datetime(2020,12,31);
  else
   last_doy=time(end);
  end
  last_cdoy=clim_time(end);
 end
 
 if daysadd(time_unt,double(time_days(end)),cal_basis)~=last_doy;
  error('ERROR: problem in time array!');
 end
 
 time1=daysadd(time_unt,double(time_days),cal_basis);
 
 t1=find(time1==clim_time(1));
 t2=find(time1==last_cdoy);
 disp('Climatology span:');
 disp(time1(t1));
 disp(time1(t2));
 
 % trim SST to required climatology span, and take mean
 sst=mean(sst1(:,:,t1:t2),3);
 
 % save data
 outfile=[outpath 'sst_mean.' modcode '.mat'];
 save(outfile,'sst','lat','lon','script_name','-v7.3');

 clear sst;
end

