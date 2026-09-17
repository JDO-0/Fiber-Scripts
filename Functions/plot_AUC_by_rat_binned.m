function plot_AUC_by_rat_binned(data, bin_size, export_to_excel)
% Plot binned AUC data for astrocytes and neurons for each rat
% bin_size: number of trials to average together (default = 5)
% export_to_excel: if true, export data to Excel (default = true)

if nargin < 2
    bin_size = 5;
end

if nargin < 3
    export_to_excel = true;
end

% Get unique rat IDs (excluding rat 18_24 which was skipped)
rat_ids = unique({data.rat_id});

% Initialize cell array to store all export data
all_export_data = {};

for r = 1:length(rat_ids)
    current_rat = rat_ids{r};
    
    % Find all sessions for this rat
    rat_indices = find(strcmp({data.rat_id}, current_rat));
    
    % Initialize arrays to collect data across sessions
    astro_tone_all = [];
    neuron_tone_all = [];
    astro_shock_all = [];
    neuron_shock_all = [];
    
    % Collect data from all sessions for this rat
    for idx = rat_indices
        n_trials = length(data(idx).astro_auc.tone);
        
        % Special case for rat 19_24 session with only 4 trials
        if strcmp(data(idx).rat_id, '19_24') && strcmp(data(idx).session_id, 'Cond')
            n_trials = min(n_trials, 4);
        end
        
        astro_tone_all = [astro_tone_all, data(idx).astro_auc.tone(1:n_trials)];
        neuron_tone_all = [neuron_tone_all, data(idx).neuron_auc.tone(1:n_trials)];
        
        % Add shock data if it's a conditioning session
        if strcmp(data(idx).session_id, 'Cond')
            astro_shock_all = [astro_shock_all, data(idx).astro_auc.shock(1:n_trials)];
            neuron_shock_all = [neuron_shock_all, data(idx).neuron_auc.shock(1:n_trials)];
        else
            % Pad with NaNs for non-conditioning sessions
            astro_shock_all = [astro_shock_all, nan(1, n_trials)];
            neuron_shock_all = [neuron_shock_all, nan(1, n_trials)];
        end
    end
    
    % Calculate number of complete bins
    n_trials = length(astro_tone_all);
    n_bins = floor(n_trials / bin_size);
    
    % Initialize binned arrays
    astro_tone_binned = zeros(1, n_bins);
    neuron_tone_binned = zeros(1, n_bins);
    astro_shock_binned = zeros(1, n_bins);
    neuron_shock_binned = zeros(1, n_bins);
    astro_tone_sem = zeros(1, n_bins);
    neuron_tone_sem = zeros(1, n_bins);
    astro_shock_sem = zeros(1, n_bins);
    neuron_shock_sem = zeros(1, n_bins);
    
    % Bin the data
    for b = 1:n_bins
        bin_start = (b-1) * bin_size + 1;
        bin_end = b * bin_size;
        
        % Tone data
        astro_tone_binned(b) = mean(astro_tone_all(bin_start:bin_end));
        neuron_tone_binned(b) = mean(neuron_tone_all(bin_start:bin_end));
        astro_tone_sem(b) = std(astro_tone_all(bin_start:bin_end)) / sqrt(bin_size);
        neuron_tone_sem(b) = std(neuron_tone_all(bin_start:bin_end)) / sqrt(bin_size);
        
        % Shock data (using nanmean/nanstd to handle NaN values)
        astro_shock_binned(b) = nanmean(astro_shock_all(bin_start:bin_end));
        neuron_shock_binned(b) = nanmean(neuron_shock_all(bin_start:bin_end));
        shock_vals_astro = astro_shock_all(bin_start:bin_end);
        shock_vals_neuron = neuron_shock_all(bin_start:bin_end);
        astro_shock_sem(b) = nanstd(shock_vals_astro) / sqrt(sum(~isnan(shock_vals_astro)));
        neuron_shock_sem(b) = nanstd(shock_vals_neuron) / sqrt(sum(~isnan(shock_vals_neuron)));
    end
    
    % Create bin labels (e.g., "1-5", "6-10", etc.)
    bin_labels = cell(1, n_bins);
    for b = 1:n_bins
        bin_start = (b-1) * bin_size + 1;
        bin_end = b * bin_size;
        bin_labels{b} = sprintf('%d-%d', bin_start, bin_end);
    end
    
    % Prepare data for Excel export
    if export_to_excel
        % Create table for this rat
        export_table = table();
        export_table.Rat_ID = repmat({current_rat}, n_bins, 1);
        export_table.Bin_Number = (1:n_bins)';
        export_table.Trial_Range = bin_labels';
        export_table.Astro_Tone_Mean = astro_tone_binned';
        export_table.Astro_Tone_SEM = astro_tone_sem';
        export_table.Neuron_Tone_Mean = neuron_tone_binned';
        export_table.Neuron_Tone_SEM = neuron_tone_sem';
        export_table.Astro_Shock_Mean = astro_shock_binned';
        export_table.Astro_Shock_SEM = astro_shock_sem';
        export_table.Neuron_Shock_Mean = neuron_shock_binned';
        export_table.Neuron_Shock_SEM = neuron_shock_sem';
        
        % Add to collection
        all_export_data{r} = export_table;
    end
    
    % Create figure for this rat
    figure('Name', sprintf('Rat %s - Binned AUC Analysis', current_rat), 'Position', [100, 100, 1200, 800]);
    
    % Plot Tone responses
    subplot(2, 1, 1);
    hold on;
    x_bins = 1:n_bins;
    
    % Plot with error bars
    errorbar(x_bins, astro_tone_binned, astro_tone_sem, '-o', 'LineWidth', 2, ...
        'MarkerSize', 8, 'MarkerFaceColor', 'auto', 'DisplayName', 'Astrocytes', 'CapSize', 10);
    errorbar(x_bins, neuron_tone_binned, neuron_tone_sem, '-s', 'LineWidth', 2, ...
        'MarkerSize', 8, 'MarkerFaceColor', 'auto', 'DisplayName', 'Neurons', 'CapSize', 10);
    
    yline(0, '--k', 'LineWidth', 1);
    xlabel('Trial Bin');
    ylabel('Mean AUC (z-score·s)');
    title(sprintf('Rat %s - Tone Response AUC (Binned by %d trials)', current_rat, bin_size));
    legend('Location', 'best');
    grid on;
    xlim([0.5, n_bins + 0.5]);
    xticks(x_bins);
    xticklabels(bin_labels);
    xtickangle(45);
    
    % Plot Shock responses
    subplot(2, 1, 2);
    hold on;
    
    % Plot with error bars
    errorbar(x_bins, astro_shock_binned, astro_shock_sem, '-o', 'LineWidth', 2, ...
        'MarkerSize', 8, 'MarkerFaceColor', 'auto', 'DisplayName', 'Astrocytes', 'CapSize', 10);
    errorbar(x_bins, neuron_shock_binned, neuron_shock_sem, '-s', 'LineWidth', 2, ...
        'MarkerSize', 8, 'MarkerFaceColor', 'auto', 'DisplayName', 'Neurons', 'CapSize', 10);
    
    yline(0, '--k', 'LineWidth', 1);
    xlabel('Trial Bin');
    ylabel('Mean AUC (z-score·s)');
    title(sprintf('Rat %s - Shock Response AUC (Binned by %d trials)', current_rat, bin_size));
    legend('Location', 'best');
    grid on;
    xlim([0.5, n_bins + 0.5]);
    xticks(x_bins);
    xticklabels(bin_labels);
    xtickangle(45);
end

% Export all data to Excel
if export_to_excel && ~isempty(all_export_data)
    % Combine all rat data into one table
    combined_table = vertcat(all_export_data{:});
    
    % Create filename with timestamp
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    filename = sprintf('Binned_AUC_Data_bin%d_%s.xlsx', bin_size, timestamp);
    
    % Write to Excel
    writetable(combined_table, filename);
    fprintf('Data exported to: %s\n', filename);
end

end