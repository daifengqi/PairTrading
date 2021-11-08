%% This file serves as a test script for the pairTrading strategy
%% Create a director
director = mclasses.director.HomeworkDirector([], 'homework_2');

%% register strategy
% parameters for director
directorParameters = [];
initParameters.startDate = datenum(2014, 5, 1);
initParameters.endDate = datenum(2020, 8, 31);
director.initialize(initParameters);

%% calculate signal
signalStruct = pairTradingSignal('20180610','20181010');
signalStruct.calSignals();
signalStruct;
signalStruct.signals
%% register strategy
strategy = pairTradingStrategy(director.rootAllocator ,'pairTrading');
strategy.initialize(signalStruct);
for i = datenum('20180902','yyyymmdd'): datenum('20180930','yyyymmdd')
    strategy.generateOrders(i);
end
