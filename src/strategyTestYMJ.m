%% This file serves as a test script for the pairTrading strategy
% start设置成20180901，20180903就不是valid了？？？
startDateStr = '20180610';
endDateStr = '20181210';
sectorNum = 3;
%% Create a director
director = mclasses.director.HomeworkDirector([], 'homework_2');

%% register strategy
% parameters for director
directorParameters = [];
initParameters.startDate = datenum('20180903','yyyymmdd');
initParameters.endDate = datenum(endDateStr,'yyyymmdd');
director.initialize(initParameters);
%% calculate signal

%% register strategy
strategy = pairTradingStrategy(director.rootAllocator ,'pairTradingProj1');
% strategyParameters = mclasses.strategy.longOnly.configParameter(strategy);
% strategyParameters.startDateStr = startDateStr;
% strategyParameters.endDateStr = endDateStr;
% strategyParameters.sectorNum = sectorNum;

signalStruct = pairTradingSignal(startDateStr,endDateStr,sectorNum);
signalStruct.calSignals();
signalStruct;
signalStruct.signals

% strategy.initialize(strategyParameters);
strategy.prepareFields(signalStruct);
marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
generalData = marketData.getAggregatedDataStruct;
allDates = generalData.sharedInformation.allDates;
for i = datenum('20180903','yyyymmdd'): datenum('20181210','yyyymmdd')
    if find(ismember(allDates,i))
        strategy.generateOrders(i);
    end
end

%% run strategies
%load('/Users/lifangwen/Desktop/module4/software/homeworkCode/sharedData/mat/marketInfo_securities_china.mat')
director.reset();
director.run();
director.displayResult();
