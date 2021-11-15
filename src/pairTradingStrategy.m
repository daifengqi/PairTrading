classdef PairTradingStrategy<mclasses.strategy.LFBaseStrategy
    
    properties(GetAccess = public, SetAccess = public)
        % 每个元素都是2维的，记录每天每只股票的持仓情况
        % 注意！！！
        % TODO:所有的dateLoc，stockLoc都是对于obj.signal里面的sharedInformation和stockUniverse而言的
        % 和obj.holdingStruct.orderPrice的length对齐的
        % 用于计算最终的PnL，NOTE: In order history, only the net positions of trades are saved,
        % where the details of individual pairs are discarded.
        holdingStruct;
        % 外部传入
        signalStruct;
        % 策略最多配置多少个pairs，方便后面初始化pairStruct
        maxNumOfPairs = 30;
        % 记录每对pair的信息，和holdingStruct不同，See Question5
        % closedPairStruct用来记录已经close的order，close的当天会画图
        % holdingPairStruct用来记录正在持有的order，每天开始前先check有无需要close的
        % 根据holdingPairStruct计算得到每天的holdingStruct，即stockUniverse里面每个ticker对应的position
        % 
        holdingPairStruct;
        closedPairStruct;
        % 最新的一个pair的序号，每对pairTrading都有唯一的序号
        % 记录在holdingPairStruct和closedPairStruct里面
        recentPairID;
        gnOrderTmp;
        % 目前的日期，是datenum
        currDate;
        % 目前日期所在位置，这里loc相对于signalStruct.sharedInformation.dateList而言
        currDateLoc;
        % 止盈：当前pairPnL是否超过了cutWin，超过则止盈
        % 止损同理
        % TODO: 按照ER的百分比来计算
        cutWin=0.03;
        cutLoss=-0.03;
        % 最多持有20天，currDateLoc-openDateLoc>cutPeriod的时候强制平仓
        cutPeriod=20;
        % 外部config
        startDateStr;
        endDateStr;
        sectorNum;
        % 最多画20个图
        maxNumPlot=20;
        capitalAvail;
        capitalInit=5e6;
        adjERratio=2;
    end
    
    methods
        function obj = PairTradingStrategy(container, name)
            obj@mclasses.strategy.LFBaseStrategy(container, name);
        end
        
        function prepareFields(obj)
            obj.capitalAvail = obj.capitalInit;
            obj.signalStruct = PairTradingSignal(obj.startDateStr,obj.endDateStr,obj.sectorNum);
            obj.signalStruct.calSignals();
            marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
            generalData = marketData.getAggregatedDataStruct;
            orderPrice = generalData.stock.properties.(obj.orderPriceType);
            numOfDate = obj.signalStruct.sharedInformation.numOfDate;
            numOfStock = obj.signalStruct.stockUniverse.numOfStock;
            % 对于目前持有的pair（最多可以持有obj.maxNumOfPairs个）
            % 记录持有的信息，stockYOperate=1--> longPosition -1-->shortPosition
            % 为了方便obj.holdingStruct.position的计算
            obj.holdingPairStruct.description = {'pairID','openDateLoc','openDateNum','expectedReturn',...
                'stockYLoc','openPriceY','stockYPosition',...
                'stockYOperate','stockXLoc','openPriceX','stockXPosition','stockXOperate','pairPriceSe'};
            for i = 1:length(obj.holdingPairStruct.description)-1
                obj.holdingPairStruct.(obj.holdingPairStruct.description{i})=zeros(obj.maxNumOfPairs,1);
            end
            obj.holdingPairStruct.pairPriceSe = zeros(obj.maxNumOfPairs,obj.cutPeriod);
%             obj.holdingPairStruct.pairInfoArr = zeros(obj.maxNumOfPairs,length(obj.holdingPairStruct.description));
            % 单纯记录每个股票的持仓情况，所有pair的加和，为了最后直接从holdingStruct得到orderList
            obj.holdingStruct.position = zeros(numOfDate,numOfStock);
            obj.holdingStruct.orderPrice = orderPrice(obj.signalStruct.loadPriceStartDateLoc:obj.signalStruct.endDateLoc,...
                obj.signalStruct.stockUniverse.stockLocList);
            assert(length(obj.holdingStruct.position)==length(obj.holdingStruct.orderPrice),'obj.holdingStruct size' );
            % 记录已经close了的pair的info
            obj.closedPairStruct.description = {'pairID','openDateLoc','openDateNum',...
                'closeDateLoc','closeDateNum','stockYLoc','openPriceY','stockYPosition',...
                'stockYOperate','stockXLoc','openPriceX','stockXPosition',...
                'stockXOperate','closeReason','pairPriceSe'};
            for i = 1:length(obj.closedPairStruct.description)
                obj.closedPairStruct.(obj.closedPairStruct.description{i})=[];
            end
            % TODO 给closeReason设置对应的说明
            obj.closedPairStruct.closeReasonDescription = {'cutWin','cutLoss','cutPeriod','notValid'};
        end
        
        function [orderList, delayList] = generateOrders(obj,currDate)
            % 计算一下最近的PnL，利用obj.holdingPairStruct+obj.currAvailableCapital
            % 在signalStruct.sharedInformation.dateList中，真正的
            % 起始位置是obj.signalStruct.wr+obj.signalStruct.ws-2    
            obj.currDate=currDate;
            obj.currDateLoc = find(ismember(obj.signalStruct.sharedInformation.dateList,obj.currDate));
            obj.updateHoldingPairPrice();
            
            % 开始调仓前，先看一下holdingPairStruct中有没有需要close的order
            % 更新holdingPairStruct（其实就是把close的部分移到closedPairStruct里面）
            % ！不用返回！这个结果的orderList
            % 直接在每天的最后根据holdingPairStruct得到一个新的holdindgStruct
            % 根据obj.holdindgStruct来确定最后的orderList
            obj.checkHoldingPairToClosed();
            orderList = [];
            delayList = [];
           

            % 更新obj.capitalAvail            
            % TODO: currAvailableCapital = initCapital - usedCapital  
            numPairAvail = sum(obj.holdingPairStruct.pairID(:,1)==0);
            
            % TODO: adjustOrder, close trades, cut loss
            % closeOrder ing 2021-11-09-20:39
            if (numPairAvail ==0) | (isempty(obj.capitalAvail))
                obj.adjustOrder();
            else
                obj.setOrder(numPairAvail);
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
        function setOrder(obj,numPairAvail)
            disp(obj.capitalAvail);
            signals = obj.signalStruct.signals;
            currOrderPrice = squeeze(obj.holdingStruct.orderPrice(obj.currDateLoc,:));
            tickerName = obj.signalStruct.stockUniverse.windTicker;
            % 初筛是否valid（目前没用）
            currValidity = squeeze(signals.validity(obj.currDateLoc,:,:));
            % FIXME: debug完可以删除
            datestr(obj.currDate,'yyyymmdd')
%             find(currValidity)
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
            perPairCapital = obj.capitalAvail/numPairAvail;
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
                    pairPrice = openPriceY*stockYPosition+openPriceX*stockXPosition;
                    % 更新可用资金
                    obj.capitalAvail = obj.capitalAvail - pairPrice;
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
                    pairPrice = openPriceY*stockYPosition+openPriceX*stockXPosition;
                    % 更新可用资金
                    obj.capitalAvail = obj.capitalAvail - pairPrice;
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
        
        % 只更新pair的价格，价值的话要再乘以stockYPosition后看变化
        % 第i个是持有了i天的price，openDate没有计算进去哈！！
        function updateHoldingPairPrice(obj)
            % 获取当前的holdingPairStruct
            if isempty(find(obj.holdingPairStruct.pairID>0,1))
                return
            end
            currHoldingPairLoc = find(obj.holdingPairStruct.pairID>0);
            for i = 1:length(currHoldingPairLoc)
                pairRowLoc = currHoldingPairLoc(i);
                openDateLoc = obj.holdingPairStruct.openDateLoc(pairRowLoc,1);
                openPeirodGap = obj.currDateLoc-openDateLoc;
                stockYLoc = obj.holdingPairStruct.stockYLoc(pairRowLoc,1);
                stockXLoc = obj.holdingPairStruct.stockXLoc(pairRowLoc,1);
                openPriceY = obj.holdingPairStruct.openPriceY(pairRowLoc,1);
                openPriceX = obj.holdingPairStruct.openPriceX(pairRowLoc,1);
                stockYPosition = obj.holdingPairStruct.stockYPosition(pairRowLoc,1);
                stockXPosition = obj.holdingPairStruct.stockXPosition(pairRowLoc,1);
                stockYOperate = obj.holdingPairStruct.stockYOperate(pairRowLoc,1);
                stockXOperate = obj.holdingPairStruct.stockXOperate(pairRowLoc,1);
                currPriceY = obj.holdingStruct.orderPrice(obj.currDateLoc,stockYLoc);
                currPriceX = obj.holdingStruct.orderPrice(obj.currDateLoc,stockXLoc);
                obj.holdingPairStruct.pairPriceSe(pairRowLoc,openPeirodGap) = stockYOperate*currPriceY+stockXOperate*currPriceX*stockXPosition*stockYPosition;
            end
        end
        
        % 每次开始前先check现有的持仓中有没有需要平仓的
        function checkHoldingPairToClosed(obj)
            % check obj.holdingPairStruct and see whether certain pair can
            % be closed by reason 
            % 获取当前的holdingPairStruct
            % Attention:这里需要用currHoldingPairStruct，因为下面操作
            % 可能会把obj.holdingPairStruct改动
            currHoldingPairStruct = obj.holdingPairStruct;
            if isempty(find(currHoldingPairStruct.pairID>0,1))
                return
            end
            signals = obj.signalStruct.signals;
            % 初筛是否valid（目前没用）
            currValidity = squeeze(signals.validity(obj.currDateLoc,:,:));
            % 对于目前持有的pairs循环，分析是否达到close的条件
            % 1，cutWin：达到止盈的标准，比较当前pairPnL是否大于cutWin
            % 2，cutLoss：达到止损的标准，比较当前pairPnL是否小于cutLoss
            % 3，cutPeriod：持有时期过长，强制平仓
            % 4，目前这个pair已经不是valid了，直接平仓（signal那边需要check计算）
            % TODO：检查4中的validity计算是否正确
            
            currHoldingPairLoc = find(currHoldingPairStruct.pairID>0);
            for i = 1:length(currHoldingPairLoc)
                pairRowLoc = currHoldingPairLoc(i);
                plotFlag = 0;
                openDateLoc = currHoldingPairStruct.openDateLoc(pairRowLoc,1);
                openPeirodGap = obj.currDateLoc-openDateLoc;
                stockYLoc = currHoldingPairStruct.stockYLoc(pairRowLoc,1);
                stockXLoc = currHoldingPairStruct.stockXLoc(pairRowLoc,1);
                pairValidity = currValidity(stockYLoc,stockXLoc);
                openDateNum = currHoldingPairStruct.openDateNum(pairRowLoc,1);
                % 先判断 3和4
                if obj.currDateLoc-openDateLoc>obj.cutPeriod
                    obj.holdingPairToClosedPair(pairRowLoc,3);
                    plotFlag = 3;
                end
                if ~pairValidity
                    obj.holdingPairToClosedPair(pairRowLoc,4);
                    plotFlag = 4;
                end
                % 判断1和2
                % 计算出目前从regression开始的pairPriceSe，看最近的currPairPrice是否达到止盈止损
                % 起始日期是：openDateLoc-obj.signalStruct.wr+1
                % TODO：做了多余计算，有空简化一下
                % openDateLoc就已经在pairPriceSe里面了，是第一个
                % 所以取priceYSe的时候应该到openDateLoc+currPriceLoc-1（需要减去1）
                % orderPrice的开始是从strategy的startDate开始的
                % FIXME: dateLoc究竟是相对于那里的？？？
%                 priceYSe = obj.holdingStruct.orderPrice(openDateLoc-obj.signalStruct.wr-obj.signalStruct.ws+2:openDateLoc+currPriceLoc-1,stockYLoc);
%                 priceXSe = obj.holdingStruct.orderPrice(openDateLoc-obj.signalStruct.wr-obj.signalStruct.ws+2:openDateLoc+currPriceLoc-1,stockXLoc);
                priceYSe = obj.holdingStruct.orderPrice(openDateLoc-obj.signalStruct.wr+1:obj.currDateLoc,stockYLoc);
                priceXSe = obj.holdingStruct.orderPrice(openDateLoc-obj.signalStruct.wr+1:obj.currDateLoc,stockXLoc);
                stockYPosition = currHoldingPairStruct.stockYPosition(pairRowLoc,1);
                stockXPosition = currHoldingPairStruct.stockXPosition(pairRowLoc,1);
                stockYOperate = currHoldingPairStruct.stockYOperate(pairRowLoc,1);
                stockXOperate = currHoldingPairStruct.stockXOperate(pairRowLoc,1);
                openPriceY = priceYSe(obj.signalStruct.wr);
                openPriceX = priceXSe(obj.signalStruct.wr);
                currPriceY = priceYSe(end);
                currPriceX = priceXSe(end);
                pairPriceSe = priceYSe*stockYPosition+stockYOperate*stockXOperate*priceXSe*stockXPosition;
                pairCapital = abs(priceYSe(obj.signalStruct.wr)*stockYPosition)+abs(priceXSe(obj.signalStruct.wr)*stockXPosition);
                openPairPrice = pairPriceSe(obj.signalStruct.wr);
                currPairPrice = pairPriceSe(end);
                cutWinPairPrice = openPairPrice+pairCapital*obj.cutWin*stockYOperate;
                cutLossPairPrice = openPairPrice+pairCapital*obj.cutLoss*stockYOperate;
                % 注意short和long这个pair的时候逻辑问题
                % stockYOperate*！！！
                if stockYOperate*currPairPrice > stockYOperate*cutWinPairPrice
                    obj.holdingPairToClosedPair(pairRowLoc,1);
                    plotFlag = 1;
                end
                if stockYOperate*currPairPrice < stockYOperate*cutLossPairPrice
                    obj.holdingPairToClosedPair(pairRowLoc,2);
                    plotFlag = 2;
                end
                % 更新obj.capitalAvail
                if plotFlag > 0 
                    pairPnL = stockYOperate*(currPriceY-openPriceY)*stockYPosition + ...
                        stockXOperate*(currPriceX-openPriceX)*stockXPosition;
                    obj.capitalAvail = obj.capitalAvail + pairCapital + pairPnL;
                end
                
                % 判断是否需要画图
                % 画出从openDate开始的PnL的图
                % TODO: 每种情况都画两个图
                if (plotFlag > 0) & (obj.maxNumPlot > 0)

                    if stockYOperate > 0
                        pairOperate = 'long';
                    else
                        pairOperate = 'short';
                    end
                    stockYTicker = obj.signalStruct.stockUniverse.windTicker{stockYLoc};
                    stockXTicker = obj.signalStruct.stockUniverse.windTicker{stockXLoc};
                    betaPlot = signals.sBeta(openDateLoc,stockYLoc,stockXLoc);
                    dateStr = datestr(obj.currDate,'yyyymmdd');
                    closeReasonStr = obj.closedPairStruct.closeReasonDescription{plotFlag};
                    seLen = length(pairPriceSe);
%                     mu = obj.signalStruct.signals.mu(obj.currDateLoc,stockYLoc,stockXLoc);
%                     sigma = obj.signalStruct.signals.sigma(obj.currDateLoc,stockYLoc,stockXLoc);
%                     entryBoundary =  obj.signalStruct.signals.entryPointBoundary(obj.currDateLoc,stockYLoc,stockXLoc);
                    % 开始画图
                    figure();
                    plot(squeeze(pairPriceSe),'-k','MarkerSize',5);
                    
                    title(sprintf('%s %s %s \n %s *%.2f*%s',closeReasonStr,dateStr,pairOperate,...
                        stockYTicker,betaPlot,stockXTicker));
                    xlim auto
                    ylim auto
                    hold on
                    x=0:0.01:seLen+2;
                    % cutWin line
                    y1=cutWinPairPrice*ones(1,length(x));
                    % cutLoss line
                    y2=cutLossPairPrice*ones(1,length(x));
                    plot(squeeze(idealPriceSe),'-','MarkerSize',5);
                    plot(x,y1,'--','color','r','linewidth',2);
                    plot(x,y2,'--','color','g','linewidth',2);
                    plot(seLen,currPairPrice,'^r','MarkerSize',3);
                    plot(obj.signalStruct.wr,openPairPrice,'^b','MarkerSize',3);
                    text(seLen-2,cutWinPairPrice,'cut win');
                    text(seLen-2,cutLossPairPrice,'cut loss');
                    xlim auto
                    ylim auto
                    hold off
                    obj.maxNumPlot =obj.maxNumPlot -1;
                end
                
            end
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
                % 选择按上下拼接，因为pairPriceSe是(1,obj.cutPeirod)的维度
                obj.closedPairStruct.(infoName) = [obj.closedPairStruct.(infoName);infoValue];
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
                loc = currPairLoc(i);
                stockYLoc = obj.holdingPairStruct.stockYLoc(loc,1);
                stockYPosition = obj.holdingPairStruct.stockYPosition(loc,1);
                stockYOperate = obj.holdingPairStruct.stockYOperate(loc,1);
                adjPosition(1,stockYLoc) = adjPosition(1,stockYLoc)+(stockYPosition*stockYOperate);
                stockXLoc = obj.holdingPairStruct.stockXLoc(loc,1);
                stockXPosition = obj.holdingPairStruct.stockXPosition(loc,1);
                stockXOperate = obj.holdingPairStruct.stockXOperate(loc,1);
                adjPosition(1,stockXLoc) = adjPosition(1,stockXLoc)+(stockXPosition*stockXOperate);
            end
            obj.holdingStruct.position(obj.currDateLoc,:) = adjPosition;
            LongCodes = [LongCodes,tickerName(adjPosition>0)];
            LongPosition = [LongPosition,adjPosition(adjPosition>0)];
            ShortCodes = [ShortCodes,tickerName(adjPosition<0)];
            ShortPosition = [ShortPosition,abs(adjPosition(adjPosition<0))];
        end
        
       
    end
    
end