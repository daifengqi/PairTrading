classdef pairTradingStrategy<mclasses.strategy.LFBaseStrategy
    
    properties(GetAccess = public, SetAccess = public)
        % 每个元素都是2维的，记录每天每只股票的持仓情况
        % 用于计算最终的PnL，NOTE: In order history, only the net positions of trades are saved,
        % where the details of individual pairs are discarded.
        holdingStruct;
        % 外部传入
        signalStruct;
        % 策略最多配置多少个pairs，方便后面初始化pairStruct
        maxNumOfPairs = 30;
        % 记录每对pair的信息，和holdingStruct不同，See Question5
        archivePairStruct;
        holdingPairStruct;
        % 最新的一个pair的序号，每对pairTrading都有唯一的序号，记录在pairsStruct里面
        recentPairID;
        gnOrderTmp;
        currDate;
        LongPosition;
        ShortPosition;
        LongCodes;
        ShortCodes;
        flag=0;
    end
    
    methods
        function obj = pairTradingStrategy(container, name)
            obj@mclasses.strategy.LFBaseStrategy(container, name);
            obj.LongPosition=[];
            obj.ShortPosition=[];
            obj.LongCodes=[];
            obj.ShortCodes=[];
        end
        
        function obj = initialize(obj,signalStruct)
            obj.signalStruct = signalStruct;
            marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
            generalData = marketData.getAggregatedDataStruct;
            orderPrice = generalData.stock.properties.(obj.orderPriceType);
            numOfDate = signalStruct.sharedInformation.numOfDate-signalStruct.wr-signalStruct.ws+1;
            numOfStock = signalStruct.stockUniverse.numOfStock;
            % 对于目前持有的pair（最多可以持有obj.maxNumOfPairs个）
            % 记录持有的信息，stockYOperate=1--> longPosition -1-->shortPosition
            % 为了方便obj.holdingStruct.position的计算
            obj.holdingPairStruct.colsName = {'pairID','expectedReturn','stockYLoc','stockYPosition',...
                'stockYOperate','stockXLoc','stockXPosition','stockXOperate'};
            obj.holdingPairStruct.pairInfo = zeros(obj.maxNumOfPairs,length(obj.holdingPairStruct.colsName));
            % 单纯记录每个股票的持仓情况，所有pair的加和
            obj.holdingStruct.position = zeros(numOfDate,numOfStock);
            obj.holdingStruct.orderPrice = orderPrice(obj.signalStruct.startDateLoc:obj.signalStruct.endDateLoc,...
                obj.signalStruct.stockUniverse.stockLocList);
        end
        
        function [orderList, delayList] = generateOrders(obj,currDate)
            orderList = [];
            delayList = [];
            obj.currDate=currDate;
            
            currAvailableCapital = 500000;   
            numPairAvail=sum(obj.holdingPairStruct.pairInfo(1,:)==0);
            obj.setOrder(currAvailableCapital,numPairAvail);
%             TODO: adjustOrder, close trades, cut loss
%             if numPairAvail ==0
%                 obj.adjustOrder(currAvailableCapital);
%             else
%                 obj.setOrder(currAvailableCapital,numPairAvail);
%             end

            
            % long side
            longAdjustOrder.operate = mclasses.asset.BaseAsset.ADJUST_LONG;
            %longAdjustOrder.account = obj.accounts('stockAccount');
            longAdjustOrder.price = obj.orderPriceType;
            longAdjustOrder.assetCode = obj.LongCodes;
            longAdjustOrder.quantity = obj.LongPosition;
            
            orderList = [orderList, longAdjustOrder];
            delayList = [delayList, 1];
            % short side
            shortAdjustOrder.operate = mclasses.asset.BaseAsset.ADJUST_SHORT;
            %shortAdjustOrder.account = obj.accounts('stockAccount');
            shortAdjustOrder.price = obj.orderPriceType;
            shortAdjustOrder.assetCode = obj.ShortCodes;
            shortAdjustOrder.quantity = obj.ShortPosition;
            
            orderList = [orderList, shortAdjustOrder];
            delayList = [delayList, 1];
        end

        % 开仓函数
        % 全部使用matrixCalculation
        % TODO：记录每个pair的详细信息
        function setOrder(obj,Capital,numPairAvail)
            currDateLoc = find(ismember(obj.signalStruct.sharedInformation.dateList(obj.signalStruct.wr+obj.signalStruct.ws:end),obj.currDate));
            signals = obj.signalStruct.signals;
            currOrderPrice = squeeze(obj.holdingStruct.orderPrice(currDateLoc,:));
            tickerName = obj.signalStruct.stockUniverse.windTicker;
            % 初筛是否valid（目前没用）
            currValidity = squeeze(signals.validity(currDateLoc,:,:));
            % 判断是否穿线
            currZscore = squeeze(signals.zScoreSe(currDateLoc,:,:,:));
            currZscoreEnd = currZscore(:,:,end);
            currZscoreEndAhead = currZscore(:,:,end-1);
            currUpPointBoundary = squeeze(signals.entryPointBoundary(currDateLoc,:,:));
            currLowPointBoundary = -currUpPointBoundary;
            % 从下穿上：short
            currShortPairLoc = (currZscoreEnd-currUpPointBoundary >0)&(currZscoreEndAhead-currUpPointBoundary<0);
            % 从上穿下：long
            currLongPairLoc = (currZscoreEndAhead-currLowPointBoundary>0)&(currZscoreEnd-currLowPointBoundary<0);
            % TODO: sort by ER
            currExpectdReturn = squeeze(signals.expectedReturn(currDateLoc,:,:));
            currLongPairER = currExpectdReturn(currLongPairLoc);
            
            currPairBeta = squeeze(signals.sBeta(currDateLoc,:,:));
            perPairCapital = Capital/numPairAvail;
            
            pairIDrecent = max(obj.holdingPairStruct.pairInfo(:,1));
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
                    pairIDrecent = pairIDrecent + 1;
                    loc = targetLongPairPositionLoc(i);
                    stockYLoc = currLongPairYLoc(loc);
                    stockYTicker = tickerName(stockYLoc);
                    stockYPosition = targetLongPairPosition(loc);
                    stockXLoc = currLongPairXLoc(loc);
                    stockXTicker = tickerName(stockXLoc);
                    stockXPosition = stockYPosition*abs(currLongPairXBeta(loc));
                    betaPlot = -currLongPairXBeta(loc);
                    % for hwk2 plot
                    zScoreSe = currZscore(stockYLoc,stockXLoc,:);
                    boudary = currUpPointBoundary(stockYLoc,stockXLoc);
                    figure();
                    plot(squeeze(zScoreSe));
                    title(sprintf('%s long\n %s *%d*%s',datestr(obj.currDate),stockYTicker{1},betaPlot,stockXTicker{1}));
                    set(gca,'XLim',[0 42]);
                    hold on
                    x=0:0.01:42;
                    y1=boudary*ones(1,length(x));
                    y2=-boudary*ones(1,length(x));
                    plot(x,y1,'color','r','linewidth',2)
                    plot(x,y2,'color','r','linewidth',2)                            
                    hold off
                    
                    % stockY是longSide，
                    obj.LongCodes = [obj.LongCodes,stockYTicker];
                    obj.LongPosition = [obj.LongPosition,stockYPosition];
                    % TODO：把pair的postion等信息更新到obj.holdingPairStruct
                    if -currLongPairXBeta(loc) > 0
                        obj.LongCodes = [obj.LongCodes,stockXTicker];
                        obj.LongPosition = [obj.LongPosition,stockXPosition];
                    else
                        obj.ShortCodes = [obj.ShortCodes,stockXTicker];
                        obj.ShortPosition = [obj.ShortPosition,stockXPosition];
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
                    % 更新pairID，计算各种postion和ticker
                    pairIDrecent = pairIDrecent + 1;
                    loc = targetShortPairPositionLoc(i);
                    stockYLoc = currShortPairYLoc(loc);
                    stockYTicker = tickerName(stockYLoc);
                    stockYPosition = targetShortPairPosition(loc);
                    stockXLoc = currShortPairXLoc(loc);
                    stockXTicker = tickerName(stockXLoc);
                    stockXPosition = stockYPosition*abs(currShortPairXBeta(loc));
                    % for hwk2 plot
                    betaPlot = -currShortPairXBeta(loc);
                    zScoreSe = currZscore(stockYLoc,stockXLoc,:);
                    boudary = currUpPointBoundary(stockYLoc,stockXLoc);
                    figure();
                    plot(squeeze(zScoreSe));
                    title(sprintf('%s short\n %s %d*%s',datestr(obj.currDate),stockYTicker{1},betaPlot,stockXTicker{1}));
                    set(gca,'XLim',[0 42]);
                    hold on
                    x=0:0.01:42;
                    y1=boudary*ones(1,length(x));
                    y2=-boudary*ones(1,length(x));
                    plot(x,y1,'color','r','linewidth',2)
                    plot(x,y2,'color','r','linewidth',2)                            
                    hold off
                    % stockY是shortSide，
                    obj.ShortCodes = [obj.ShortCodes,stockYTicker];
                    obj.ShortPosition = [obj.ShortPosition,stockYPosition];
                    % TODO：把pair的postion等信息更新到obj.holdingPairStruct
                    if -currShortPairXBeta(loc) > 0
                        obj.ShortCodes = [obj.ShortCodes,stockXTicker];
                        obj.ShortPosition = [obj.ShortPosition,stockXPosition];
                    else
                        obj.LongCodes = [obj.LongCodes,stockXTicker];
                        obj.LongPosition = [obj.LongPosition,stockXPosition];
                    end
                end
            end

        end
        
    end
end