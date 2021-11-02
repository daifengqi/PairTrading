marketData = mclasses.staticMarketData.BasicMarketLoader.getInstance();
generalData = marketData.getAggregatedDataStruct;
generalData.stock
generalData.stock.sectorClassification

generalData
generalData.sectorLevelOne
generalData.sectorLevelOne.sectorFullNames

generalData.sectorLevelOne
generalData.sectorLevelOne.sectorFullNames
generalData.stock.sectorClassification
financeSectorFilter = generalData.stock.sectorClassification.levelOne == 32;
figure; plot(sum(financeSectorFilter, 2));
financeSectorFilter = generalData.stock.sectorClassification.levelOne == 31;
figure; plot(sum(financeSectorFilter, 2));
financeSectorFilter = generalData.stock.sectorClassification.levelOne == 19;
figure; plot(sum(financeSectorFilter, 2));

generalData.stock.description.tickers.shortName(financeSectorFilter(1,:))
generalData.stock.description.tickers.shortName(financeSectorFilter(end,:))
generalData.stock.description.tickers.shortName(financeSectorFilter(end-1,:))

financeSectorFilter = generalData.stock.sectorClassification.levelOne == 32;
generalData.stock.description.tickers.shortName(financeSectorFilter(end,:))
generalData.stock.description.tickers.shortName(financeSectorFilter(1,:))

financeSectorFilter = generalData.stock.sectorClassification.levelOne == 31;
generalData.stock.description.tickers.shortName(financeSectorFilter(1,:))
generalData.stock.description.tickers.shortName(financeSectorFilter(end,:))

%% add test
% sanity check
financeSectorFilter = generalData.stock.sectorClassification.levelOne == 31;
currentResult = generalData.stock.description.tickers.shortName(financeSectorFilter(2210,:));
expectedResult = { 'ƽ������'
    '��������'
    '�ַ�����'
    '��������'
    '��������'
    '��������'
    '�Ͼ�����'
    '��ҵ����'
    '��������'
    'ũҵ����'
    '��ͨ����'
    '��������'
    '�������'
    '��������'
    '�й�����'
    '��������'
    '��������'
    '��������'
    '��������'
    '��������'
    '��������'
    '��������'
    '�Ϻ�����'
    '��ũ����'
    '�żҸ���'
    '�ɶ�����'
    '֣������'
    '��ɳ����'
    '�ൺ����'
    '��������'
    '�Ͻ�����'
    '��ũ����'
    '��������'
    '��ũ����'
    '��������'
    '�ʴ�����'};
assert(isequal(currentResult, expectedResult), 'pairTrading::stock selection::data mismatch');

%% correlation check
bankStockLocation = find(sum(financeSectorFilter) > 1);
generalData.stock.description.tickers.shortName(bankStockLocation)
bankFowardPrices = generalData.stock.properties.fwd_close(:, bankStockLocation);

corr(bankFowardPrices)
validStartingPoint = max(sum(isnan(bankFowardPrices)))+3;
bankCorrelationMatrix = corr(bankFowardPrices(validStartingPoint:end, :));

min(bankCorrelationMatrix)
min(min(bankCorrelationMatrix))

figure; plot(sort(bankCorrelationMatrix));
figure; plot(sort(bankCorrelationMatrix(:)));

%% forward adjusted prices vs close prices
bankClosePrices = generalData.stock.properties.close(:, bankStockLocation);
figure; plot(bankClosePrices);
figure; plot(bankFowardPrices);



