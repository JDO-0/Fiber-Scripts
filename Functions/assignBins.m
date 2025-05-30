function [bin_id] = assignBins(bin_in_minutes, pain_timeStamps)

%% Convert the bin from minutes to seconds %%
bin_in_seconds = bin_in_minutes * 60;
bin = 1;
bin_id = NaN(1,length(pain_timeStamps));

for i = 1:length(pain_timeStamps)
    assigned = false;
    while ~assigned
        if pain_timeStamps(i) <= (bin_in_seconds * bin)
            bin_id(i) = bin;
            assigned = true;
        else
            bin = bin + 1;
        end
    end
end

clear bin bin_in_seconds bin_in_minutes pain_timeStamps i assigned

end