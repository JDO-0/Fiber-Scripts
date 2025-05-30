function graphGreen_RedFiber(data, peakinfo)

TimeB = linspace(1/1017.253, length(data.astro_dFF)/1017.253, length(data.astro_dFF));

%% Plot dF/F
figure
subplot(2, 1, 1)
plot(TimeB,data.astro_dFF, 'LineWidth', 2, 'Color', 'g');
hold on;
plot(TimeB,data.neuron_dFF, 'LineWidth', 2, 'Color', 'r');

for i = 1:length(data.epocs.oTon.onset)
    tone_time = data.epocs.oTon.onset(i):1:data.epocs.oTon.offset(i);
    plot(tone_time, 6, 'k*')
end

for i = 1:length(data.epocs.Tick.notes.index)
    event_time = data.epocs.Tick.notes.ts(i);
    plot(event_time, data.epocs.Tick.notes.index(i) * 5, 'b^')
end

if data.session_id == "Cond"
    for i = 1:length(data.epocs.oSho.onset)
        shock_time = data.epocs.oSho.onset(i):1:data.epocs.oSho.offset(i)
        plot(shock_time, 6.5, 'c*')
    end
end

xlabel('{\bfTime} (seconds)', 'FontSize', 18);
ylabel('{\bf\Delta{\itF/F}} (%)', 'FontSize', 18);
title(data.info.blockname, 'FontSize', 18);

if data.session_id == "Cond"
    legend({'465 nm', '560 nm', 'tone', 'freeze', 'shock'},'Fontsize',16, 'Location', 'northeast');
else
    legend({'465 nm', '560 nm', 'tone', 'freeze'},'Fontsize',16, 'Location', 'northeast');
end

%% Plot z-scores
subplot(2, 1, 2)
plot(TimeB,data.astro_z, 'LineWidth', 2, 'Color', 'g');
hold on;
plot(TimeB,data.neuron_z, 'LineWidth', 2, 'Color', 'r');

for i = 1:length(data.epocs.oTon.onset)
    tone_time = data.epocs.oTon.onset(i):1:data.epocs.oTon.offset(i);
    plot(tone_time, 6, 'k*')
end

for i = 1:length(data.epocs.Tick.notes.index)
    event_time = data.epocs.Tick.notes.ts(i);
    plot(event_time, data.epocs.Tick.notes.index(i) * 5, 'b^')
end

if data.session_id == "Cond"
    for i = 1:length(data.epocs.oSho.onset)
        shock_time = data.epocs.oSho.onset(i):1:data.epocs.oSho.offset(i)
        plot(shock_time, 6.5, 'c*')
    end
end

xlabel('{\bfTime} (seconds)', 'FontSize', 18);
ylabel('{\bfz-scores}', 'FontSize', 18);
title(data.info.blockname, 'FontSize', 18);

if data.session_id == "Cond"
    legend({'490 nm', '560 nm', 'tone', 'freeze', 'shock'},'Fontsize',16, 'Location', 'northeast');
else
    legend({'490 nm', '560 nm', 'tone', 'freeze'},'Fontsize',16, 'Location', 'northeast');
end

end