SDKPATH = 'C:\Users\jdani\OneDrive\Documents\Education\MUSC Postdoc\Lab Management\Code\MATLAB\TDTMatlabSDK'
addpath(genpath(SDKPATH))
DATAPATH = 'E:\ANALYZED VIDEOS'
addpath(genpath(DATAPATH))
data = TDTbin2mat(append(DATAPATH,'\JDO_20-24-241217-162858'))

MATPATH = 'C:\Users\jdani\OneDrive\Documents\Education\MUSC Postdoc\Lab Management\Code\MATLAB\Fear'
addpath(genpath(MATPATH))

dFFfindpeaksJWB_Astro_Neuron_Fear(data);
