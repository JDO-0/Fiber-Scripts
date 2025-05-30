%% Specify the data folder
data_folder = 'E:\Formalin';

%% Add the path to MATLAB fuctions
MATLAB_FX_PATH = 'C:/Users/jdani/OneDrive/Documents/Education/MUSC Postdoc/Lab Management/Code/MATLAB/Functions';
addpath(genpath(MATLAB_FX_PATH));

%% Import data into MATLAB from TDT Files
data = getTDTFiles(data_folder);

%% Extract rat id %%
for i = 1:length(data)
    data(i).rat_id = data(i).info.blockname(1:end-14);
end
clear i

%% Bin flinches/licks %%
binSize = 5; % Size of the bin in minutes.
for i = 1:length(data)
    temp_bin = assignBins(binSize, data(i).epocs.Pain.onset);
    data(i).epocs.pain_bins = temp_bin';
end
clear i temp_bin binSize

%% Count the number of events in each bin %%
for i=1:length(data)
    data(i).bins = groupcounts(data(i).epocs.pain_bins);
end

clear i

%% Export to Excel %%
%% Flatten bins and export to Excel %%
% Determine the maximum number of bins across all animals
max_bins = max(cellfun(@numel, {data.bins}));

% Preallocate cell array for table rows
rat_ids = cell(length(data), 1);
bins_matrix = nan(length(data), max_bins);  % Use NaN for missing bins

for i = 1:length(data)
    rat_ids{i} = data(i).rat_id;
    num_bins = length(data(i).bins);
    bins_matrix(i, 1:num_bins) = data(i).bins;
end

% Create bin column names: bin1, bin2, ..., binN
bin_column_names = arrayfun(@(x) sprintf('bin%d', x), 1:max_bins, 'UniformOutput', false);

% Create the table
export_table = cell2table(rat_ids, 'VariableNames', {'rat_id'});
bins_table = array2table(bins_matrix, 'VariableNames', bin_column_names);
final_table = [export_table, bins_table];

% Specify output file path
output_file = fullfile(data_folder, 'rat_bins_flattened.xlsx');

% Write to Excel
writetable(final_table, output_file);

disp(['Export complete: ' output_file]);

