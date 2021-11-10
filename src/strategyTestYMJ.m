%% This file serves as a test script for the pairTrading strategy

warning('off','all')
warning
startDateStr = '20190510';
endDateStr = '20191010';
sectorNum = 31;
%% Create a director
director = mclasses.director.HomeworkDirector([], 'homework_2');

%% register strategy
% parameters for director
directorParameters = [];
initParameters.startDate = datenum(startDateStr,'yyyymmdd');
initParameters.endDate = datenum(endDateStr,'yyyymmdd');
director.initialize(initParameters);
%% calculate signal

%% register strategy

strategy = PairTradingStrategy(director.rootAllocator ,'pairTradingProj1');
strategyParameters = configParameter(strategy);
% 设置参数
strategy.startDateStr = startDateStr;
strategy.endDateStr = endDateStr;
strategy.sectorNum = sectorNum;
strategy.initialize(strategyParameters);
% 计算signal
strategy.prepareFields();

%% run strategies
%load('/Users/lifangwen/Desktop/module4/software/homeworkCode/sharedData/mat/marketInfo_securities_china.mat')
director.reset();
% strategy 每天更新orderList，给director执行，并记录每个pair的PnL，平仓时会自动画出pair的表现情况
director.run();
% 利用老师回测平台，得到策略的效果，放一张return的图，后续同学会详细解释
director.displayResult();
