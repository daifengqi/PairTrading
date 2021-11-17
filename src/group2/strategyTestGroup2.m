%% This file serves as a test script for the pairTrading strategy

warning('off','all')
warning
startDateStr = '20170510';
endDateStr = '20200110';
sectorNum = 31;
%% Create a director
director = mclasses.director.HomeworkDirector([], 'proj_group2');

%% register strategy
% parameters for director
directorParameters = [];
initParameters.startDate = datenum(startDateStr,'yyyymmdd');
initParameters.endDate = datenum(endDateStr,'yyyymmdd');
director.initialize(initParameters);

%% register strategy
strategy = PairTradingStrategy(director.rootAllocator ,'pairTradingProj');
strategyParameters = configParameter(strategy);
% 设置参数
strategy.startDateStr = startDateStr;
strategy.endDateStr = endDateStr;
strategy.sectorNum = sectorNum;
strategy.initialize(strategyParameters);
disp(strategy.startDateStr);

% 计算signal
strategy.prepareFields();

%% run strategies
director.reset();
% strategy 每天更新orderList，给director执行，并记录每个pair的PnL，平仓时会自动画出pair的表现情况
director.run();
% 利用老师回测平台，得到策略的效果，放一张return的图，后续同学会详细解释
director.displayResult();
