function fearFiber_graph_allTones(data)
%% Create graphs of all tone presentations across all sessions.
for i = 1:length(data)
    figure('Name', [data(i).rat_id, ' ', data(i).session_id])
    fig_index = 1;
    for j = 1:length(data(i).epocs.oTon.data)
    	if round((data(i).epocs.oTon.offset(j) * samplingRate) + (20 * samplingRate)) > numel(data(i).astro_z)
        	break
    	end
        if ~strcmp(data(i).session_id, 'Cond')
            Start = round((data(i).epocs.oTon.onset(j) * samplingRate) - (10 * samplingRate));
            End = round((data(i).epocs.oTon.offset(j) * samplingRate) + (20 * samplingRate));
            subplot(5,2,fig_index);
    		title(['Tone', ' ', num2str(j)]);
            TimeSec = linspace(1/samplingRate, length(data(i).astro_z(Start:End))/samplingRate, length(data(i).astro_z(Start:End)));
            yyaxis left; % Astrocyte data on the left axis.
            plot(TimeSec, data(i).astro_z(Start:End), 'LineWidth', 4, 'Color', 'g'); hold on; box off;
            xlim([0 60]);
            ylim([-2 8]);
            set(gca, 'FontName', 'Helvetica', 'FontSize', 12, 'LineWidth', 3);
    		if ~isempty(data(i).neuron_z)
                yyaxis right; % Neuron data on the right axis.
                ylim([-2 4]);
                yticks([-2 0 2 4]);
                plot(TimeSec, data(i).neuron_z(Start:End), 'LineWidth', 4, 'Color', 'r');
    		end
            rectangle('Position', [10 -2 30 8], 'FaceColor', [0.8500 0.3250 0.0980], 'FaceAlpha', 0.2, 'LineStyle', 'none');
            ax = gca;
            ax.YAxis(1).Color = 'k';
            ax.YAxis(2).Color = 'k';
            fig_index = fig_index + 1;
        else
            Start = round((data(i).epocs.oTon.onset(j) * samplingRate) - (10 * samplingRate));
            End = round((data(i).epocs.oTon.offset(j) * samplingRate) + (20 * samplingRate));
            subplot(5,2,fig_index);
    		title(['Tone', ' ', num2str(j)]);
            TimeSec = linspace(1/samplingRate, length(data(i).astro_z(Start:End))/samplingRate, length(data(i).astro_z(Start:End)));
            yyaxis left; % Astrocyte data on the left axis.
            plot(TimeSec, data(i).astro_z(Start:End), 'LineWidth', 4, 'Color', 'g'); hold on; box off;
            xlim([0 60]);
            ylim([-2 8]);
            set(gca, 'FontName', 'Helvetica', 'FontSize', 12, 'LineWidth', 3);
    		if ~isempty(data(i).neuron_z)
                yyaxis right; % Neuron data on the right axis.
                ylim([-2 4]);
                yticks([-2 0 2 4]);
                plot(TimeSec, data(i).neuron_z(Start:End), 'LineWidth', 4, 'Color', 'r');
    		end
            rectangle('Position', [10 -2 30 10], 'FaceColor', [0.8500 0.3250 0.0980], 'FaceAlpha', 0.2, 'LineStyle', 'none');
            rectangle('Position', [39 -2 1 10], 'FaceColor', 'y', 'FaceAlpha', 0.4, 'LineStyle', 'none');
            ax = gca;
            ax.YAxis(1).Color = 'k';
            ax.YAxis(2).Color = 'k';
            fig_index = fig_index + 1;
        end
    end
end

clear Start End shock_time tone_time TimeSec i j fig_index