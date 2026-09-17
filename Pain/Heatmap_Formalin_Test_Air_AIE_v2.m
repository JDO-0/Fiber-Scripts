%% ============================================================================
%% FIBER PHOTOMETRY ANALYSIS PIPELINE (POOLED Z-SCORE VERSION)
%% Import -> Treatment/Condition tagging -> dF/F -> Filter -> POOLED Z-score ->
%% Bin -> Heatmap/Histogram (per session condition x treatment group) ->
%% GraphPad export
%%
%% Difference from the standard version: instead of z-scoring each session
%% to its OWN mean/std (which forces every session to mean~0, std~1 and
%% erases between-group differences in overall activity), this version
%% computes ONE shared mean/std per channel, pooled across every animal and
%% every session that passed filtering, and applies that same normalization
%% to all traces. This preserves real differences in activity magnitude
%% between treatment groups / session conditions while still correcting for
%% animal-to-animal differences in baseline signal size (expression level,
%% fiber coupling, etc.) the way raw dF/F cannot.
%% ============================================================================

%% ============================================================================
%% SECTION 0: CONFIGURATION - EDIT THIS SECTION FOR YOUR EXPERIMENT
%% ============================================================================

% --- Paths ---
data_folder     = 'E:\Pilot Pain Dual FP Videos';
MATLAB_FX_PATH  = 'D:\jdani\OneDrive\Documents\Education\MUSC Postdoc\Lab Management\Code\MATLAB\Functions';
addpath(genpath(MATLAB_FX_PATH));

output_folder = fullfile(data_folder, 'Analysis_Output');
export_folder = fullfile(output_folder, 'GraphPad_Export');
if ~exist(output_folder, 'dir'); mkdir(output_folder); end
if ~exist(export_folder, 'dir'); mkdir(export_folder); end

% --- Animal ID -> Treatment group map (AIR vs AIE) ---
% Add/edit entries here. Keys must match the animal ID exactly as it
% appears in the filename (case-insensitive matching is applied below).
group_map = containers.Map();
group_map('856B') = 'AIR';
group_map('856C') = 'AIR';
group_map('855C') = 'AIE';
% group_map('XXXX') = 'AIE';   % <- add more animals here

% --- Expected filename pattern ---
% e.g. "856C-260909-171021-Formalin"  ->  AnimalID - YYMMDD - HHMMSS - Condition
% Only files whose AnimalID is a key in group_map AND whose Condition is
% "Formalin" or "Saline" are imported; everything else is skipped.
filename_pattern = '^(?<id>[A-Za-z0-9]+)-(?<date>\d{6})-(?<time>\d{6})-(?<cond>\w+)$';

% --- Analysis settings ---
bin_width_min       = 5;                       % <-- ADJUSTABLE bin width (minutes)
channels_to_analyze = {'GCAMP', 'srGECO'};     % channels to z-score/bin/plot/heatmap
session_conds       = {'Formalin', 'Saline'};  % session condition labels
treatment_grps      = {'AIR', 'AIE'};          % treatment group labels
make_plots          = true;                    % set false to skip group figures (export only)
make_qc_plots       = true;                    % set false to skip per-session dF/F + z-score QC figures

% --- Pain event analysis settings ---
pain_onset_unit     = 'ms';      % 'ms' or 'sec' - unit of data(i).epocs.Pain.onset values
pain_bout_iei_sec   = 3;         % <-- ADJUSTABLE: onsets closer together than this (sec) are
                                  %     grouped into one "bout", anchored at the bout's first event
peth_window_sec     = [-10 10];  % <-- ADJUSTABLE PETH window around each bout onset (sec)
                                  %     Keep this <= pain_bout_iei_sec on each side so PETH windows
                                  %     from neighboring bouts can't overlap/contaminate each other
peth_baseline_sec   = [-10 0];   % window used as "pre" baseline for the PETH stats
peth_response_sec   = [0 10];    % window used as "post" response for the PETH stats
n_permutations      = 1000;      % permutations for circular-shift null tests (pain event analysis)
make_pain_plots     = true;      % set false to skip pain-event figures (export only)

%% ============================================================================
%% SECTION 1: IMPORT RAW TDT DATA
%% ============================================================================
raw_data = getTDTFiles(data_folder);

%% ============================================================================
%% SECTION 2: FILTER BY FILENAME + ASSIGN TREATMENT GROUP & SESSION CONDITION
%% ============================================================================
keep_idx  = false(1, length(raw_data));
animal_id = cell(1, length(raw_data));
condition = cell(1, length(raw_data));

for i = 1:length(raw_data)
    blockname = raw_data(i).info.blockname;
    tok = regexp(blockname, filename_pattern, 'names');

    if isempty(tok)
        fprintf('Skipping "%s": filename does not match expected pattern (ID-YYMMDD-HHMMSS-Condition).\n', blockname);
        continue
    end

    id = upper(tok.id);

    % Match against group_map keys case-insensitively
    matched_key = '';
    map_keys = keys(group_map);
    for m = 1:length(map_keys)
        if strcmpi(map_keys{m}, id)
            matched_key = map_keys{m};
            break
        end
    end

    if isempty(matched_key)
        fprintf('Skipping "%s": animal ID "%s" not found in group_map.\n', blockname, id);
        continue
    end

    cond_raw = lower(tok.cond);
    if strcmp(cond_raw, 'formalin')
        cond = 'Formalin';
    elseif strcmp(cond_raw, 'saline')
        cond = 'Saline';
    else
        fprintf('Skipping "%s": condition "%s" is not Formalin or Saline.\n', blockname, tok.cond);
        continue
    end

    keep_idx(i)  = true;
    animal_id{i} = matched_key;
    condition{i} = cond;
end

data      = raw_data(keep_idx);
animal_id = animal_id(keep_idx);
condition = condition(keep_idx);

for i = 1:length(data)
    data(i).rat_id          = animal_id{i};
    data(i).treatment_group = group_map(animal_id{i});
    data(i).session_cond    = condition{i};
end

fprintf('\nImported %d of %d blocks after filename/group filtering.\n\n', length(data), length(raw_data));
clear raw_data keep_idx animal_id condition i m tok id matched_key map_keys cond cond_raw blockname

if isempty(data)
    error('No blocks passed filtering. Check filename_pattern and group_map against your actual filenames.');
end

%% ============================================================================
%% SECTION 3: EXTRACT FIBER CHANNELS
%% ============================================================================
for i = 1:length(data)
    data(i).FiberChannels.GCAMP     = data(i).streams.x465A.data;
    data(i).FiberChannels.srGECO    = data(i).streams.x560B.data;
    data(i).FiberChannels.isoGCAMP  = data(i).streams.x405A.data;
    data(i).FiberChannels.isoSRGECO = data(i).streams.x405B.data;
end
clear i

%% ============================================================================
%% SECTION 4: EXTRACT PAIN EVENT CHANNEL, IF PRESENT (onset in ms)
%% ============================================================================
for i = 1:length(data)
    if isfield(data(i).epocs, 'Pain')
        data(i).pain = data(i).epocs.Pain.onset;
    end
end
clear i

%% ============================================================================
%% SECTION 4b: DETECT PAIN "BOUTS" (group closely-spaced discrete events)
%% Raw scored onsets often arrive as bursts (e.g. several flinches a couple
%% seconds apart) followed by a gap, then another burst. Treating every
%% single onset as an independent event would let one burst dominate/skew
%% any peri-event average and double-count what is really one behavioral
%% episode. Here, consecutive onsets separated by less than
%% pain_bout_iei_sec are collapsed into a single "bout", anchored at the
%% onset of its first event. Event count and duration within each bout are
%% kept as metadata in case they're useful later (e.g. weighting, or asking
%% whether bout intensity/duration itself scales with activity).
%% ============================================================================
for i = 1:length(data)
    if ~isfield(data(i), 'pain') || isempty(data(i).pain)
        data(i).PainBouts = table(zeros(0,1), zeros(0,1), zeros(0,1), ...
            'VariableNames', {'BoutOnsetSec', 'EventCount', 'DurationSec'});
        continue
    end

    onsets_sec = sort(double(data(i).pain(:)));
    if strcmpi(pain_onset_unit, 'ms')
        onsets_sec = onsets_sec / 1000;
    end

    bout_start_onsets = [];
    bout_event_counts = [];
    bout_durations     = [];

    bout_first = onsets_sec(1);
    bout_last  = onsets_sec(1);
    bout_n     = 1;

    for k = 2:length(onsets_sec)
        if (onsets_sec(k) - bout_last) < pain_bout_iei_sec
            % same bout - extend it
            bout_last = onsets_sec(k);
            bout_n    = bout_n + 1;
        else
            % gap exceeded threshold - close out the previous bout, start a new one
            bout_start_onsets(end+1) = bout_first; %#ok<AGROW>
            bout_event_counts(end+1) = bout_n; %#ok<AGROW>
            bout_durations(end+1)    = bout_last - bout_first; %#ok<AGROW>

            bout_first = onsets_sec(k);
            bout_last  = onsets_sec(k);
            bout_n     = 1;
        end
    end
    % close out the final bout
    bout_start_onsets(end+1) = bout_first;
    bout_event_counts(end+1) = bout_n;
    bout_durations(end+1)    = bout_last - bout_first;

    data(i).PainBouts = table(bout_start_onsets(:), bout_event_counts(:), bout_durations(:), ...
        'VariableNames', {'BoutOnsetSec', 'EventCount', 'DurationSec'});
end
clear i onsets_sec bout_start_onsets bout_event_counts bout_durations bout_first bout_last bout_n k

%% ============================================================================
%% SECTION 5: SAMPLING RATE
%% ============================================================================
FP_SamplingRate = data(1).streams.x465A.fs;

%% ============================================================================
%% SECTION 6: dF/F NORMALIZATION (isosbestic motion-artifact correction)
%% For GCAMP and srGECO: instead of detrending each channel against its own
%% linear fit over time (which does NOT remove motion artifacts), each
%% signal channel is now regressed against ITS OWN isosbestic (405) channel
%% - GCAMP vs isoGCAMP (405A), srGECO vs isoSRGECO (405B). The isosbestic
%% trace is fluorescence-independent (405 nm doesn't excite the
%% calcium-sensitive state of the indicator), so it tracks motion/bending/
%% bleaching artifacts common to both channels but not real calcium
%% activity. Fitting isosbestic -> signal with a linear regression produces
%% a "fitted isosbestic" trace scaled to the signal channel; subtracting
%% that (rather than a plain time-trend line) removes the shared artifact
%% while leaving real activity intact. This is the standard approach (e.g.
%% Lerner et al. 2015).
%%
%% The isosbestic channels themselves still get a simple time-detrend (no
%% independent reference channel exists to correct them against) - this is
%% only used for the raw QC display panels, not for artifact correction.
%% ============================================================================
for i = 1:length(data)
    if length(data(i).FiberChannels.GCAMP) > 3600 * FP_SamplingRate
        Stop = 3600 * FP_SamplingRate - 1 * FP_SamplingRate; % cap at 1 hr session, trim last 1 sec
    else
        Stop = length(data(i).FiberChannels.GCAMP) - 1 * FP_SamplingRate; % trim last 1 sec
    end
    Start = 45 * FP_SamplingRate; % drop first 45 sec

    % Persist the analysis-window bounds (in samples, relative to the raw
    % recording) so pain event onset times can later be aligned to this
    % same trimmed timeline (see Section 14).
    data(i).AnalysisStartSample = round(Start);
    data(i).AnalysisStopSample  = round(Stop);

    temp_GCAMP      = data(i).FiberChannels.GCAMP(round(Start):round(Stop));
    temp_srGECO     = data(i).FiberChannels.srGECO(round(Start):round(Stop));
    temp_isoGCAMP   = data(i).FiberChannels.isoGCAMP(round(Start):round(Stop));
    temp_isoSRGECO  = data(i).FiberChannels.isoSRGECO(round(Start):round(Stop));

    % --- GCAMP: motion-corrected against its own isosbestic (405A) ---
    bls_GCAMP        = polyfit(temp_isoGCAMP, temp_GCAMP, 1);
    fitted_isoGCAMP  = polyval(bls_GCAMP, temp_isoGCAMP);
    data(i).dFoverFWhole.GCAMP = (temp_GCAMP - fitted_isoGCAMP) ./ fitted_isoGCAMP * 100;

    % --- srGECO: motion-corrected against its own isosbestic (405B) ---
    bls_srGECO        = polyfit(temp_isoSRGECO, temp_srGECO, 1);
    fitted_isoSRGECO  = polyval(bls_srGECO, temp_isoSRGECO);
    data(i).dFoverFWhole.srGECO = (temp_srGECO - fitted_isoSRGECO) ./ fitted_isoSRGECO * 100;

    % --- Isosbestic channels: simple time-detrend (for QC display only) ---
    time = 1:length(temp_isoGCAMP);

    reg_isoGCAMP  = polyfit(time, temp_isoGCAMP, 1);
    f0_isoGCAMP   = reg_isoGCAMP(1) * time + reg_isoGCAMP(2);
    data(i).dFoverFWhole.isoGCAMP = (temp_isoGCAMP - f0_isoGCAMP) ./ f0_isoGCAMP * 100;

    reg_isoSRGECO = polyfit(time, temp_isoSRGECO, 1);
    f0_isoSRGECO  = reg_isoSRGECO(1) * time + reg_isoSRGECO(2);
    data(i).dFoverFWhole.isoSRGECO = (temp_isoSRGECO - f0_isoSRGECO) ./ f0_isoSRGECO * 100;
end
clear temp* reg* f0* bls* fitted* i time Stop Start

%% ============================================================================
%% SECTION 7: LOW-PASS FILTER
%% (0.012 ~ 6 Hz | 0.002 ~ 1 Hz | 0.0012 ~ 0.6 Hz)
%% ============================================================================
[c, d] = butter(4, 0.012, 'low');

for i = 1:length(data)
    data(i).Filtered.GCAMP      = filter(c, d, data(i).dFoverFWhole.GCAMP);
    data(i).Filtered.srGECO     = filter(c, d, data(i).dFoverFWhole.srGECO);
    data(i).Filtered.isoGCAMP   = filter(c, d, data(i).dFoverFWhole.isoGCAMP);
    data(i).Filtered.isoSRGECO  = filter(c, d, data(i).dFoverFWhole.isoSRGECO);
end
clear i c d

%% ============================================================================
%% SECTION 8: POOLED Z-SCORE (one shared mean/std per channel, across ALL
%% animals and ALL sessions that passed filtering)
%% Includes the isosbestic (405) channels too, purely so the per-session QC
%% plots (Section 13) can show a z-scored signal-vs-isosbestic comparison on
%% the same scale. The isosbestic channels are NOT included in
%% channels_to_analyze, so they never enter the binning/heatmap/histogram
%% analysis - this is for visual QC only.
%% ============================================================================
qc_only_channels = {'isoGCAMP', 'isoSRGECO'};
zscore_channels  = unique([channels_to_analyze, qc_only_channels], 'stable');

pooled_mu    = struct();
pooled_sigma = struct();
pooled_n     = struct();

for ch_i = 1:length(zscore_channels)
    ch = zscore_channels{ch_i};
    pooled_trace = [];
    for i = 1:length(data)
        pooled_trace = [pooled_trace, data(i).Filtered.(ch)]; %#ok<AGROW>
    end
    pooled_mu.(ch)    = mean(pooled_trace, 'omitnan');
    pooled_sigma.(ch) = std(pooled_trace, 0, 'omitnan');
    pooled_n.(ch)     = sum(~isnan(pooled_trace));
end
clear ch_i ch pooled_trace

for i = 1:length(data)
    for ch_i = 1:length(zscore_channels)
        ch = zscore_channels{ch_i};
        data(i).Zscore.(ch) = (data(i).Filtered.(ch) - pooled_mu.(ch)) / pooled_sigma.(ch);
    end
end
clear i ch_i ch

fprintf('Pooled normalization reference (per channel):\n');
for ch_i = 1:length(zscore_channels)
    ch = zscore_channels{ch_i};
    fprintf('  %s: mean = %.4f, std = %.4f, n samples pooled = %d\n', ...
        ch, pooled_mu.(ch), pooled_sigma.(ch), pooled_n.(ch));
end
fprintf('\n');
clear ch_i ch qc_only_channels zscore_channels

%% ============================================================================
%% SECTION 9: BIN INTO TIME BINS (adjustable width, bin_width_min above)
%% ============================================================================
bin_width_sec   = bin_width_min * 60;
samples_per_bin = round(bin_width_sec * FP_SamplingRate);

for i = 1:length(data)
    for ch_i = 1:length(channels_to_analyze)
        ch = channels_to_analyze{ch_i};
        trace  = data(i).Zscore.(ch);
        n_bins = floor(length(trace) / samples_per_bin);
        binned = nan(1, n_bins);
        for b = 1:n_bins
            idx_start = (b - 1) * samples_per_bin + 1;
            idx_end   = b * samples_per_bin;
            binned(b) = mean(trace(idx_start:idx_end), 'omitnan');
        end
        data(i).Binned.(ch) = binned;
    end
end
clear i ch_i ch trace n_bins binned b idx_start idx_end

%% ============================================================================
%% SECTION 10: GROUP INTO SESSION-CONDITION x TREATMENT-GROUP x CHANNEL
%% ============================================================================
results = struct();

for ch_i = 1:length(channels_to_analyze)
    ch = channels_to_analyze{ch_i};
    for s_i = 1:length(session_conds)
        sc = session_conds{s_i};
        for g_i = 1:length(treatment_grps)
            tg = treatment_grps{g_i};

            idx = find(strcmp({data.session_cond}, sc) & strcmp({data.treatment_group}, tg));
            if isempty(idx)
                continue
            end

            min_bins = min(arrayfun(@(k) length(data(k).Binned.(ch)), idx));
            heat_mat = nan(length(idx), min_bins);
            animal_labels = cell(length(idx), 1);
            for k = 1:length(idx)
                heat_mat(k, :) = data(idx(k)).Binned.(ch)(1:min_bins);
                animal_labels{k} = data(idx(k)).rat_id;
            end

            group_key = sprintf('%s_%s_%s', ch, sc, tg);
            results.(group_key).heatmap        = heat_mat;
            results.(group_key).animal_ids     = animal_labels;
            results.(group_key).bin_width_min  = bin_width_min;
            results.(group_key).channel        = ch;
            results.(group_key).session_cond   = sc;
            results.(group_key).treatment_grp  = tg;
        end
    end
end
clear ch_i ch s_i sc g_i tg idx min_bins heat_mat animal_labels k group_key

if isempty(fieldnames(results))
    error('No group combinations had data. Check that both Formalin/Saline and AIR/AIE groups are represented.');
end

%% ============================================================================
%% SECTION 11: PLOT HEATMAPS + HISTOGRAMS WITH BEST-FIT CURVES
%% ============================================================================
group_keys = fieldnames(results);

if make_plots
    for k = 1:length(group_keys)
        key = group_keys{k};
        heat_mat = results.(key).heatmap;

        % --- Heatmap: averaged across animals (single row = group mean) ---
        % Individual-animal values are still in the CSV export (Section 12)
        % for anyone who wants per-animal detail; the figure itself now
        % shows the group average rather than one row per animal.
        mean_trace = mean(heat_mat, 1, 'omitnan');
        figure('Name', ['Heatmap - ' key], 'Position', [100 100 900 250]);
        imagesc(mean_trace);
        colormap(jet);
        cb = colorbar;
        cb.Label.String = 'Mean z-score';
        xlabel(sprintf('Time bin (%g min each)', bin_width_min));
        yticks(1);
        yticklabels({sprintf('n = %d', size(heat_mat, 1))});
        title(strrep(key, '_', ' '), 'Interpreter', 'none');
        saveas(gcf, fullfile(output_folder, ['Heatmap_' key '.png']));
        clear mean_trace

        % --- Histogram with best-fit (normal) curve ---
        % (pooled across all animals in the group - distribution shape,
        % not affected by the averaging change above)
        all_vals = heat_mat(:);
        all_vals = all_vals(~isnan(all_vals));

        figure('Name', ['Histogram - ' key], 'Position', [100 100 700 500]);
        histogram(all_vals, 30, 'Normalization', 'pdf', 'FaceColor', [0.6 0.6 0.6]);
        hold on;
        [mu, sigma] = local_normfit(all_vals);
        x_vals = linspace(min(all_vals), max(all_vals), 200);
        y_vals = local_normpdf(x_vals, mu, sigma);
        plot(x_vals, y_vals, 'r-', 'LineWidth', 2);
        xlabel('Z-score');
        ylabel('Probability density');
        title(strrep(key, '_', ' '), 'Interpreter', 'none');
        legend({'Data', 'Gaussian fit'});
        hold off;
        saveas(gcf, fullfile(output_folder, ['Histogram_' key '.png']));
    end
    clear k key heat_mat all_vals mu sigma x_vals y_vals cb
end

%% ============================================================================
%% SECTION 11b: GROUP-AVERAGED HEATMAPS + OVERLAID HISTOGRAMS (per channel)
%% One heatmap per channel with a row per group (mean across animals in
%% that group) so all 4 groups (Formalin/Saline x AIR/AIE) can be compared
%% side by side. One histogram per channel with all 4 group distributions
%% and fitted curves overlaid for direct comparison.
%% ============================================================================
group_avg = struct();   % holds the group-averaged data for export, regardless of make_plots
group_colors = [0.85 0.20 0.20;   % Formalin AIR - red
                 0.20 0.40 0.85;   % Formalin AIE - blue
                 0.95 0.55 0.20;   % Saline AIR   - orange
                 0.30 0.70 0.90];  % Saline AIE   - light blue

for ch_i = 1:length(channels_to_analyze)
    ch = channels_to_analyze{ch_i};

    combo_labels = {};
    combo_means  = {};   % 1 x n_bins mean trace per combo
    combo_vals   = {};   % pooled binned z-scores per combo (for histogram)
    combo_idx    = 0;

    for s_i = 1:length(session_conds)
        sc = session_conds{s_i};
        for g_i = 1:length(treatment_grps)
            tg = treatment_grps{g_i};
            group_key = sprintf('%s_%s_%s', ch, sc, tg);
            if ~isfield(results, group_key)
                continue
            end
            combo_idx = combo_idx + 1;
            combo_labels{combo_idx}  = sprintf('%s %s', sc, tg); %#ok<SAGROW>
            heat_mat = results.(group_key).heatmap;
            combo_means{combo_idx} = mean(heat_mat, 1, 'omitnan');   %#ok<SAGROW>
            all_vals = heat_mat(:);
            combo_vals{combo_idx} = all_vals(~isnan(all_vals));      %#ok<SAGROW>
        end
    end

    if combo_idx == 0
        continue
    end

    % Pad group mean traces to a common (min) length and stack into a matrix
    min_bins = min(cellfun(@length, combo_means));
    group_heat_mat = nan(combo_idx, min_bins);
    for r = 1:combo_idx
        group_heat_mat(r, :) = combo_means{r}(1:min_bins);
    end

    group_avg.(ch).labels  = combo_labels;
    group_avg.(ch).heatmap = group_heat_mat;

    if make_plots
        % --- Group-averaged heatmap ---
        figure('Name', ['Group Averaged Heatmap - ' ch], 'Position', [100 100 900 400]);
        imagesc(group_heat_mat);
        colormap(jet);
        cb = colorbar;
        cb.Label.String = 'Mean z-score';
        xlabel(sprintf('Time bin (%g min each)', bin_width_min));
        ylabel('Group');
        yticks(1:combo_idx);
        yticklabels(combo_labels);
        title(sprintf('%s - Group Averaged Heatmap', ch), 'Interpreter', 'none');
        saveas(gcf, fullfile(output_folder, ['GroupAveragedHeatmap_' ch '.png']));

        % --- Overlaid group histograms with fitted curves ---
        figure('Name', ['Group Histograms - ' ch], 'Position', [100 100 800 550]);
        hold on;
        legend_entries = {};
        for r = 1:combo_idx
            col = group_colors(mod(r-1, size(group_colors,1)) + 1, :);
            vals = combo_vals{r};
            histogram(vals, 30, 'Normalization', 'pdf', 'FaceColor', col, ...
                'FaceAlpha', 0.35, 'EdgeColor', 'none');
            [mu, sigma] = local_normfit(vals);
            x_vals = linspace(min(vals), max(vals), 200);
            y_vals = local_normpdf(x_vals, mu, sigma);
            plot(x_vals, y_vals, '-', 'Color', col, 'LineWidth', 2.5);
            legend_entries = [legend_entries, {[combo_labels{r} ' (data)']}, {[combo_labels{r} ' (fit)']}]; %#ok<AGROW>
        end
        hold off;
        xlabel('Z-score');
        ylabel('Probability density');
        title(sprintf('%s - Group Distributions', ch), 'Interpreter', 'none');
        legend(legend_entries, 'Location', 'best');
        saveas(gcf, fullfile(output_folder, ['GroupHistograms_' ch '.png']));
    end
end
clear ch_i ch combo_labels combo_means combo_vals combo_idx s_i sc g_i tg group_key ...
      heat_mat all_vals min_bins group_heat_mat r col vals mu sigma x_vals y_vals ...
      legend_entries cb group_colors

%% ============================================================================
%% SECTION 12: EXPORT DATA FOR GRAPHPAD PRISM
%% ============================================================================
for k = 1:length(group_keys)
    key = group_keys{k};
    heat_mat   = results.(key).heatmap;
    animal_ids = results.(key).animal_ids;
    n_bins     = size(heat_mat, 2);

    % --- Heatmap export: rows = animals, columns = time bins ---
    bin_labels = arrayfun(@(b) sprintf('%g_%gmin', (b - 1) * bin_width_min, b * bin_width_min), ...
                           1:n_bins, 'UniformOutput', false);
    T_heat = array2table(heat_mat, 'VariableNames', bin_labels, 'RowNames', animal_ids);
    writetable(T_heat, fullfile(export_folder, ['Heatmap_' key '.csv']), 'WriteRowNames', true);

    % --- Histogram export: long-format column of all binned z-scores ---
    all_vals = heat_mat(:);
    all_vals = all_vals(~isnan(all_vals));
    T_hist = table(all_vals, 'VariableNames', {'Zscore'});
    writetable(T_hist, fullfile(export_folder, ['Histogram_' key '.csv']));
end
clear k key heat_mat animal_ids n_bins bin_labels T_heat all_vals T_hist

% --- Master long-format export: one row per animal x bin x channel ---
% Columns: RatID, TreatmentGroup, SessionCondition, Channel, BinIndex,
%          BinStartMin, BinEndMin, Zscore
% This single file can be pivoted/filtered directly in GraphPad or Excel.
rows = {};
for k = 1:length(group_keys)
    key = group_keys{k};
    r = results.(key);
    [n_animals, n_bins] = size(r.heatmap);
    for a = 1:n_animals
        for b = 1:n_bins
            rows(end+1, :) = { r.animal_ids{a}, r.treatment_grp, r.session_cond, ...
                                r.channel, b, (b-1)*bin_width_min, b*bin_width_min, ...
                                r.heatmap(a, b) }; %#ok<SAGROW>
        end
    end
end
T_master = cell2table(rows, 'VariableNames', ...
    {'RatID', 'TreatmentGroup', 'SessionCondition', 'Channel', 'BinIndex', ...
     'BinStartMin', 'BinEndMin', 'Zscore'});
writetable(T_master, fullfile(export_folder, 'Master_LongFormat_AllData.csv'));
clear k key r n_animals n_bins a b rows T_master

% --- Group-averaged heatmap export: rows = groups, columns = time bins ---
% One file per channel, ready to drop straight into a Prism grouped heatmap.
group_avg_channels = fieldnames(group_avg);
for ch_i = 1:length(group_avg_channels)
    ch = group_avg_channels{ch_i};
    ga = group_avg.(ch);
    n_bins = size(ga.heatmap, 2);
    bin_labels = arrayfun(@(b) sprintf('%g_%gmin', (b - 1) * bin_width_min, b * bin_width_min), ...
                           1:n_bins, 'UniformOutput', false);
    row_labels = strrep(ga.labels, ' ', '_');
    T_group_heat = array2table(ga.heatmap, 'VariableNames', bin_labels, 'RowNames', row_labels);
    writetable(T_group_heat, fullfile(export_folder, ['GroupAveragedHeatmap_' ch '.csv']), 'WriteRowNames', true);
end
clear ch_i ch ga n_bins bin_labels row_labels T_group_heat group_avg_channels

% --- Reference export: the pooled mean/std used for normalization ---
% Keep this alongside the data exports so the normalization is documented
% and reproducible.
ref_rows = {};
for ch_i = 1:length(channels_to_analyze)
    ch = channels_to_analyze{ch_i};
    ref_rows(end+1, :) = {ch, pooled_mu.(ch), pooled_sigma.(ch), pooled_n.(ch)}; %#ok<SAGROW>
end
T_ref = cell2table(ref_rows, 'VariableNames', {'Channel', 'PooledMean', 'PooledStd', 'PooledNSamples'});
writetable(T_ref, fullfile(export_folder, 'Zscore_Normalization_Reference.csv'));
clear ch_i ch ref_rows T_ref

fprintf('\nDone. Figures and CSV exports saved to:\n  %s\n  %s\n\n', output_folder, export_folder);

%% ============================================================================
%% SECTION 13: PER-SESSION QC PLOTS
%% For every session: raw, dF/F, and z-scored traces (3 rows), with GCAMP in
%% the left column and srGECO in the right column (2 columns). One PNG per
%% session (3x2 layout). GCAMP is paired with its own isosbestic (405A);
%% srGECO is paired with its own isosbestic (405B).
%% ============================================================================
if make_qc_plots
    qc_folder = fullfile(output_folder, 'Session_QC_Traces');
    if ~exist(qc_folder, 'dir'); mkdir(qc_folder); end

    for i = 1:length(data)
        % --- Time vectors ---
        n_dff = length(data(i).Filtered.GCAMP);
        t_dff_min = linspace(1/FP_SamplingRate, n_dff/FP_SamplingRate, n_dff) / 60;

        n_raw = min([length(data(i).FiberChannels.GCAMP), ...
                     length(data(i).FiberChannels.srGECO), ...
                     length(data(i).FiberChannels.isoGCAMP), ...
                     length(data(i).FiberChannels.isoSRGECO)]);
        t_raw_min = linspace(1/FP_SamplingRate, n_raw/FP_SamplingRate, n_raw) / 60;

        fig_name = sprintf('%s_%s_%s', data(i).rat_id, data(i).session_cond, data(i).treatment_group);

        figure('Name', ['QC - ' fig_name], 'Position', [50 50 1400 1100], 'Visible', 'off');

        % --- Row 1: Raw traces ---
        subplot(3, 2, 1);
        plot_paired_trace(t_raw_min, data(i).FiberChannels.GCAMP(1:n_raw), [0 0.6 0.2], 'GCAMP', ...
                           data(i).FiberChannels.isoGCAMP(1:n_raw), [0.5 0.5 0.5], '405A (iso)', ...
                           'Raw signal (AU)', 'GCAMP raw vs 405A isosbestic');
        subplot(3, 2, 2);
        plot_paired_trace(t_raw_min, data(i).FiberChannels.srGECO(1:n_raw), [0.8 0.1 0.1], 'srGECO', ...
                           data(i).FiberChannels.isoSRGECO(1:n_raw), [0.5 0.5 0.5], '405B (iso)', ...
                           'Raw signal (AU)', 'srGECO raw vs 405B isosbestic');

        % --- Row 2: dF/F traces (isosbestic motion-corrected) ---
        subplot(3, 2, 3);
        plot_paired_trace(t_dff_min, data(i).dFoverFWhole.GCAMP, [0 0.6 0.2], 'GCAMP', ...
                           data(i).dFoverFWhole.isoGCAMP, [0.5 0.5 0.5], '405A (iso)', ...
                           '\DeltaF/F (%)', 'GCAMP dF/F vs 405A isosbestic');
        subplot(3, 2, 4);
        plot_paired_trace(t_dff_min, data(i).dFoverFWhole.srGECO, [0.8 0.1 0.1], 'srGECO', ...
                           data(i).dFoverFWhole.isoSRGECO, [0.5 0.5 0.5], '405B (iso)', ...
                           '\DeltaF/F (%)', 'srGECO dF/F vs 405B isosbestic');

        % --- Row 3: Z-score traces (pooled z-score) ---
        subplot(3, 2, 5);
        plot_paired_trace(t_dff_min, data(i).Zscore.GCAMP, [0 0.6 0.2], 'GCAMP', ...
                           data(i).Zscore.isoGCAMP, [0.5 0.5 0.5], '405A (iso)', ...
                           'Z-score', 'GCAMP Z-score vs 405A isosbestic');
        subplot(3, 2, 6);
        plot_paired_trace(t_dff_min, data(i).Zscore.srGECO, [0.8 0.1 0.1], 'srGECO', ...
                           data(i).Zscore.isoSRGECO, [0.5 0.5 0.5], '405B (iso)', ...
                           'Z-score', 'srGECO Z-score vs 405B isosbestic');

        sgtitle(strrep(fig_name, '_', ' '), 'Interpreter', 'none');
        saveas(gcf, fullfile(qc_folder, ['QC_' fig_name '.png']));
        close(gcf);
    end
    clear i n_dff t_dff_min n_raw t_raw_min fig_name qc_folder

    fprintf('Per-session QC trace figures saved to:\n  %s\n\n', fullfile(output_folder, 'Session_QC_Traces'));
end

%% ============================================================================
%% SECTION 14: PAIN EVENT ANALYSIS
%% Two complementary analyses, both built on the bouts detected in Section
%% 4b (so bursts of closely-spaced onsets count as one event, not several):
%%
%%  (A) Peri-Event Time Histogram (PETH): z-scored activity is aligned to
%%      each bout's onset and averaged, first within a session (across that
%%      session's bouts), then across sessions within each group (with SEM
%%      across sessions). A circular-shift permutation test compares the
%%      mean post-onset z-score to the mean pre-onset z-score per
%%      session/channel, without assuming normality and while respecting
%%      the trace's own autocorrelation (the null is built by repeatedly
%%      shifting the WHOLE trace by a random amount and recomputing the
%%      same pre/post comparison against the unchanged bout times).
%%
%%  (B) Binned correlation: correlates the existing per-bin mean z-score
%%      (from Section 9) against bout COUNT in that same bin, per session
%%      per channel. Also uses a circular-shift permutation test (shifting
%%      the binned bout-count series) rather than a parametric p-value,
%%      since both series are autocorrelated in time. Correlations are
%%      computed per session (not pooled across animals into one number)
%%      to avoid pseudoreplication; compare the resulting per-session
%%      coefficients across groups downstream (e.g. in GraphPad/stats
%%      software) rather than pooling raw bins across animals.
%% ============================================================================
has_pain_data = any(arrayfun(@(s) height(s.PainBouts) > 0, data));

if ~has_pain_data
    fprintf('No pain events found in any session - skipping pain event analysis (Section 14).\n\n');
else
    pain_folder = fullfile(output_folder, 'Pain_Event_Analysis');
    if ~exist(pain_folder, 'dir'); mkdir(pain_folder); end

    peth_win_samples = round(peth_window_sec * FP_SamplingRate); % [start end] sample offsets rel. to onset
    peth_t_sec       = (peth_win_samples(1):peth_win_samples(2)) / FP_SamplingRate;

    if any(abs(peth_window_sec) > pain_bout_iei_sec)
        fprintf('NOTE: peth_window_sec extends beyond pain_bout_iei_sec - PETH windows from\n');
        fprintf('neighboring bouts could overlap. Consider shrinking peth_window_sec or\n');
        fprintf('increasing pain_bout_iei_sec if that matters for your data.\n\n');
    end

    %% --- (A1) Build per-bout PETH epochs, per session, per channel ---
    for i = 1:length(data)
        trace_len           = length(data(i).Zscore.(channels_to_analyze{1}));
        start_sec_analysis  = data(i).AnalysisStartSample / FP_SamplingRate;
        n_bouts             = height(data(i).PainBouts);

        centers = [];
        for b = 1:n_bouts
            onset_sec_rel = data(i).PainBouts.BoutOnsetSec(b) - start_sec_analysis;
            idx_center    = round(onset_sec_rel * FP_SamplingRate) + 1;
            idx_start     = idx_center + peth_win_samples(1);
            idx_end       = idx_center + peth_win_samples(2);
            if idx_start >= 1 && idx_end <= trace_len
                centers(end+1) = idx_center; %#ok<AGROW>
            end
        end
        data(i).PETH_centers = centers;

        for ch_i = 1:length(channels_to_analyze)
            ch    = channels_to_analyze{ch_i};
            trace = data(i).Zscore.(ch);
            epochs = nan(length(centers), length(peth_t_sec));
            for k = 1:length(centers)
                idx_start = centers(k) + peth_win_samples(1);
                idx_end   = centers(k) + peth_win_samples(2);
                epochs(k, :) = trace(idx_start:idx_end);
            end
            data(i).PETH.(ch) = epochs;
        end
    end
    clear i trace_len start_sec_analysis n_bouts centers b onset_sec_rel idx_center ...
          idx_start idx_end ch_i ch trace epochs k

    %% --- (A2) Group-level PETH: mean +/- SEM across sessions, per channel ---
    group_peth = struct();
    for ch_i = 1:length(channels_to_analyze)
        ch = channels_to_analyze{ch_i};
        for s_i = 1:length(session_conds)
            sc = session_conds{s_i};
            for g_i = 1:length(treatment_grps)
                tg  = treatment_grps{g_i};
                idx = find(strcmp({data.session_cond}, sc) & strcmp({data.treatment_group}, tg));

                session_means = [];
                for k = 1:length(idx)
                    ep = data(idx(k)).PETH.(ch);
                    if ~isempty(ep)
                        session_means(end+1, :) = mean(ep, 1, 'omitnan'); %#ok<AGROW>
                    end
                end
                if isempty(session_means)
                    continue
                end

                group_key = sprintf('%s_%s_%s', ch, sc, tg);
                group_peth.(group_key).mean_trace = mean(session_means, 1, 'omitnan');
                group_peth.(group_key).sem_trace  = std(session_means, 0, 1, 'omitnan') / sqrt(size(session_means, 1));
                group_peth.(group_key).n_sessions = size(session_means, 1);
            end
        end
    end
    clear ch_i ch s_i sc g_i tg idx session_means k ep group_key

    %% --- (A3) Plot group PETH: one figure per channel, all 4 groups overlaid ---
    if make_pain_plots
        peth_colors = [0.85 0.20 0.20; 0.20 0.40 0.85; 0.95 0.55 0.20; 0.30 0.70 0.90];
        for ch_i = 1:length(channels_to_analyze)
            ch = channels_to_analyze{ch_i};
            figure('Name', ['PETH - ' ch], 'Position', [100 100 800 550]);
            hold on;
            legend_entries = {};
            r = 0;
            for s_i = 1:length(session_conds)
                sc = session_conds{s_i};
                for g_i = 1:length(treatment_grps)
                    tg = treatment_grps{g_i};
                    group_key = sprintf('%s_%s_%s', ch, sc, tg);
                    if ~isfield(group_peth, group_key)
                        continue
                    end
                    r   = r + 1;
                    col = peth_colors(mod(r - 1, size(peth_colors, 1)) + 1, :);
                    m = group_peth.(group_key).mean_trace;
                    s = group_peth.(group_key).sem_trace;
                    fill([peth_t_sec, fliplr(peth_t_sec)], [m + s, fliplr(m - s)], col, ...
                        'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                    plot(peth_t_sec, m, 'Color', col, 'LineWidth', 2);
                    legend_entries{end+1} = sprintf('%s %s (n=%d sessions)', sc, tg, group_peth.(group_key).n_sessions); %#ok<SAGROW>
                end
            end
            xline(0, '--k', 'Pain bout onset');
            hold off;
            xlabel('Time from pain bout onset (sec)');
            ylabel('Mean z-score (\pm SEM across sessions)');
            title(sprintf('%s - Peri-Event Time Histogram', ch), 'Interpreter', 'none');
            legend(legend_entries, 'Location', 'best');
            saveas(gcf, fullfile(pain_folder, ['PETH_' ch '.png']));
        end
        clear ch_i ch r s_i sc g_i tg group_key col m s legend_entries peth_colors
    end

    %% --- (A4) Per-session pre vs post stats (circular-shift permutation test) ---
    pre_offset  = round(peth_baseline_sec * FP_SamplingRate);
    post_offset = round(peth_response_sec * FP_SamplingRate);
    peth_stats_rows = {};

    for i = 1:length(data)
        centers = data(i).PETH_centers;
        for ch_i = 1:length(channels_to_analyze)
            ch = channels_to_analyze{ch_i};
            trace = data(i).Zscore.(ch);
            if isempty(centers)
                diff_val = NaN; p_val = NaN;
            else
                [diff_val, p_val] = local_peth_permtest(trace, centers, pre_offset, post_offset, n_permutations);
            end
            peth_stats_rows(end+1, :) = {data(i).rat_id, data(i).treatment_group, data(i).session_cond, ...
                ch, length(centers), diff_val, p_val}; %#ok<SAGROW>
        end
    end
    T_peth_stats = cell2table(peth_stats_rows, 'VariableNames', ...
        {'RatID', 'TreatmentGroup', 'SessionCondition', 'Channel', 'NBoutsUsed', 'PostMinusPreZ', 'PermutationP'});
    writetable(T_peth_stats, fullfile(export_folder, 'Pain_PETH_PrePostStats.csv'));
    clear i centers ch_i ch trace diff_val p_val peth_stats_rows pre_offset post_offset T_peth_stats

    %% --- (A5) Export: group-averaged PETH traces + individual epochs ---
    group_keys_peth = fieldnames(group_peth);
    for k = 1:length(group_keys_peth)
        key = group_keys_peth{k};
        m = group_peth.(key).mean_trace;
        s = group_peth.(key).sem_trace;
        T_g = table(peth_t_sec(:), m(:), s(:), 'VariableNames', {'TimeSec', 'MeanZscore', 'SEM'});
        writetable(T_g, fullfile(export_folder, ['PETH_' key '.csv']));
    end
    clear k key m s T_g group_keys_peth

    bout_export_rows = {};
    for i = 1:length(data)
        bt = data(i).PainBouts;
        for b = 1:height(bt)
            bout_export_rows(end+1, :) = {data(i).rat_id, data(i).treatment_group, data(i).session_cond, ...
                bt.BoutOnsetSec(b), bt.EventCount(b), bt.DurationSec(b)}; %#ok<SAGROW>
        end
    end
    if ~isempty(bout_export_rows)
        T_bouts = cell2table(bout_export_rows, 'VariableNames', ...
            {'RatID', 'TreatmentGroup', 'SessionCondition', 'BoutOnsetSec', 'EventCount', 'DurationSec'});
        writetable(T_bouts, fullfile(export_folder, 'Pain_Bouts_Detected.csv'));
    end
    clear i bt b bout_export_rows T_bouts

    %% --- (B) Binned correlation: binned z-score vs binned bout count ---
    bin_width_sec_pain = bin_width_min * 60; % mirrors Section 9's binning exactly
    corr_rows = {};

    for i = 1:length(data)
        start_sec_analysis = data(i).AnalysisStartSample / FP_SamplingRate;
        bout_rel_sec = data(i).PainBouts.BoutOnsetSec - start_sec_analysis;
        bout_rel_sec = bout_rel_sec(bout_rel_sec >= 0);

        for ch_i = 1:length(channels_to_analyze)
            ch = channels_to_analyze{ch_i};
            binned_z = data(i).Binned.(ch);
            n_bins   = length(binned_z);
            bin_edges = 0:bin_width_sec_pain:(n_bins * bin_width_sec_pain);
            bout_counts = histcounts(bout_rel_sec, bin_edges);

            if n_bins < 3 || sum(bout_counts) == 0
                r_val = NaN;
                p_val = NaN;
            else
                cc = corrcoef(binned_z(:), bout_counts(:));
                r_val = cc(1, 2);

                null_r = nan(n_permutations, 1);
                for p = 1:n_permutations
                    shifted = circshift(bout_counts, randi(n_bins - 1));
                    cc_p = corrcoef(binned_z(:), shifted(:));
                    null_r(p) = cc_p(1, 2);
                end
                p_val = (sum(abs(null_r) >= abs(r_val)) + 1) / (n_permutations + 1);
            end

            corr_rows(end+1, :) = {data(i).rat_id, data(i).treatment_group, data(i).session_cond, ...
                ch, n_bins, sum(bout_counts), r_val, p_val}; %#ok<SAGROW>
        end
    end
    T_corr = cell2table(corr_rows, 'VariableNames', ...
        {'RatID', 'TreatmentGroup', 'SessionCondition', 'Channel', 'NBins', 'NBouts', 'PearsonR', 'PermutationP'});
    writetable(T_corr, fullfile(export_folder, 'Pain_BinnedCorrelation.csv'));
    clear i start_sec_analysis bout_rel_sec ch_i ch binned_z n_bins bin_edges bout_counts ...
          cc r_val null_r p shifted cc_p p_val corr_rows T_corr bin_width_sec_pain

    fprintf('Pain event analysis (PETH + binned correlation) complete.\n');
    fprintf('  Figures: %s\n', pain_folder);
    fprintf('  CSV exports: %s\n\n', export_folder);
end
clear has_pain_data

%% ============================================================================
%% SECTION 15: MANUSCRIPT-STYLE OVERLAID PROBABILITY DENSITY CURVES
%% Smooth kernel density estimates (KDE) of the same pooled binned z-score
%% values already used for the group histograms in Section 11b - but drawn
%% as clean overlaid curves with NO histogram bars, all 4 groups (per
%% channel) evaluated over one shared, padded x-axis so every curve in a
%% figure is directly comparable and none is clipped at the edges.
%%
%% This does not modify, recompute, or replace any existing figure -
%% Sections 1-14 are untouched. It is a separate, additional output
%% intended for direct use in a manuscript: white background, no
%% histogram, minimal box/gridlines, both a PNG (quick look) and a
%% vector PDF (scalable/editable) are saved per channel. A KDE is used
%% instead of assuming a normal distribution (unlike the Gaussian fit
%% line in Sections 11/11b), since the true shape of the distribution is
%% exactly what a reviewer would want to see, not an assumed shape.
%% ============================================================================
density_folder = fullfile(output_folder, 'Manuscript_Density_Curves');
if ~exist(density_folder, 'dir'); mkdir(density_folder); end

density_colors    = [0.85 0.20 0.20;   % Formalin AIR
                      0.20 0.40 0.85;   % Formalin AIE
                      0.95 0.55 0.20;   % Saline AIR
                      0.30 0.70 0.90];  % Saline AIE
n_density_points  = 300;   % <-- ADJUSTABLE: resolution of each curve

density_curves = struct();

for ch_i = 1:length(channels_to_analyze)
    ch = channels_to_analyze{ch_i};

    % Gather this channel's pooled z-score values per group, and the
    % global min/max across ALL of that channel's groups so every curve
    % in the figure is drawn over the exact same x range.
    group_vals   = {};
    group_labels = {};
    all_min = Inf;
    all_max = -Inf;

    for s_i = 1:length(session_conds)
        sc = session_conds{s_i};
        for g_i = 1:length(treatment_grps)
            tg = treatment_grps{g_i};
            group_key = sprintf('%s_%s_%s', ch, sc, tg);
            if ~isfield(results, group_key)
                continue
            end
            vals = results.(group_key).heatmap(:);
            vals = vals(~isnan(vals));
            if isempty(vals)
                continue
            end
            group_vals{end+1}   = vals; %#ok<SAGROW>
            group_labels{end+1} = sprintf('%s %s', sc, tg); %#ok<SAGROW>
            all_min = min(all_min, min(vals));
            all_max = max(all_max, max(vals));
        end
    end

    if isempty(group_vals)
        continue
    end

    % Pad the shared range a bit so curves taper to ~0 instead of being cut off
    pad = 0.05 * (all_max - all_min);
    xi  = linspace(all_min - pad, all_max + pad, n_density_points);

    curves_mat = nan(n_density_points, length(group_vals));

    fig = figure('Name', ['Density - ' ch], 'Position', [100 100 750 500], 'Color', 'w');
    ax = axes(fig);
    hold(ax, 'on');
    for k = 1:length(group_vals)
        col = density_colors(mod(k - 1, size(density_colors, 1)) + 1, :);
        [~, f] = local_kde(group_vals{k}, xi);
        curves_mat(:, k) = f(:);
        plot(ax, xi, f, 'Color', col, 'LineWidth', 2.5);
    end
    hold(ax, 'off');

    box(ax, 'off');
    ax.TickDir   = 'out';
    ax.FontName  = 'Arial';
    ax.FontSize  = 12;
    ax.LineWidth = 1;
    xlim(ax, [xi(1), xi(end)]);
    xlabel(ax, 'Z-score', 'FontSize', 13);
    ylabel(ax, 'Probability density', 'FontSize', 13);
    title(ax, strrep(ch, '_', ' '), 'FontSize', 14, 'FontWeight', 'normal');
    legend(ax, group_labels, 'Location', 'best', 'Box', 'off', 'FontSize', 11);

    saveas(fig, fullfile(density_folder, ['Density_' ch '.png']));
    try
        exportgraphics(fig, fullfile(density_folder, ['Density_' ch '.pdf']), 'ContentType', 'vector');
    catch
        % exportgraphics needs R2020a+; fall back to a standard PDF export
        saveas(fig, fullfile(density_folder, ['Density_' ch '.pdf']));
    end

    density_curves.(ch).xi     = xi;
    density_curves.(ch).labels = group_labels;
    density_curves.(ch).curves = curves_mat;
end
clear ch_i ch group_vals group_labels all_min all_max s_i sc g_i tg group_key vals ...
      pad xi curves_mat fig ax k col f density_colors n_density_points

%% --- Export the KDE curves themselves (one shared x column + one density
%%     column per group) - a direct XY multi-column table for Prism ---
density_channels = fieldnames(density_curves);
for ch_i = 1:length(density_channels)
    ch = density_channels{ch_i};
    dc = density_curves.(ch);
    var_names = [{'Zscore'}, strrep(dc.labels, ' ', '_')];
    T_density = array2table([dc.xi(:), dc.curves], 'VariableNames', var_names);
    writetable(T_density, fullfile(export_folder, ['DensityCurves_' ch '.csv']));
end
clear ch_i ch dc var_names T_density density_channels

fprintf('Manuscript-style density curve figures saved to:\n  %s\n\n', density_folder);

%% ============================================================================
%% LOCAL FUNCTIONS (no toolbox dependency)
%% ============================================================================
function plot_paired_trace(t, sig1, color1, label1, sig2, color2, label2, y_label, title_str)
    n = min([length(t), length(sig1), length(sig2)]);
    plot(t(1:n), sig1(1:n), 'Color', color1, 'LineWidth', 1); hold on;
    plot(t(1:n), sig2(1:n), 'Color', color2, 'LineWidth', 1);
    hold off;
    xlabel('Time (min)');
    ylabel(y_label);
    title(title_str);
    legend({label1, label2}, 'Location', 'best');
end

function [mu, sigma] = local_normfit(x)
    mu = mean(x, 'omitnan');
    sigma = std(x, 0, 'omitnan');
end

function y = local_normpdf(x, mu, sigma)
    y = (1 / (sigma * sqrt(2*pi))) * exp(-0.5 * ((x - mu) / sigma).^2);
end

function [obs_diff, p_val] = local_peth_permtest(trace, idx_centers, pre_offset, post_offset, n_perm)
    % Circular-shift permutation test: compares the observed mean
    % (post-window - pre-window) z-score, averaged across bouts, against a
    % null built by shifting the WHOLE trace by a random amount and
    % recomputing the same statistic at the unchanged bout center indices.
    % This preserves the trace's own autocorrelation structure in the null,
    % which a parametric test would ignore.
    obs_diff = local_prepost_diff(trace, idx_centers, pre_offset, post_offset);

    n = length(trace);
    null_diffs = nan(n_perm, 1);
    for p = 1:n_perm
        shifted_trace = circshift(trace, randi(n - 1));
        null_diffs(p) = local_prepost_diff(shifted_trace, idx_centers, pre_offset, post_offset);
    end
    p_val = (sum(abs(null_diffs) >= abs(obs_diff)) + 1) / (n_perm + 1);
end

function d = local_prepost_diff(trace, idx_centers, pre_offset, post_offset)
    n = length(trace);
    pre_vals  = nan(length(idx_centers), 1);
    post_vals = nan(length(idx_centers), 1);
    for k = 1:length(idx_centers)
        c = idx_centers(k);
        pre_idx  = (c + pre_offset(1)):(c + pre_offset(2));
        post_idx = (c + post_offset(1)):(c + post_offset(2));
        if all(pre_idx >= 1 & pre_idx <= n) && all(post_idx >= 1 & post_idx <= n)
            pre_vals(k)  = mean(trace(pre_idx), 'omitnan');
            post_vals(k) = mean(trace(post_idx), 'omitnan');
        end
    end
    d = mean(post_vals - pre_vals, 'omitnan');
end

function [xi, f] = local_kde(x, xi)
    % Gaussian kernel density estimate, bandwidth via Silverman's rule of
    % thumb (1.06 * std * n^-1/5). No Statistics Toolbox required.
    x = x(~isnan(x));
    n = length(x);
    f = zeros(size(xi));

    sigma = std(x, 0, 'omitnan');
    if n < 2 || sigma == 0 || isnan(sigma)
        return
    end

    bw = 1.06 * sigma * n^(-1/5);
    for k = 1:n
        f = f + exp(-0.5 * ((xi - x(k)) / bw) .^ 2);
    end
    f = f / (n * bw * sqrt(2 * pi));
end