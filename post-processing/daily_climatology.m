% JBK 2021-09-03
% compute the daily seasonal climatology over a given period
% clim_s and clim_e: start and end dates of climatological base-line
% can handle different calendars, but requires testing
% temp: need last non-singleton dimension to equal length of time array
% time_cal: 360, noleap, or standard
% clim_ts: return seasonally varying climatology over the whole baseline period
% clim: return the seasonal climatology for one year (360 or 365 days)

function [clim_ts,clim]=detect(temp,time,clim_s,clim_e,time_cal)

% make sure climatology start and end values are in same format as time array
clim_s.Format=time.Format;
clim_e.Format=time.Format;

% handle temp 1D vectors and 3D arrays by reshaping
Sinit=size(temp);    % initial size of array
ndim=sum(Sinit~=1);  % count the number of non-singleton dimensions

% for 1D arrays, make sure it is a row vector
if ndim==1
 if ~isrow(temp)
  temp=temp';
 end
 templen=numel(temp);
% for 3D arrays, convert to 2D array
elseif ndim==3
 temp=reshape(temp,[Sinit(1)*Sinit(2) Sinit(3)]);
 templen=Sinit(3);
else
 templen=Sinit(2);
end

if templen~=length(time)
 error('ERROR: time dimension of temp does not match length of time array!');
end

% determine calendar
if strcmp(time_cal,'360')
 dy=360;
elseif strcmp(time_cal,'noleap')
 dy=365;
elseif strcmp(time_cal,'standard')
 dy=365;
end

% for building climatological seasonal cycle, trim to required start and end dates
% compare dates but ignore hours, minutes, seconds
i1=find(year(time)==year(clim_s) & month(time)==month(clim_s) & day(time)==day(clim_s));
i2=find(year(time)==year(clim_e) & month(time)==month(clim_e) & day(time)==day(clim_e));
T_tmp=temp(:,i1:i2);
time_tmp=time(i1:i2);

% with standard calendar, for climatology, temporarily ignore Feb 29
if strcmp(time_cal,'standard')
 ii=find(month(time_tmp)==2 & day(time_tmp)==29);
 T_tmp(:,ii)=[];
end

% compute seasonal cycle at each grid-point
% for each calendar day, average over an 11-day period around that date
S=size(T_tmp);
% this assumes that climatological period starts on Jan 1, and contains
% an integer number of complete calendar years
idoy=repmat([1:dy]',[S(2)/dy 1]);
hw=5;   % same as vWindowHalfWidth in m_mhw
clear clim;
for kk=1:dy
 % range of indices to average over
 inds=kk-hw:kk+hw;
 
 % for indices near start/end of calendar, wrap
 inds(inds<1)=inds(inds<1)+dy;
 inds(inds>dy)=inds(inds>dy)-dy;

 T1=T_tmp(:,ismember(idoy,inds));
 clim(:,kk)=mean(T1,2);
end

% smooth the resulting seasonal cycle
smth_len=31;   % same as vsmoothPercentileWidth in m_mhw
clim_pad=repmat(clim,[1 3]); % repeat seasonal cycle 3 times for smoothing
clim_pad=movmean(clim_pad,smth_len,2);
clim=clim_pad(:,(dy+1):(dy+1)+(dy-1));  % retain only central cycle
clear clim_pad;

% for standard calendar, create temporary seasonal cycles for leap year
% fill in Feb 29 with average of Feb 28 and Mar 1
if strcmp(time_cal,'standard')
 clim_ly=cat(2,clim(:,1:59),mean(clim(:,[59 60]),2),clim(:,60:end));
end

% now map the seasonal cycle to the original calendar
kk=find(month(time)==1 & day(time)==1);  % find all Jan 1
clear clim_ts;

% for standard calendar, need to treat leap years separately
if strcmp(time_cal,'standard')
 ily=leapyear(year(time(kk)));  % check which years are leap years
 for ii=1:numel(kk)
  if ily(ii)==1   % map leap years
   clim_ts(:,kk(ii):kk(ii)+dy)=clim_ly;
  else            % map non leap years
   clim_ts(:,kk(ii):kk(ii)+(dy-1))=clim;
  end
 end
% for other calendars, just map based on year length
else
 for ii=1:numel(kk)
  clim_ts(:,kk(ii):kk(ii)+(dy-1))=clim;
 end
end

% need to reshape mclim, m90, and mhw_ts if data was originally 3D
if ndim==3
 clim=reshape(clim,[Sinit(1) Sinit(2) size(clim,2)]);
 clim_ts=reshape(clim_ts,[Sinit(1) Sinit(2) size(clim_ts,2)]);
end


return

