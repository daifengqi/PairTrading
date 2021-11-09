classdef pairTradingStrategy<mclasses.strategy.LFBaseStrategy
    
    properties(GetAccess = public, SetAccess = public)
        % 每个元素都是2维的，记录每天每只股票的持仓情况
        % 注意！！！所有的dateLoc，stockLoc都是对于obj.signal里面的sharedInformation和stockUniverse而言的
        % 用于计算最终的PnL，NOTE: In order history, only the net positions of trades are saved,
        % where the details of individual pairs are discarded.
        holdingStruct;
        % 外部传入
        signalStruct;
        % 策略最多配置多少个pairs，方便后面初始化pairStruct
        maxNumOfPairs = 30;
        % 记录每对pair的信息，和holdingStruct不同，See Question5
        closedPairStruct;
        holdingPairStruct;
        % 最新的一个pair的序号，每对pairTrading都有唯一的序号，记录在pairsStruct里面
        recentPairID;
        gnOrderTmp;
        currDate;
        currDateLoc;
%         LongPosition;
%         ShortPosition;
%         LongCodes;
%         ShortCodes;
        flag=0;
        currPnL;
        cutWin=2;
        cutLoss=2;
        % 最多持有20天
        cutPeriod=20;
        tmpStruct;
        
    end
    
    methods
        function obj = pairTradingStrategy(container, name)
            obj@mclasses.strategy.LFBaseStrategy(container, name);
%             obj.LongPosition=[];
%             obj.ShortPosition=[];
%             obj.LongCodes=[];
%             obj.ShortCodes=[];
            obj.initCapital= 500000;
        end
        
        function prepareFields(obj,signalStruct)
%             obj@mclasses.strategy.LFBaseStrategy.initialize(params);
%             obj.signalStruct = pairTradingSignal(obj.startDateStr,obj.endDateStr,obj.sectorNum);
            obj.signalStruct = signalStruct;
            marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
            generalData = marketData.getAggregatedDataStruct;
            orderPrice = generalData.stock.properties.(obj.orderPriceType);
            numOfDate = obj.signalStruct.sharedInformation.numOfDate-obj.signalStruct.wr-obj.signalStruct.ws+1;
            numOfStock = obj.signalStruct.stockUniverse.numOfStock;
            % 对于目前持有的pair（最多可以持有obj.maxNumOfPairs个）
            % 记录持有的信息，stockYOperate=1--> longPosition -1-->shortPosition
            % 为了方便obj.holdingStruct.position的计算
            obj.holdingPairStruct.description = {'pairID','openDateLoc','openDateNum','expectedReturn','stockYLoc','openPriceY','stockYPosition',...
                'stockYOperate','stockXLoc','openPriceX','stockXPosition','stockXOperate'};
            for i = 1:length(obj.holdingPairStruct.description)
                obj.holdingPairStruct.(obj.holdingPairStruct.description{i})=zeros(obj.maxNumOfPairs,1);
            end
%             obj.holdingPairStruct.pairInfoArr = zeros(obj.maxNumOfPairs,length(obj.holdingPairStruct.description));
            % 单纯记录每个股票的持仓情况，所有pair的加和，为了最后直接从holdingStruct得到orderList
            obj.holdingStruct.position = zeros(numOfDate,numOfStock);
            obj.holdingStruct.orderPrice = orderPrice(obj.signalStruct.startDateLoc:obj.signalStruct.endDateLoc,...
                obj.signalStruct.stockUniverse.stockLocList);
            % 记录已经close了的pair的info
            obj.closedPairStruct.description = {'pairID','openDateLoc','openDateNum','closeDateLoc','closeDateNum','stockYLoc','openPriceY','stockYPosition',...
                'stockYOperate','stockXLoc','openPriceX','stockXPosition','stockXOperate','closeReason'};
            for i = 1:length(obj.closedPairStruct.description)
                obj.closedPairStruct.(obj.closedPairStruct.description{i})=[];
            end
            % TODO 给closeReason设置对应的说明
%             obj.closedPairStruct.closeReasonDescription = struct(1,'cut win',2,'cut loss',3,'is not valid')
        end
        
        function [orderList, delayList] = generateOrders(obj,currDate)
            obj.currDate=currDate;
            % 计算一下最近的PnL，利用obj.holdingPairStruct+obj.currAvailableCapital
            obj.currDateLoc = find(ismember(obj.signalStruct.sharedInformation.dateList(obj.signalStruct.wr+obj.signalStruct.ws:end),obj.currDate));
            obj.updatePnL();
            % 开始调仓前，先看一下holdingPairStruct中有没有需要close的order
            % 更新holdingPairStruct（其实就是把close的部分移到closedPairStruct里面）
            % ！不用返回！这个结果的orderList
            % 直接在每天的最后根据holdingPairStruct得到一个新的holdindgStruct
            % 根据obj.holdindgStruct来确定最后的orderList
            obj.checkHoldingPair();
            orderList = [];
            delayList = [];
            
            % TODO: currAvailableCapital = initCapital - usedCapital
            currAvailableCapital = 500000;   
            numPairAvail = sum(obj.holdingPairStruct.pairID(:,1)==0);
            % TODO: adjustOrder, close trades, cut loss
            % closeOrder ing 2021-11-09-20:39
            if numPairAvail ==0
                obj.adjustOrder(currAvailableCapital);
            else
                obj.setOrder(currAvailableCapital,numPairAvail);
            end
            % 利用obj.holdingPairStruct整合出obj.holdingStruct.position(obj.currDate)
            % 再得到ADJUST_LONG和ADJUST_SHORT的postion和codes的信息！
            [LongCodes,LongPosition,ShortCodes,ShortPosition] = obj.adjustPairCodePosition();
            % long side
            longAdjustOrder.operate = mclasses.asset.BaseAsset.ADJUST_LONG;
            longAdjustOrder.account = obj.accounts('stockAccount');
            longAdjustOrder.price = obj.orderPriceType;
            longAdjustOrder.assetCode = LongCodes;
            longAdjustOrder.quantity = LongPosition;
            
            orderList = [orderList, longAdjustOrder];
            delayList = [delayList, 1];
            % short side
            shortAdjustOrder.operate = mclasses.asset.BaseAsset.ADJUST_SHORT;
            shortAdjustOrder.account = obj.accounts('stockAccount');
            shortAdjustOrder.price = obj.orderPriceType;
            shortAdjustOrder.assetCode = ShortCodes;
            shortAdjustOrder.quantity = ShortPosition;
            
            orderList = [orderList, shortAdjustOrder];
            delayList = [delayList, 1];
        end

        % 开仓函数
        % 全部使用matrixCalculation
        % TODO：记录每个pair的详细信息
        function setOrder(obj,Capital,numPairAvail)
            signals = obj.signalStruct.signals;
            currOrderPrice = squeeze(obj.holdingStruct.orderPrice(obj.currDateLoc,:));
            tickerName = obj.signalStruct.stockUniverse.windTicker;
            
            % 初筛是否valid（目前没用）
            currValidity = squeeze(signals.validity(obj.currDateLoc,:,:));
            % FIXME: debug完可以删除
            datestr(obj.currDate,'yyyymmdd')
            find(currValidity)
            % 判断是否穿线
            currZscore = squeeze(signals.zScoreSe(obj.currDateLoc,:,:,:));
            currZscoreEnd = currZscore(:,:,end);
            currZscoreEndAhead = currZscore(:,:,end-1);
            currUpPointBoundary = squeeze(signals.entryPointBoundary(obj.currDateLoc,:,:));
            currLowPointBoundary = -currUpPointBoundary;
            % 从下穿上：short
            currShortPairLoc = (currZscoreEnd-currUpPointBoundary >0)&(currZscoreEndAhead-currUpPointBoundary<0);
            % 从上穿下：long
            currLongPairLoc = (currZscoreEndAhead-currLowPointBoundary>0)&(currZscoreEnd-currLowPointBoundary<0);
            % TODO: sort by ER, long short portfolio direction???
            currExpectdReturn = squeeze(signals.expectedReturn(obj.currDateLoc,:,:));
            currLongPairER = currExpectdReturn(currLongPairLoc);
            currShortPairER = currExpectdReturn(currShortPairLoc);
            
            currPairBeta = squeeze(signals.sBeta(obj.currDateLoc,:,:));
            perPairCapital = Capital/numPairAvail;
            currPairCount = 0;
            pairIDrecent = max(obj.holdingPairStruct.pairID(:,1));
            
            % 对于需要加入的long的pair
            % TODO：先按照ER排序后，根据numPairAvail定好需要加入的pair
            % 目前就最简单的方式，从longPair开始按顺序加进去，直到加满位置（currPairCount记录）
            [currLongPairYLoc,currLongPairXLoc] = find(currLongPairLoc);
            if ~isempty(currLongPairYLoc)
                currLongPairYPrice = currOrderPrice(currLongPairYLoc)';
                currLongPairXPrice = currOrderPrice(currLongPairXLoc)';
                currLongPairXBeta = currPairBeta(currLongPairLoc);
                currLongPairPrice = currLongPairYPrice+abs(currLongPairXBeta).*currLongPairXPrice;
                targetLongPairPosition = floor(perPairCapital*0.85 /currLongPairPrice /100)*100;
                targetLongPairPositionLoc = find(targetLongPairPosition);
                for i = 1:length(targetLongPairPositionLoc)
                    % 更新pairID，计算各种postion和ticker
                    currPairCount = currPairCount+1;
                    if currPairCount > numPairAvail
                        break
                    end
                    pairIDrecent = pairIDrecent + 1;
                    loc = targetLongPairPositionLoc(i);
                    stockYLoc = currLongPairYLoc(loc);
                    stockYPosition = targetLongPairPosition(loc);
                    stockXLoc = currLongPairXLoc(loc);
                    stockXPosition = floor(stockYPosition*abs(currLongPairXBeta(loc))/100)*100;
                    pairER = currLongPairER(loc);
                    openPriceY = currLongPairYPrice(loc);
                    openPriceX = currLongPairXPrice(loc);
                    
                    % 更新holdingPairStruct里面的内容
                    pairIDempty = find(obj.holdingPairStruct.pairID==0);
                    pairRowLoc = pairIDempty(1);
                    obj.holdingPairStruct.pairID(pairRowLoc,1) = pairIDrecent;
                    obj.holdingPairStruct.openDateLoc(pairRowLoc,1) = obj.currDateLoc;
                    obj.holdingPairStruct.openDateNum(pairRowLoc,1) = obj.currDate;
                    obj.holdingPairStruct.expectedReturn(pairRowLoc,1) = pairER;
                    obj.holdingPairStruct.stockYLoc(pairRowLoc,1) = stockYLoc;
                    obj.holdingPairStruct.openPriceY(pairRowLoc,1) = openPriceY;
                    obj.holdingPairStruct.stockYPosition(pairRowLoc,1) = stockYPosition;
                    obj.holdingPairStruct.stockYOperate(pairRowLoc,1) = 1;
                    obj.holdingPairStruct.stockXLoc(pairRowLoc,1) = stockXLoc;
                    obj.holdingPairStruct.openPriceX(pairRowLoc,1) = openPriceX;
                    obj.holdingPairStruct.stockXPosition(pairRowLoc,1) = stockXPosition;
                    if -currLongPairXBeta(loc) > 0
                        obj.holdingPairStruct.stockXOperate(pairRowLoc,1) = 1;
                    else
                        obj.holdingPairStruct.stockXOperate(pairRowLoc,1) = -1;
                    end
                    
                end
                
            end
            % 同理对于short的pair一样的操作
            [currShortPairYLoc,currShortPairXLoc] = find(currShortPairLoc);
            if ~isempty(currShortPairYLoc)
                currShortPairYPrice = currOrderPrice(currShortPairYLoc)';
                currShortPairXPrice = currOrderPrice(currShortPairXLoc)';
                currShortPairXBeta = currPairBeta(currShortPairLoc);
                currShortPairPrice = currShortPairYPrice+abs(currShortPairXBeta).*currShortPairXPrice;
                targetShortPairPosition = floor(perPairCapital*0.85 /currShortPairPrice /100)*100;
                targetShortPairPositionLoc = find(targetShortPairPosition);
                for i = 1:length(targetShortPairPositionLoc)
                    currPairCount = currPairCount+1;
                    if currPairCount > numPairAvail
                        break
                    end
                    % 更新pairID，计算各种postion和ticker
                    pairIDrecent = pairIDrecent + 1;
                    loc = targetShortPairPositionLoc(i);
                    stockYLoc = currShortPairYLoc(loc);
                    stockYPosition = targetShortPairPosition(loc);
                    stockXLoc = currShortPairXLoc(loc);
                    stockXPosition = floor(stockYPosition*abs(currShortPairXBeta(loc))/100)*100;
                    pairER = currShortPairER(loc);
                    openPriceY = currShortPairYPrice(loc);
                    openPriceX = currShortPairXPrice(loc);
                    % 更新holdingPairStruct里面的内容
                    pairIDempty = find(obj.holdingPairStruct.pairID==0);
                    pairRowLoc = pairIDempty(1);
                    obj.holdingPairStruct.pairID(pairRowLoc,1) = pairIDrecent;
                    obj.holdingPairStruct.openDateLoc(pairRowLoc,1) = obj.currDateLoc;
                    obj.holdingPairStruct.openDateNum(pairRowLoc,1) = obj.currDate;
                    obj.holdingPairStruct.expectedReturn(pairRowLoc,1) = pairER;
                    obj.holdingPairStruct.stockYLoc(pairRowLoc,1) = stockYLoc;
                    obj.holdingPairStruct.openPriceY(pairRowLoc,1) = openPriceY;
                    obj.holdingPairStruct.stockYPosition(pairRowLoc,1) = stockYPosition;
                    obj.holdingPairStruct.stockYOperate(pairRowLoc,1) = -1;
                    obj.holdingPairStruct.stockXLoc(pairRowLoc,1) = stockXLoc;
                    obj.holdingPairStruct.openPriceX(pairRowLoc,1) = openPriceX;
                    obj.holdingPairStruct.stockXPosition(pairRowLoc,1) = stockXPosition;
                    if -currShortPairXBeta(loc) > 0
                        obj.holdingPairStruct.stockXOperate(pairRowLoc,1) = -1;
                    else
                        obj.holdingPairStruct.stockXOperate(pairRowLoc,1) = 1;
                    end
                end
            end

        end
        
        % 每次开始前先check现有的持仓中有没有需要平仓的
        function checkHoldingPair(obj)
            obj.tmpStruct.closeHoldingPair.orderList = [];
            % check obj.holdingPairStruct and see whether certain pair can
            % be closed by reason 
            % 获取当前的holdingPairStruct
            currHoldingPairStruct = obj.holdingPairStruct;
            if isempty(find(currHoldingPairStruct.pairID>0,1))
                return
            end
            signals = obj.signalStruct.signals;
            % 当前的zScore信息
            currZscore = squeeze(signals.zScoreSe(obj.currDateLoc,:,:,:));
            % 初筛是否valid（目前没用）
            currValidity = squeeze(signals.validity(obj.currDateLoc,:,:));
            % 对于目前持有的pairs循环，分析是否达到close的条件
            % 1，cutWin：达到止盈的标准
            % 2，cutLoss：达到止损的标准
            % 3，cutPeriod：持有时期过长，强制平仓
            % 4，目前这个pair已经不是valid了，直接平仓（signal那边需要check计算）
            for pairRowLoc = 1:length(find(currHoldingPairStruct.pairID>0))
                plotFlag = 0;
                stockYLoc = currHoldingPairStruct.stockYLoc(pairRowLoc,1);
                stockXLoc = currHoldingPairStruct.stockXLoc(pairRowLoc,1);
                stockYOperate = currHoldingPairStruct.stockYOperate(pairRowLoc,1);
                pairValidity = currValidity(stockYLoc,stockXLoc);
                openDateNum = currHoldingPairStruct.openDateNum(pairRowLoc,1);
                % 先判断 3和4
                if obj.currDate-openDateNum>obj.cutPeriod
                    obj.holdingPairToClosedPair(pairRowLoc,3);
                    plotFlag = 1;
                end
                if ~pairValidity
                    obj.holdingPairToClosedPair(pairRowLoc,4);
                    plotFlag = 1;
                end
                % 判断1和2

                pairZscoreEnd = currZscore(stockYLoc,stockXLoc,end);
                pairZscoreEndAhead = currZscore(stockYLoc,stockXLoc,end-1);
                % 判断是long的话，
                if stockYOperate > 0
                    if pairZscoreEnd-pairZscoreEndAhead>obj.cutWin
                        obj.holdingPairToClosedPair(pairRowLoc,1);
                        plotFlag = 1;
                    elseif pairZscoreEnd-pairZscoreEndAhead<-obj.cutLoss
                        obj.holdingPairToClosedPair(pairRowLoc,2);
                        plotFlag = 1;
                    
                    end
                end
                % 判断是short的话，
                if stockYOperate < 0
                    if pairZscoreEnd-pairZscoreEndAhead<-obj.cutWin
                        obj.holdingPairToClosedPair(pairRowLoc,1)
                        plotFlag = 1;
                    elseif pairZscoreEnd-pairZscoreEndAhead>obj.cutLoss
                        obj.holdingPairToClosedPair(pairRowLoc,2)
                        plotFlag = 1;
                    end
                end
                % 判断是否需要画图
                if plotFlag > 0
                    currPairZscoreSe = squeeze(currZscore(stockYLoc,stockXLoc,:));
                    currPairBoundary = signals.entryPointBoundary(obj.currDateLoc,stockYLoc,stockXLoc);
                    stockYTicker = obj.signalStruct.stockUniverse.windTicker(stockYLoc);
                    stockXTicker = obj.signalStruct.stockUniverse.windTicker(stockXLoc);
                    betaPlot = signal.sBeta(obj.currDateLoc,stockYLoc,stockXLoc);
                    plotOrderClose(currPairZscoreSe,currPairBoundary,stockYTicker,stockXTicker,betaPlot);
                end
                
            end
            orderList = obj.tmpStruct.closeHoldingPair.orderList;
        end
                    
        function updatePnL(obj)
            
        end
        
        function adjustOrder(obj,currAvailableCapital)
            
        end
        
        % 输入pair在obj.holdingPairStruct的位置pairRowLoc，以及平仓的原因序号
        % 实现功能：把obj.holdingPairStruct中该pair的信息删除
        % 存入到obj.closedPairStruct中，并加入closeDate与closeReason的信息
        function holdingPairToClosedPair(obj,pairRowLoc,closeReason)
            for i = 1:length(obj.holdingPairStruct.description)
                infoName = obj.holdingPairStruct.description{:,i};
                infoValue = obj.holdingPairStruct.(infoName)(pairRowLoc,1);
                obj.holdingPairStruct.(infoName)(pairRowLoc,1)=0;
                if strcmp(infoName, 'expectedReturn')
                    continue
                end
                obj.closedPairStruct.(infoName) = [obj.closedPairStruct.(infoName),infoValue];
                obj.closedPairStruct.closeDateLoc = obj.currDateLoc;
                obj.closedPairStruct.closeDateNum = obj.currDate;
                % closeReason 1: cutWin 2:cutLoss 3:cutPeriod 4:notValid
                obj.closedPairStruct.closeReason = closeReason;
             end
        end
        
        function [LongCodes,LongPosition,ShortCodes,ShortPosition] = adjustPairCodePosition(obj)
            % 初始化返回值
            LongCodes = [];
            LongPosition = [];
            ShortCodes = [];
            ShortPosition = [];
            % 判断这一天是否有holdingPairStruct
            currPairLoc = find(obj.holdingPairStruct.pairID>0);
            tickerName = obj.signalStruct.stockUniverse.windTicker;
            adjPosition = zeros(1,length(tickerName));
            for i = 1:length(currPairLoc)
                stockYLoc = obj.holdingPairStruct.stockYLoc(i,1);
                stockYPosition = obj.holdingPairStruct.stockYPosition(i,1);
                stockYOperate = obj.holdingPairStruct.stockYOperate(i,1);
                adjPosition(1,stockYLoc) = adjPosition(1,stockYLoc)+(stockYPosition*stockYOperate);
                stockXLoc = obj.holdingPairStruct.stockXLoc(i,1);
                stockXPosition = obj.holdingPairStruct.stockXPosition(i,1);
                stockXOperate = obj.holdingPairStruct.stockXOperate(i,1);
                adjPosition(1,stockXLoc) = adjPosition(1,stockXLoc)+(stockXPosition*stockXOperate);
            end
            obj.holdingStruct.position(obj.currDateLoc,:) = adjPosition;
            LongCodes = [LongCodes,tickerName(adjPosition>0)];
            LongPosition = [LongPosition,adjPosition(adjPosition>0)];
            ShortCodes = [ShortCodes,tickerName(adjPosition<0)];
            ShortPosition = [ShortPosition,abs(adjPosition(adjPosition<0))];
        end
    end
    
    methods(Static)
        % 用于画出平仓时的图
        % TODO:画买入卖出的点
        function plotOrderClose(zScoreSe,boudary,currDate,stockYTicker,stockXTicker,betaPlot)
            figure();
            plot(squeeze(zScoreSe));
            title(sprintf('%s long\n %s *%d*%s',datestr(currDate),stockYTicker{1},betaPlot,stockXTicker{1}));
            set(gca,'XLim',[0 42]);
            hold on
            x=0:0.01:42;
            y1=boudary*ones(1,length(x));
            y2=-boudary*ones(1,length(x));
            plot(x,y1,'color','r','linewidth',2)
            plot(x,y2,'color','r','linewidth',2)                            
            hold off
        end
    end
    
end