function [tone_average, shock_average] = averagePeak_Tone(locs, peaks, tone_start, tone_end)

tone_sum = 0;
tone_count = 0;
shock_sum = 0;
shock_count = 0;

for i = 1:length(locs)
    %% Locations reflect the location from the smaller window passed to the peak find function.
    %% window_x will reflect the correct time (location) for the entire experiment.
    window_x = (tone_start - 10) + locs(i);
    if window_x > tone_start && window_x < (tone_end - 1)
        tone_sum = tone_sum + peaks(i);
        tone_count = tone_count + 1;
    elseif window_x > (tone_end - 1)
        shock_sum = shock_sum + peaks(i);
        shock_count = shock_count + 1;
    else
        continue
    end
end
if tone_count ~= 0
    tone_average = tone_sum / tone_count;
else
    tone_average = NaN;
end
if shock_count ~= 0
    shock_average = shock_sum / shock_count;
else
    shock_average = NaN;
end

end