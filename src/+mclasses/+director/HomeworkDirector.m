classdef HomeworkDirector < mclasses.director.HFDirector
    
    properties (GetAccess = public, SetAccess = private)
    end
    
    methods (Access = public)
        
        function obj = HomeworkDirector(container, name)
            obj@mclasses.director.HFDirector(container, name);
        end
        
        function run(obj)
            % Follow the sequence diagram for director discussed class
            % lectures, leverge the UML diagrams of both director and
            % strategy classes, finish the run method definition, such that
            % the given LongOnly strategy can be successfully executed.

            currentDate = obj.calculateStartDate();
            allDates = obj.marketData.getAggregatedDataStruct().sharedInformation.allDates;
            endDate = obj.endDate;

            while currentDate < endDate
                if ismember(currentDate, allDates)
                    obj.beforeMarketOpen(currentDate);
                    obj.recordDailyPnlBOD(currentDate);
                    obj.executeOrder(currentDate);
                    obj.afterMarketClose(currentDate);
                    obj.recordDailyPnl(currentDate);
                    obj.examCash(currentDate);
                    obj.allocatorRebalance(currentDate);
                    obj.updateLFStrategy(currentDate);
                end
                currentDate = currentDate + 1;
            end

        end
    end
end
