function [data] = getTDTFiles(folder)

% Get the folder names for all TDT sessions
TDTFolder_directory = folder;
allTDTFolders = dir(TDTFolder_directory);

% Remove '.' and '..' from the folder list
TDTFolder_names = allTDTFolders(~ismember({allTDTFolders.name}, {'.', '..'}));

% Set location of the TDT SDK and add path
SDKPATH = 'D:\jdani\OneDrive\Documents\Education\MUSC Postdoc\Lab Management\Code\MATLAB\TDTMatlabSDK';
addpath(genpath(SDKPATH));

% Call TDT_import to get the data and then store it somewhere.
for i = 1:length([TDTFolder_names])
    disp(TDTFolder_names(i).name)
    data(i) = TDTbin2mat(append(TDTFolder_directory, '\', [TDTFolder_names(i).name]));
end

clearvars -except data
end