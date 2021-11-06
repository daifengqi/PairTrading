signal = pairTradingSignal();
signal.calSignals();


% propertyNames = {'validity','zScore','dislocation','expectedReturn',...
%            'halfLife','entryPointBoundry','alpha','beta'};
% numOfDate = 250;
% numOfStock = 50;
% for i = 1:size(propertyNames,2)
%     signalSample.(propertyNames{1,i})=zeros(numOfDate,numOfStock,numOfStock);
% end
% signalSample.validity(:,1:25,36:40) = 1;
% signalSample.zScore(1:50,1:25,36:38) = 2;
% signalSample.zScore(50:250,1:25,36:38) = 2.5;
% signalSample.zScore(1:50,1:25,39:40) = 1;
% signalSample.zScore(50:250,1:25,39:40) = 3;
% 
% signalSample.dislocation(1:50,1:25,36:38) = 10;
% signalSample.dislocation(50:250,1:25,36:38) = 15;
% signalSample.dislocation(1:50,1:25,39:40) = 5;
% signalSample.dislocation(50:250,1:25,39:40) = 25;
% 
% signalSample.expectedReturn(1:50,1:25,36:38) = 1;
% signalSample.expectedReturn(50:250,1:25,36:38) = 5;
% signalSample.expectedReturn(1:50,1:25,39:40) = 2;
% signalSample.expectedReturn(50:250,1:25,39:40) = 1;
% 
% signalSample.halfLife(1:50,1:25,36:38) = 10;
% signalSample.halfLife(50:250,1:25,36:38) = 5;
% signalSample.halfLife(1:50,1:25,39:40) = 6;
% signalSample.halfLife(50:250,1:25,39:40) = 40;
% 
% signalSample.entryPointBoundry(:,:,:) = 1.96;

% for dateLoc = 1:numOfDate
%     for stockYLoc = 1:numOfStock-1
%         for stockXLoc = stockYLoc+1 : numOfStock
%             signalSample.validity
% 
% 
