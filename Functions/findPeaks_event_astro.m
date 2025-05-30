function [] = findPeaks_event_astro()

[pks,locs,w,p]=findpeaks(dFoverFWhole_x465A,1017.253,'MinPeakHeight',0.1,'MinPeakDistance',1.0,'MinPeakWidth',1.0,'MinPeakProminence',0.1);

pks=transpose(pks);
Nvalues = numel(pks);
locs=transpose(locs);
w=transpose(w);
p=transpose(p);

mean_peak_amplitude=mean(pks);%this is the peak amplitude
peaksem=std(pks)/sqrt(Nvalues);

mean_peak_prominence=mean(p);%this is the peak prominence
psem=std(p)/sqrt(Nvalues);

mean_peak_width=mean(w);
widthsem=std(w)/sqrt(Nvalues);

IEI = (diff(locs));
MeanIEI = mean(IEI);
StdMeanIEI = std(IEI);
SEMMeanIEI = StdMeanIEI/sqrt(Nvalues);

MedAbsDev = mad(dFoverFWhole_x465A,1);

TimeB = linspace(1/1017.253, length(dFoverFWhole_x465A)/1017.253, length(dFoverFWhole_x465A));