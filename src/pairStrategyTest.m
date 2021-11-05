classdef pairStrategyTest<mclasses.strategy.LFBaseStrategy
    
    properties(GetAccess = public, SetAccess = public)
        divideShare%在strategyTest中用initialize中初始化为空
        stockUniverse%在strategyTest中用initialize中初始化为空
        %stockUniverse表示现在的持仓情况
        %通过持仓部分的正负号判断做空还是做多
        signalPool%在strategyTest中用initialize中初始化为空
        %缓冲池，自行设定多长
        structarray%在strategyTest中用initialize中初始化为空
        %累积量，记录从startDate到endDate股票交易详情
        listname
        codes
        signal
        LongPosition
        ShortPosition
        LongCodes
        ShortCodes
        currDate%这里的currDate是7打头的六位数字
        changeRate
    end
    
     methods
%% setOrder函数，用于开仓
%计算pairs两个股分别购买多少手时，再考虑一下beta如何处理
        function setOrder(obj,Capital,Filter,numPairAvail)
%             numPairAvail=sum(cellfun(@isempty,obj.stockUniverse(1,:)));
%             if numPairAvail ==0
%                 obj.adjustOrder(Capital,Filter);
%             end
            %挑选出zscore达到+-2σ的pairs并保存起来
            alterAmount=30;
            %备选股票对数，在判断是否超过+-2σ时使用
            electivepairs = cell(4,alterAmount);%30是我默认一共挑出来不超过30对,后面还用到了一次
            p = 1;
            for i = 1:length(obj.listname)
                for j = 1:length(obj.listname)
                    if isempty(obj.signal{i,j})==0%validity要么不存在，要么为1
                        %-1代表需要做空，1代表需要做多
                        if obj.signal{i,j}.entryPointBounry == -1 
                            %这里也可以用zscores判断,但property里面的zscore是个序列
                            electivepairs{2,p}= -1;
                            electivepairs{1,p}= [i,j];
                            electivepairs{3,p}= obj.signal{i,j}.expectedReturn;
                            electivepairs{4,p}= obj.signal{i,j}.beta;
                        elseif obj.signal{i,j}.entryPointBounry == 1
                            electivepairs{2,p}= 1;
                            electivepairs{1,p}= [i,j];
                            electivepairs{3,p}= obj.signal{i,j}.expectedReturn;
                            electivepairs{4,p}= obj.signal{i,j}.beta;
                        else
                            electivepairs{2,p}= 0;
                            electivepairs{1,p}= [i,j];
                            electivepairs{3,p}= obj.signal{i,j}.expectedreturn;
                            electivepairs{4,p}= obj.signal{i,j}.beta;
                        end
                        p=p+1;
                    end
                end
            end
            %在zscore超过+-2σ的情况下按照ER进行排序
            [~,ind] = sort(cell2mat(electivepairs(3,:)),'descend');
            electivepairs=electivepairs(:,ind);
            marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
            aggregatedDataStruct = marketData.getAggregatedDataStruct;
            [~, dateLoc] = ismember(todatenum(cdfepoch(obj.currDate)), aggregatedDataStruct.sharedInformation.allDates);
            
            %按照空余pairs个数寻找ER最高的pairs，计算pairs每手的价格，得到交易量
            q=1;
            for i =1:size(electivepairs,2)
                if electivepairs{2,i}==0
                    continue
                end
                stock_1=obj.listname(electivepairs{1,i}(1));
                stock_2=obj.listname(electivepairs{1,i}(2));%默认signal类中name变量是按照顺序给的个股名称
                stock1Loc = find(ismember(aggregatedDataStruct.stock.description.tickers.shortName,stock_1));
                stock2Loc = find(ismember(aggregatedDataStruct.stock.description.tickers.shortName,stock_2));
                stock1Code = aggregatedDataStruct.stock.description.tickers.windTicker(stock1Loc);
                stock2Code = aggregatedDataStruct.stock.description.tickers.windTicker(stock2Loc);
                selectedPrices1 = aggregatedDataStruct.stock.properties.(obj.orderPriceType)(dateLoc, stock1Loc);
                selectedPrices2 = aggregatedDataStruct.stock.properties.(obj.orderPriceType)(dateLoc, stock2Loc);
                if Filter(stock1Loc)==0
                    continue
                end
                if Filter(stock2Loc)==0
                    continue
                end    
                perCapital=Capital/numPairAvail;
                %为保证整手交易，smooth_beta取两位小数，这样可能会影响交易的精确性
                pairPrices = selectedPrices1*abs(double(vpa(electivepairs{4,i},2)))+selectedPrices2;
                targetPosition = floor(perCapital*0.85 /pairPrices /100)*100;
                nextDate=dateLoc+1;
                %突破上界2σ，做空该组合
                if electivepairs{2,i}==-1
                    obj.ShortCodes=[obj.ShortCodes;stock2Code];
                    obj.ShortPosition = [obj.ShortPosition,targetPosition];
                    stock2OpenPrice=aggregatedDataStruct.stock.properties.open(nextDate,stock2Loc);
                    obj.stockUniverse{2,obj.divideShare-numPairAvail+q}={stock_2,stock2Code,(-1)*targetPosition,stock2OpenPrice};
                    %β<0，同时做空，β>0，long stock1 short stock2
                    if electivepairs{4,i}<0
                        obj.ShortCodes=[obj.ShortCodes;stock1Code];
                        obj.ShortPosition=[obj.ShortPosition,targetPosition*abs(vpa(electivepairs{4,i},2))];
                        %obj.ShortList = [obj.ShortList;{stock_1,targetPosition*vpa(electivepairs{4,i},2)}];
                    else
                        obj.LongCodes=[obj.LongCodes;stock1Code];
                        obj.LongPosition=[obj.LongPosition,targetPosition*abs(vpa(electivepairs{4,i},2))];
                        %obj.LongList = [obj.ShortList;{stock_1,targetPosition*vpa(electivepairs{4,i},2)}];
                    end
                    stock1OpenPrice=aggregatedDataStruct.stock.properties.open(nextDate,stock1Loc);
                    obj.stockUniverse{1,obj.divideShare-numPairAvail+q}={stock_1,stock1Code,targetPosition*double(vpa(electivepairs{4,i},2)),stock1OpenPrice};
                
                %突破下界-2σ，做多该组合
                elseif electivepairs{2,i}==1
                    obj.LongCodes=[obj.LongCodes;stock2Code];
                    obj.LongPosition = [obj.LongPosition,targetPosition];
                    stock2OpenPrice=aggregatedDataStruct.stock.properties.open(nextDate,stock2Loc);
                    obj.stockUniverse{2,obj.divideShare-numPairAvail+q}={stock_2,stock2Code,targetPosition,stock2OpenPrice};
                    %β<0，同时做多，β>0，short stock1 long stock2
                    if electivepairs{4,i}<0
                        obj.LongCodes=[obj.LongCodes;stock1Code];
                        obj.LongPosition = [obj.LongPosition,targetPosition*abs(vpa(electivepairs{4,i},2))];
                        %obj.LongList = [obj.ShortList;{stock_1,targetPosition*vpa(electivepairs{4,i},2)}];
                    else
                        obj.ShortCodes=[obj.ShortCodes;stock1Code];
                        obj.ShortPosition = [obj.ShortPosition,targetPosition*abs(vpa(electivepairs{4,i},2))];
                        %obj.ShortList = [obj.ShortList;{stock_1,targetPosition*vpa(electivepairs{4,i},2)}];
                    end
                    stock1OpenPrice=aggregatedDataStruct.stock.properties.open(nextDate,stock1Loc);
                    obj.stockUniverse{1,obj.divideShare-numPairAvail+q}={stock_1,stock1Code,targetPosition*double(vpa(electivepairs{4,i},2)),stock1OpenPrice};
                end
                obj.stockUniverse{3,obj.divideShare-numPairAvail+q}=obj.signal{electivepairs{1,i}(1),electivepairs{1,i}(2)};

                if q ==  numPairAvail
                    break
                end 
                q=q+1;
            end
            
        end
%% adjustOrder函数，用于换仓
%换仓的条件是满仓，且signal中的pairs的ER最大值是stockUniverse中的pairs的ER最小值的changeRate倍
%默认换仓一天只能换一对pairs
        function adjustOrder(obj,Capital,Filter)
            [~,ind] = sort(cell2mat(obj.stockUniverse{3,:}.expectedreturn));
            leastER=obj.stockUniverse{:,ind(1)}.expectedreturn;
            largeER=obj.changeRate*leaseER
            changePairs=[0,0]
            changesignal=0;
            for i = size(obj.signal,1)
                for j = size(obj.signal,2)
                    if obj.signal{i,j}.expectedreturn>largeER
                        if obj.signal{i,j}.entryPointBounry==1||obj.signal{i,j}.entryPointBounry==-1
                            changeSignal=1;
                        end
                    end
                end
            end
            if changeSignal == 0
                disp('No order need to change today.');
            else
            %先平仓
                if obj.stockUniverse{1,ind(1)}{1,2}>0
                    obj.ShortCodes=[obj.ShortCodes,obj.stockUniverse{1,ind(1)}{1,2}];
                    obj.ShortPosition = [obj.ShortPosition,0];
                else
                    obj.LoneCodes=[obj.ShortCodes,obj.stockUniverse{1,ind(1)}{1,2}];
                    obj.LongPosition = [obj.ShortPosition,0];
                end
                if obj.stockUniverse{2,ind(1)}{1,2}>0
                    obj.ShortCodes=[obj.ShortCodes,obj.stockUniverse{2,ind(1)}{1,2}];
                    obj.ShortPosition = [obj.ShortPosition,0];
                else
                    obj.LoneCodes=[obj.ShortCodes,obj.stockUniverse{2,ind(1)}{1,2}];
                    obj.LongPosition = [obj.ShortPosition,0];
                end
            %后开仓
                obj.setOrder(obj,Capital,Filter,1);
            end
        end
    end
end