classdef pairTradingSignal < handle
   properties
       startDateStr = '20180409';
       endDateStr = '20190409';
       sharedInformation;
       numOfDate;
       dateList;
       wr = 20;
       ws = 15;
       nSigma = 1;
       startDate;
       endDate;
       stockUniverse;
       signals;
       calSignalTmp;
   end
    
   methods
       function obj = pairTradingSignal()
           % marketData
           marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
           generalData = marketData.getAggregatedDataStruct;
           allDates = generalData.sharedInformation.allDates;
           fwd_close = generalData.stock.properties.fwd_close;
           windTicker = generalData.stock.description.tickers.windTicker;
           % get date list
           startDate = datenum(obj.startDateStr,'yyyymmdd');
           endDate = datenum(obj.endDateStr,'yyyymmdd');
           tmp = find(allDates>=startDate);
           startDateLoc = tmp(1);
           tmp = find(allDates<=endDate);
           endDateLoc = tmp(end);
           loadPriceStartDateLoc = startDateLoc-obj.wr-obj.ws;
           obj.sharedInformation.dateList = allDates(loadPriceStartDateLoc:endDateLoc);
           obj.sharedInformation.numOfDate = length(obj.sharedInformation.dateList);
           % init universe 化工 简单起见，先选50个
           financeSectorFilter = generalData.stock.sectorClassification.levelOne == 3;
           stockLocation = find(sum(financeSectorFilter) > 1);
           stockLocation = stockLocation(1:50);
           obj.stockUniverse.windTicker = windTicker(stockLocation,:);
           obj.stockUniverse.numOfStock = length(stockLocation);
           obj.stockUniverse.fwd_close = fwd_close(loadPriceStartDateLoc:endDateLoc,stockLocation);
           % init signals=(date,stockY,stockX,properties)
           obj.sharedInformation.propertyNames = {'validity','zScore','dislocation','expectedReturn',...
           'halfLife','sigma','alpha','beta','open'};
           for i = 1:size(obj.sharedInformation.propertyNames,2)
               obj.signals.(obj.sharedInformation.propertyNames{1,i})=zeros(obj.sharedInformation.numOfDate,obj.stockUniverse.numOfStock,obj.stockUniverse.numOfStock);
           end
          
           
       end
       
       function obj=calSignals(obj)
           for currDateLoc = obj.wr:obj.sharedInformation.numOfDate
               for stockYLoc = 1:(obj.stockUniverse.numOfStock-1)
                   for stockXLoc = (stockYLoc+1):obj.stockUniverse.numOfStock
                       obj.calSignal(currDateLoc,stockYLoc,stockXLoc);
                   end
               end
           end
       end
       
       function obj=calSignal(obj,currDateLoc,stockYLoc,stockXLoc)
           obj.calSignalTmp.currDateLoc = currDateLoc;
           obj.calSignalTmp.stockYLoc = stockYLoc;
           obj.calSignalTmp.stockXLoc = stockXLoc;
           % step1: get price series and process them --> mean=1 (TODO in proj)
           [priceY, priceProcessedY] = obj.loadPrice(stockYLoc);
           [priceX, priceProcessedX] = obj.loadPrice(stockXLoc);
           % step2: test the co-intergration between Y and X,
           % update obj.signals(4).validty
           % if valid, update obj.signals(4).beta & alpha
           validty = obj.testCointegration(priceY,priceX);
           if validty == 0
               return
           end
           % step3: smooth beta, first select valid dates in
           % [currDate-obj.ws+1,currDate], then get the mean(beta_se)
           sBeta = obj.smoothBeta(0.6);
           % step4: use smoothed beta to calResidual
           residualSe = obj.calResidual(sBeta,priceY,priceX);
           % step5: analyze residual & update zScore,halfLife, use OUTest
           % inside this function
           obj.analyzeResidual(residualSe);
       end
       
       function [price,priceProcessed] = loadPrice(stockLoc)
           price = obj.stockUniverse.fwd_close(obj.calSignalTmp.currDateLoc-obj.wr+1:obj.currDateLoc,stockLoc);
           priceProcessed = obj.processPrice(price);
       end
       
       function priceProcessed = processPrice(obj,price)
            priceMean = mean(price);
            priceProcessed = price/priceMean;
            % TODO in proj
            priceProcessed = price;
       end
       
       function validty = testCointegration(obj,priceY,priceX)
           if sum(isnan(priceY))>0 || sum(isnan(priceX))>0
               obj.signals.validty(obj.calSignalTmp.currDate,obj.calSignalTmp.stockYLoc,obj.calSignalTmp.stockXLoc)=0;
               validty = 0;
               return
           end
           
       end
       
       function sBeta = smoothBeta(obj,minRatio)
           
       end
       
       function residualSe = calResidual(obj,sBeta,priceY,priceX)
       end
   end
   
   
end