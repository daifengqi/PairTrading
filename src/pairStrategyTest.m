classdef pairStrategyTest<mclasses.strategy.LFBaseStrategy
    
    properties(GetAccess = public, SetAccess = public)
        divideShare%��strategyTest����initialize�г�ʼ��Ϊ��
        stockUniverse%��strategyTest����initialize�г�ʼ��Ϊ��
        %stockUniverse��ʾ���ڵĳֲ����
        %ͨ���ֲֲ��ֵ��������ж����ջ�������
        signalPool%��strategyTest����initialize�г�ʼ��Ϊ��
        %����أ������趨�೤
        structarray%��strategyTest����initialize�г�ʼ��Ϊ��
        %�ۻ�������¼��startDate��endDate��Ʊ��������
        listname
        codes
        signal
        LongPosition
        ShortPosition
        LongCodes
        ShortCodes
        currDate%�����currDate��7��ͷ����λ����
        changeRate
    end
    
     methods
%% setOrder���������ڿ���
%����pairs�����ɷֱ��������ʱ���ٿ���һ��beta��δ���
        function setOrder(obj,Capital,Filter,numPairAvail)
%             numPairAvail=sum(cellfun(@isempty,obj.stockUniverse(1,:)));
%             if numPairAvail ==0
%                 obj.adjustOrder(Capital,Filter);
%             end
            %��ѡ��zscore�ﵽ+-2�ҵ�pairs����������
            alterAmount=30;
            %��ѡ��Ʊ���������ж��Ƿ񳬹�+-2��ʱʹ��
            electivepairs = cell(4,alterAmount);%30����Ĭ��һ��������������30��,���滹�õ���һ��
            p = 1;
            for i = 1:length(obj.listname)
                for j = 1:length(obj.listname)
                    if isempty(obj.signal{i,j})==0%validityҪô�����ڣ�ҪôΪ1
                        %-1������Ҫ���գ�1������Ҫ����
                        if obj.signal{i,j}.entryPointBounry == -1 
                            %����Ҳ������zscores�ж�,��property�����zscore�Ǹ�����
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
            %��zscore����+-2�ҵ�����°���ER��������
            [~,ind] = sort(cell2mat(electivepairs(3,:)),'descend');
            electivepairs=electivepairs(:,ind);
            marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
            aggregatedDataStruct = marketData.getAggregatedDataStruct;
            [~, dateLoc] = ismember(todatenum(cdfepoch(obj.currDate)), aggregatedDataStruct.sharedInformation.allDates);
            
            %���տ���pairs����Ѱ��ER��ߵ�pairs������pairsÿ�ֵļ۸񣬵õ�������
            q=1;
            for i =1:size(electivepairs,2)
                if electivepairs{2,i}==0
                    continue
                end
                stock_1=obj.listname(electivepairs{1,i}(1));
                stock_2=obj.listname(electivepairs{1,i}(2));%Ĭ��signal����name�����ǰ���˳����ĸ�������
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
                %Ϊ��֤���ֽ��ף�smooth_betaȡ��λС�����������ܻ�Ӱ�콻�׵ľ�ȷ��
                pairPrices = selectedPrices1*abs(double(vpa(electivepairs{4,i},2)))+selectedPrices2;
                targetPosition = floor(perCapital*0.85 /pairPrices /100)*100;
                nextDate=dateLoc+1;
                %ͻ���Ͻ�2�ң����ո����
                if electivepairs{2,i}==-1
                    obj.ShortCodes=[obj.ShortCodes;stock2Code];
                    obj.ShortPosition = [obj.ShortPosition,targetPosition];
                    stock2OpenPrice=aggregatedDataStruct.stock.properties.open(nextDate,stock2Loc);
                    obj.stockUniverse{2,obj.divideShare-numPairAvail+q}={stock_2,stock2Code,(-1)*targetPosition,stock2OpenPrice};
                    %��<0��ͬʱ���գ���>0��long stock1 short stock2
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
                
                %ͻ���½�-2�ң���������
                elseif electivepairs{2,i}==1
                    obj.LongCodes=[obj.LongCodes;stock2Code];
                    obj.LongPosition = [obj.LongPosition,targetPosition];
                    stock2OpenPrice=aggregatedDataStruct.stock.properties.open(nextDate,stock2Loc);
                    obj.stockUniverse{2,obj.divideShare-numPairAvail+q}={stock_2,stock2Code,targetPosition,stock2OpenPrice};
                    %��<0��ͬʱ���࣬��>0��short stock1 long stock2
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
%% adjustOrder���������ڻ���
%���ֵ����������֣���signal�е�pairs��ER���ֵ��stockUniverse�е�pairs��ER��Сֵ��changeRate��
%Ĭ�ϻ���һ��ֻ�ܻ�һ��pairs
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
            %��ƽ��
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
            %�󿪲�
                obj.setOrder(obj,Capital,Filter,1);
            end
        end
    end
end