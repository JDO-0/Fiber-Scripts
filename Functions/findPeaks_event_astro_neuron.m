function [p_a, locs_a, p_n, locs_n] = findPeaks_event_astro_neuron(astro_z, neuron_z)

[pks_a,locs_a,w_a,p_a]=findpeaks(astro_z,1017.253,'MinPeakDistance',1.0,'MinPeakWidth',1.0,'MinPeakProminence',0.1);
[pks_n,locs_n,w_n,p_n]=findpeaks(neuron_z,1017.253,'MinPeakDistance',1.0,'MinPeakWidth',1.0,'MinPeakProminence',0.1);

pks_a=transpose(pks_a);
Nvalues_a = numel(pks_a);
locs_a=transpose(locs_a);
w_a=transpose(w_a);
p_a=transpose(p_a);

pks_n=transpose(pks_n);
Nvalues_n = numel(pks_n);
locs_n=transpose(locs_n);
w_n=transpose(w_n);
p_n=transpose(p_n);

end