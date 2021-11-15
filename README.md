# PairTrading
MATLAB codes for  pair trading strategy.

## pairTradingSignal

### input

### output

`obj.signals` (see `signalSample` in `testSignalYMJ.m` )

a structure in Matlab which contains the following matrix 

`shape=(numOfDate,numOfStock,numOfStock)`

- `validity`: **if 1, we will consider this pair on this date**
  - `signalSample.validity(10,12,15)` is 1 means: on date 10, we consider the stock pair (stock12,stock15) when `generateOrders`
- `zScore`: see slide, z-Score value of residual, compared it with the `entryPointBoundry`,**need to consider when you construct your strategy**
- `dislocation`: see slide, the true gap between the residual and mean, **need to consider when you calculate your pnl**
- `expectedReturn`: see slide, calculate from OU process, **need to consider when you construct your strategy**
- `halfLife`: see slide, calculate from OU process, used for calculating `expectedReturn`
- `entryPointBoundry`: compare it with `zScore`, if `zScore > entryPointBoundry`, for homework, we can think it's a `short signal` if `zScore < -entryPointBoundry`, we can think it's a `long signal`. We set it as 1.96 for all pairs (actually it can be different among pairs)
- `alpha`: regression 
- `beta`: regression

