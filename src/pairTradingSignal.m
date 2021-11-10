classdef PairTradingSignal < handle
   properties
       startDateStr;
       endDateStr;
       wr = 40;
       ws = 20;
       validRatio = 0.8;
       entryPointBoundaryDefault = 1.8;
       startDate;
       startDateLoc;
       endDate;
       endDateLoc;
       sharedInformation;
       stockUniverse;
       signals;
       calSignalTmp;
   end
    
   methods
       function obj = PairTradingSignal(startDateStr,endDateStr,sectorNum)
           obj.endDateStr=endDateStr;
           obj.startDateStr=startDateStr;
           % TODO: pass args via config file
           % marketData
           marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
           generalData = marketData.getAggregatedDataStruct;
           allDates = generalData.sharedInformation.allDates;
           allDateStr = generalData.sharedInformation.allDateStr;
           fwd_close = generalData.stock.properties.fwd_close;
           windTicker = generalData.stock.description.tickers.windTicker;
           shortName = generalData.stock.description.tickers.shortName;
           % get date list
           startDate = datenum(obj.startDateStr,'yyyymmdd');
           endDate = datenum(obj.endDateStr,'yyyymmdd');
           tmp = find(allDates>=startDate);
           startDateLoc = tmp(1);
           obj.startDateLoc =startDateLoc;
           obj.startDate = allDates(startDateLoc);
           tmp = find(allDates<=endDate);
           endDateLoc = tmp(end);
           obj.endDateLoc = endDateLoc;
           obj.endDate = allDates(endDateLoc);
           loadPriceStartDateLoc = startDateLoc-obj.wr-obj.ws;
           obj.sharedInformation.dateList = allDates(loadPriceStartDateLoc:endDateLoc);
           obj.sharedInformation.dateStrList = allDateStr(loadPriceStartDateLoc:endDateLoc,:);
           obj.sharedInformation.numOfDate = length(obj.sharedInformation.dateList);
           % init universe 化工 简单起见，先选20个
           financeSectorFilter = generalData.stock.sectorClassification.levelOne == sectorNum;
           stockLocation = find(sum(financeSectorFilter) > 1);
           stockLocation = stockLocation(1:20);
           stockST = generalData.stock.stTable;
           stockST = stockST(loadPriceStartDateLoc:endDateLoc,stockLocation);
           stockTradeDay = generalData.stock.tradeDayTable;
           stockTradeDay = stockTradeDay(loadPriceStartDateLoc:endDateLoc,stockLocation);
           obj.stockUniverse.stockFilter = (~stockST)&stockTradeDay;
           obj.stockUniverse.stockLocList = stockLocation;
           obj.stockUniverse.windTicker = windTicker(stockLocation,:);
           obj.stockUniverse.shortName = shortName(stockLocation,:);
           obj.stockUniverse.numOfStock = length(stockLocation);
           obj.stockUniverse.fwd_close = fwd_close(loadPriceStartDateLoc:endDateLoc,stockLocation);
           % init signals=(date,stockY,stockX,properties)
           obj.sharedInformation.propertyNames = {'validity','validForSmooth','dislocation','expectedReturn',...
           'halfLife','entryPointBoundary','beta','sBeta','zScoreSe'};
           for i = 1:size(obj.sharedInformation.propertyNames,2)-1
               obj.signals.(obj.sharedInformation.propertyNames{1,i}) = zeros(obj.sharedInformation.numOfDate,...
                   obj.stockUniverse.numOfStock,obj.stockUniverse.numOfStock);
           end
           % store the zScore series for plot,
           % zScore(end-1)<entryPointBounddary<zScore(end)--> short
           obj.signals.zScoreSe = zeros(obj.sharedInformation.numOfDate,...
                   obj.stockUniverse.numOfStock,obj.stockUniverse.numOfStock,obj.wr);
           
       end
       
       function obj=calSignals(obj)
           fprintf('calculating signals')
           for currDateLoc = obj.wr:obj.sharedInformation.numOfDate
               for stockYLoc = 1:(obj.stockUniverse.numOfStock-1)
                   if ~obj.stockUniverse.stockFilter(currDateLoc,stockYLoc)
                       continue
                   end
                   for stockXLoc = (stockYLoc+1):obj.stockUniverse.numOfStock
                       if ~obj.stockUniverse.stockFilter(currDateLoc,stockXLoc)
                           continue
                       end
                       obj.calSignal(currDateLoc,stockYLoc,stockXLoc);
                   end
               end
           end
           fprintf('signals calculated')
       end
       
       function obj=calSignal(obj,currDateLoc,stockYLoc,stockXLoc)
           % 每一步都有需要检验并更改validity的部分
           obj.calSignalTmp.currDateLoc = currDateLoc;
           obj.calSignalTmp.stockYLoc = stockYLoc;
           obj.calSignalTmp.stockXLoc = stockXLoc;
           % step1: get price series and process them --> mean=1 (TODO in proj)
           [priceY, priceProcessedY] = obj.loadPrice(stockYLoc);
           [priceX, priceProcessedX] = obj.loadPrice(stockXLoc);
           obj.calSignalTmp.priceY = priceY;
           obj.calSignalTmp.priceX = priceX;
           % step2: test the co-intergration between Y and X,
           % update obj.signals(4).validity
           % if valid, update obj.signals(4).beta & alpha
           validity = obj.testCointegration(priceY,priceX);
           if (validity == 0)
               return
           end
           if (currDateLoc<obj.ws+obj.wr)
               obj.signals.validForSmooth(currDateLoc,stockYLoc,stockXLoc) = 1;
               return
           end
           % step3: smooth beta, first select valid dates in
           % [currDate-obj.ws+1,currDate], then get the mean(beta_se)
           [validity,sBeta] = obj.smoothBeta();
           if validity == 0
               return
           end
           obj.signals.sBeta(currDateLoc,stockYLoc,stockXLoc) = sBeta;
           % step4: use smoothed beta to calResidual
           residualSe = obj.calResidual(sBeta,priceY,priceX);
           % step5: analyze residual & update zScore,halfLife, use OUTest
           % inside this function
           validity = obj.analyzeResidual(residualSe);
           obj.signals.validity(currDateLoc,stockYLoc,stockXLoc) = validity;
       end
       
       % 获取历史价格数据，并demean
       function [price,priceProcessed] = loadPrice(obj,stockLoc)
           price = obj.stockUniverse.fwd_close(obj.calSignalTmp.currDateLoc-obj.wr+1:obj.calSignalTmp.currDateLoc,stockLoc);
           priceProcessed = obj.processPrice(price);
       end
       
       
       
       % 对于Y和X的价格序列进行协整检验（是否需要和t做回归，且保留t的系数？alpha2）
       function validity = testCointegration(obj,priceY,priceX)
           % FIXME: 是否需要residual alpha1 2???
           if sum(isnan(priceY))>0 || sum(isnan(priceX))>0
               validity = 0;
               return
           end
           t = (linspace(1,obj.wr,obj.wr))';
           X = [ones(obj.wr,1) t priceX];
           [b,bint,residualSe] = regress(priceY,X);
           alpha1 = b(1);
           beta = b(3);
           % 进行残差的单位根检验（ADFtest）
           % 返回值为1，则拒绝原假设（a unit root is present in a time series sample）
           % 说明没有单位根--平稳的
           validity = adftest(residualSe);
           if validity == 0
               return
           end
           % TODO:
           % 判断是否和时间有关，系数是0或者1，为什么不是-1？？？
           if bint(2,1) < 0 && bint(2,2) > 0 
               alpha2 = 0;
           else
               alpha2 = 1;
           end
           obj.signals.beta(obj.calSignalTmp.currDateLoc,obj.calSignalTmp.stockYLoc,obj.calSignalTmp.stockXLoc) = beta;
           obj.signals.validForSmooth(obj.calSignalTmp.currDateLoc,obj.calSignalTmp.stockYLoc,obj.calSignalTmp.stockXLoc) = beta;
       end
       
       % 对于beta做平滑
       function [validity,sBeta] = smoothBeta(obj)
           betaSeries = obj.signals.beta(obj.calSignalTmp.currDateLoc-obj.ws+1:obj.calSignalTmp.currDateLoc,...
               obj.calSignalTmp.stockYLoc,obj.calSignalTmp.stockXLoc);
           validForSmoothSe = obj.signals.validForSmooth(obj.calSignalTmp.currDateLoc-obj.ws+1:obj.calSignalTmp.currDateLoc,...
               obj.calSignalTmp.stockYLoc,obj.calSignalTmp.stockXLoc);
           if mean(validForSmoothSe)<obj.validRatio
               validity = 0;
               sBeta = NaN;
               return
           end
           sBeta = mean(betaSeries(logical(validForSmoothSe)));
           obj.calSignalTmp.sBeta = sBeta;
           validity = 1;
       end
       
       % 分析残差序列从而得到dislocation,zScore(长度为obj.wr),entryPointBoundary(事先设定好的)
       % expectedReturn,halfLife
       function validity = analyzeResidual(obj,residualSe)
%            validity = adftest(residualSe);
           [notStationary,pValue,stat,cValue,reg] = adftest(residualSe);
           validity = ~notStationary;
           if validity == 0
               return
           end
           obj.signals.entryPointBoundary(obj.calSignalTmp.currDateLoc,obj.calSignalTmp.stockYLoc,obj.calSignalTmp.stockXLoc)=obj.entryPointBoundaryDefault;
           % Question!!! TODO
           % dislocation是没有zScore的residualSe(end)???
           % ER到底怎么算？halfLife = log(2)/lambda,其实只要所有pairs的计算方式一样，都是差一个常数C而已
           % ½*dislocation/half life normalized to monthly or yearly return
           % 不考虑capital吗？？？
           [mu,sigma,lambda] = obj.OU_Calibrate_LS(residualSe,1);
           zScoreSe = (residualSe-mu)/sigma;
           dislocation = residualSe(end);
           capital = obj.calSignalTmp.priceY(end) + abs(obj.calSignalTmp.sBeta)*obj.calSignalTmp.priceX(end);
           halfLife = log(2)/lambda;
           expectedReturn = (dislocation/2*250)/(capital*halfLife);
           obj.signals.dislocation(obj.calSignalTmp.currDateLoc,obj.calSignalTmp.stockYLoc,obj.calSignalTmp.stockXLoc)=dislocation;
           obj.signals.zScoreSe(obj.calSignalTmp.currDateLoc,obj.calSignalTmp.stockYLoc,obj.calSignalTmp.stockXLoc,:)=zScoreSe;
           obj.signals.halfLife(obj.calSignalTmp.currDateLoc,obj.calSignalTmp.stockYLoc,obj.calSignalTmp.stockXLoc)=halfLife;
           obj.signals.expectedReturn(obj.calSignalTmp.currDateLoc,obj.calSignalTmp.stockYLoc,obj.calSignalTmp.stockXLoc)=expectedReturn;
           validity = 1;
       end
       
       % 方便直接通过loc的信息print出来对应的日期，pairs
       function [dateStr,stockYName,stockXName] = getEntry(obj,dateLoc,YLoc,XLoc)
           dateStr = obj.sharedInformation.dateStrList(dateLoc,:);
           stockYName = obj.stockUniverse.shortName(YLoc);
           stockXName = obj.stockUniverse.shortName(XLoc);
       end
       
   end
   
   methods(Static)
       % demean操作
       function priceProcessed = processPrice(price)
            priceMean = mean(price);
            priceProcessed = price/priceMean;
            % TODO in proj
            priceProcessed = price;
       end
       % 利用平滑后的beta计算残差序列
       function residualSe = calResidual(sBeta,priceY,priceX)
           residualSe = priceY - priceX*sBeta;
       end
       % OU process 计算 mu,sigma,lambda
       % lambda：回复的速率，越大说明halfLife越短
       function [mu,sigma,lambda] = OU_Calibrate_LS(S,delta)
            n = length(S)-1;
            Sx  = sum( S(1:end-1) );
            Sy  = sum( S(2:end) );
            Sxx = sum( S(1:end-1).^2 );
            Sxy = sum( S(1:end-1).*S(2:end) );
            Syy = sum( S(2:end).^2 );
            a  = ( n*Sxy - Sx*Sy ) / ( n*Sxx -Sx^2 );
            b  = ( Sy - a*Sx ) / n;
            sd = sqrt( (n*Syy - Sy^2 - a*(n*Sxy - Sx*Sy) )/n/(n-2) );
            lambda = -log(a)/delta;
            mu     = b/(1-a);
            sigma  =  sd * sqrt( -2*log(a)/delta/(1-a^2) );
       end
   end
   
   
end