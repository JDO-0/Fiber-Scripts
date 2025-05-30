function dFoverFWhole_x465A = dFF_green(data, varargin)

%% Set default stop and start values in seconds in case none are provided
defaultStart = 1;
defaultEnd = 1;

%% Create input parser to handle optional inputs
p = inputParser;
validTime = @(x) isnumeric(x) && isscalar(x) && (x > 0) && (x < 1820);
addRequired(p, 'data');
addOptional(p, 'start', defaultStart, validTime);
addOptional(p, 'last', defaultEnd, validTime);

%% Parse inputs
parse(p, data, varargin{:});

%% Reset default values if optional input is provided
start = p.Results.start;
last = p.Results.last;

if ~ismember('start', p.UsingDefaults)
    defaultStart = start;
end

if ~ismember('last', p.UsingDefaults)
    defaultEnd = last;
end

%% Set the start and stop times for the data
Stop = length(data.streams.x405A.data) - defaultEnd * 1017.253; %adjust stop time as necessary by adding -x*1017.253 to end
Start= defaultStart * 1017.253; %adjust start as necessary

%normalizes 465 channel to time
dataone=data.streams.x465A.data(round(Start):round(Stop));
time=1:length(data.streams.x465A.data(round(Start):round(Stop)));
reg = polyfit(time, dataone, 1);
f0 = reg(1)*time + reg(2);
signal_df_f0 = (dataone - f0)./f0 * 100;


%normalizes 405 channel to time
datatwo=data.streams.x405A.data(round(Start):round(Stop));
time=1:length(data.streams.x405A.data(round(Start):round(Stop)));
reg = polyfit(time, datatwo, 1);
f0 = reg(1)*time + reg(2);
reference_df_f0 = (datatwo - f0)./f0 * 100;
    
%subtracts the two
dFoverFWhole_x465A = signal_df_f0 - reference_df_f0;

%applies low pass filter, making 2nd value smaller is more filtering
[c,d] = butter(2,0.00012,'low');

dFoverFWhole_x465A=filter(c,d,dFoverFWhole_x465A);