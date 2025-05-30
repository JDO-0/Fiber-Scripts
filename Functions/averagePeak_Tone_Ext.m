function [tone_average] = averagePeak_Tone_Ext(locs, peaks, tone_start, tone_end)

tone_sum = 0;
tone_count = 0;

for i = 1:length(locs)
    %% Locations reflect the location from the smaller window passed to the peak find function.
    %% window_x will reflect the correct time (location) for the entire experiment.
    window_x = (tone_start - 10) + locs(i);
    if window_x > tone_start && window_x < (tone_end)
        tone_sum = tone_sum + peaks(i);
        tone_count = tone_count + 1;
    else
        continue
    end
end
if tone_count ~= 0
    tone_average = tone_sum / tone_count;
else
    tone_average = NaN;
end

end