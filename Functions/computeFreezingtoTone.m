function percent_freezing = computeFreezingtoTone(ToneOn, ToneOff, Freezing)

k = 1;
count = 0;
ToneOn = round(ToneOn);
ToneOff = round(ToneOff);
while round(Freezing.ts(k)) <= ToneOff && k < length(Freezing.ts)
    if round(Freezing.ts(k)) >= ToneOn && Freezing.index(k) == 1
        count = count + 1;
        k = k + 1;
    else
        k = k + 1;
    end
end

%% The Freezing is recorded in seconds. This will record the percent freezing during each tone.
percent_freezing = (count / (ToneOff - ToneOn)) * 100;
if percent_freezing > 100
    percent_freezing = 100;
end

end
