function [astro_AUC_Tone, neuron_AUC_Tone, astro_AUC_Shock, neuron_AUC_Shock] = calcAUC_Tone_Shock(astro_z, neuron_z, trial_type, sampling_rate)

Start_Tone_Baseline = 1;
Start_Tone_AUC = round(10 * sampling_rate);
End_Tone_AUC = round(30 * sampling_rate);
Start_Shock_Baseline = round(34 * sampling_rate);
Start_Shock_AUC = round(39 * sampling_rate);
End_Shock_AUC = round(59 * sampling_rate);

% Fit linear baseline for tone region
x_tone_base = (Start_Tone_Baseline:Start_Tone_AUC)' / sampling_rate;
astro_tone_base_data = astro_z(Start_Tone_Baseline:Start_Tone_AUC);

% Fit lines to baseline data
p_astro_tone = polyfit(x_tone_base, astro_tone_base_data', 1);

% Create baseline-corrected tone data
x_tone = (Start_Tone_AUC:End_Tone_AUC)' / sampling_rate;
astro_tone_baseline_fit = polyval(p_astro_tone, x_tone);
astro_tone_corrected = astro_z(Start_Tone_AUC:End_Tone_AUC)' - astro_tone_baseline_fit;

% Calculate AUC for tone (baseline-corrected)
astro_AUC_Tone = trapz(astro_tone_corrected) / sampling_rate;

if ~isempty(neuron_z)
    % Fit linear baseline for tone region
    neuron_tone_base_data = neuron_z(Start_Tone_Baseline:Start_Tone_AUC);

    % Fit lines to baseline data
    p_neuron_tone = polyfit(x_tone_base, neuron_tone_base_data', 1);

    % Create baseline-corrected tone data
    neuron_tone_baseline_fit = polyval(p_neuron_tone, x_tone);
    neuron_tone_corrected = neuron_z(Start_Tone_AUC:End_Tone_AUC)' - neuron_tone_baseline_fit;

    % Calculate AUC for tone (baseline-corrected)
    neuron_AUC_Tone = trapz(neuron_tone_corrected) / sampling_rate;

else
    neuron_AUC_Tone = NaN;

end

if strcmp(trial_type, 'Cond')
    % Fit linear baseline for shock region
    x_shock_base = (Start_Shock_Baseline:Start_Shock_AUC)' / sampling_rate;
    astro_shock_base_data = astro_z(Start_Shock_Baseline:Start_Shock_AUC);

    % Fit lines to baseline data
    p_astro_shock = polyfit(x_shock_base, astro_shock_base_data', 1);

    % Create baseline-corrected shock data
    x_shock = (Start_Shock_AUC:End_Shock_AUC)' / sampling_rate;
    astro_shock_baseline_fit = polyval(p_astro_shock, x_shock);
    astro_shock_corrected = astro_z(Start_Shock_AUC:End_Shock_AUC)' - astro_shock_baseline_fit;

    % Calculate AUC for shock (baseline-corrected)
    astro_AUC_Shock = trapz(astro_shock_corrected) / sampling_rate;

    if ~isempty(neuron_z)
    	% Fit linear baseline for shock region
    	neuron_shock_base_data = neuron_z(Start_Shock_Baseline:Start_Shock_AUC);

    	% Fit lines to baseline data
    	p_neuron_shock = polyfit(x_shock_base, neuron_shock_base_data', 1);

    	% Create baseline-corrected shock data
    	neuron_shock_baseline_fit = polyval(p_neuron_shock, x_shock);
    	neuron_shock_corrected = neuron_z(Start_Shock_AUC:End_Shock_AUC)' - neuron_shock_baseline_fit;

    	% Calculate AUC for shock (baseline-corrected)
    	neuron_AUC_Shock = trapz(neuron_shock_corrected) / sampling_rate;
    else
        neuron_AUC_Shock = NaN;
    end

else
    astro_AUC_Shock = NaN;
    neuron_AUC_Shock = NaN;
end