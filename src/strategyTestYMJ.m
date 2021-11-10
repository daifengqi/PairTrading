%% This file serves as a test script for the pairTrading strategy
% start设置成20180901，20180903就不是valid了？？？
warning('off','all')
warning
startDateStr = '20180610';
endDateStr = '20181010';
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

% strategyParameters = mclasses.strategy.longOnly.configParameter(strategy);


% signalStruct = pairTradingSignal(startDateStr,endDateStr,sectorNum);
% signalStruct.calSignals();
% signalStruct;
% signalStruct.signals

% strategy.initialize(strategyParameters);
strategy = PairTradingStrategy(director.rootAllocator ,'pairTradingProj');
strategyParameters = configParameter(strategy);
strategy.startDateStr = startDateStr;
strategy.endDateStr = endDateStr;
strategy.sectorNum = sectorNum;
strategy.initialize(strategyParameters);
strategy.prepareFields();
% marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
% generalData = marketData.getAggregatedDataStruct;
% allDates = generalData.sharedInformation.allDates;
% for i = datenum('20180903','yyyymmdd'): datenum('20181210','yyyymmdd')
%     if find(ismember(allDates,i))
%         strategy.generateOrders(i);
%     end
% end
%% run strategies
%load('/Users/lifangwen/Desktop/module4/software/homeworkCode/sharedData/mat/marketInfo_securities_china.mat')
director.reset();
director.run();
director.displayResult();
