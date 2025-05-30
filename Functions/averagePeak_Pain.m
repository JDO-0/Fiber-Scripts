function [tone_average] = averagePeak_Pain(locs, peaks, pain_event)

tone_sum = 0;
tone_count = 0;

for i = 1:length(locs)
    %% Locations reflect the location from the smaller window passed to the peak find function.
    %% window_x will reflect the correct time (location) for the entire experiment.
    window_x = (pain_event - 1) + locs(i);
    if window_x > (pain_event - 1) && window_x < (pain_event + 15)
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