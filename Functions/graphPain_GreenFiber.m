function graphPain_GreenFiber(data)

TimeB = linspace(1/1017.253, length(data.astro_dFF)/1017.253, length(data.astro_dFF));

%% Plot dF/F
figure
subplot(2, 1, 1)
plot(TimeB,data.astro_dFF, 'LineWidth', 2, 'Color', 'g');
hold on;

if ~strcmp(data.session_id, 'PreTest')
    for i = 1:length(data.epocs.Pain.onset)
        pain_time = data.epocs.Pain.onset(i);
        plot(pain_time, 6, 'k*')
    end
end

for i = 1:length(data.astro_loc)
    plot(data.astro_loc(i), 5, 'g*')
end

xlabel('{\bfTime} (seconds)', 'FontSize', 18);
ylabel('{\bf\Delta{\itF/F}} (%)', 'FontSize', 18);
title(data.info.blockname, 'FontSize', 18);

legend({'465 nm', 'pain event'},'Fontsize',16, 'Location', 'northeast');

%% Plot z-scores
subplot(2, 1, 2)
plot(TimeB,data.astro_z, 'LineWidth', 2, 'Color', 'g');
hold on;

if ~strcmp(data.session_id, 'PreTest')
    for i = 1:length(data.epocs.Pain.onset)
        pain_time = data.epocs.Pain.onset(i);
        plot(pain_time, 6, 'k*')
    end
end

for i = 1:length(data.astro_loc)
    plot(data.astro_loc(i), 5, 'g*')
end

xlabel('{\bfTime} (seconds)', 'FontSize', 18);
ylabel('{\bfz-scores}', 'FontSize', 18);
title(data.info.blockname, 'FontSize', 18);

legend({'465 nm', 'pain event'},'Fontsize',16, 'Location', 'northeast');

end