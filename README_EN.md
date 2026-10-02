# GoldX9 Base — MT5 Fractal Breakout EA

> A MetaTrader 5 (MT5) Expert Advisor based on breakouts of prior swing highs and lows. The EA places pending orders around confirmed fractal structures and manages each trade with defined stop-loss, take-profit, and optional position-management rules.

[rbot.cc](https://rbot.cc/) · [Source code](./GoldX9_Base.mq5)

## Strategy Overview

The EA scans a selected timeframe for confirmed fractal highs and lows:

- A `Buy Stop` is placed around a fractal high to capture an upside breakout.
- A `Sell Stop` is placed around a fractal low to capture a downside breakout.
- A minimum-distance filter prevents orders from being placed too close to the current market price.
- Maximum pending orders, maximum open positions, order expiry, and duplicate-price filtering limit exposure.
- Every submitted order includes a server-side stop-loss and take-profit.

Price distances are defined as percentages rather than fixed point values, making the setup easier to adapt across instruments with different price levels. Broker specifications, spread, liquidity, and minimum stop distances still materially affect live results.

## Features

- Fractal high/low scanning with configurable left and right confirmation bars
- Buy Stop and Sell Stop breakout entries
- Percentage-based entry offsets, stop-losses, and take-profits
- Pending-order expiry, maximum-pending, and maximum-position limits
- Duplicate-price filtering for same-direction pending orders
- Fixed-lot or equity-risk-percent position sizing
- Break-even, trailing-stop, and salvage exit management
- Magic Number and order-comment isolation

## Installation

1. Download [GoldX9_Base.mq5](./GoldX9_Base.mq5).
2. Copy it to the `MQL5/Experts/` directory inside your MT5 data folder.
3. Compile it in MetaEditor and confirm there are no errors.
4. Attach the EA to the desired instrument chart.
5. Test it in the MT5 Strategy Tester using your broker's contract specifications, spread, and historical data.
6. Validate the configuration on a demo account before considering live deployment.

## Key Parameters

| Parameter | Default | Description |
| --- | ---: | --- |
| `InpFractalTF` | `H1` | Timeframe used to identify market structure |
| `InpFractalLeft` / `InpFractalRight` | `5 / 5` | Confirmation bars required on each side of a fractal |
| `InpMaxSearchBars` | `200` | Maximum historical bars scanned for a fractal |
| `InpMinFractalClearancePct` | `0.02%` | Minimum distance between current price and a fractal |
| `InpBuyEntryOffsetPct` / `InpSellEntryOffsetPct` | `-0.10% / -0.10%` | Pending-order offset relative to a swing high or low |
| `InpStopLossPct` | `2.00%` | Stop-loss distance calculated from entry price |
| `InpTakeProfitPct` | `1.00%` | Take-profit distance calculated from entry price |
| `InpTrailTriggerPct` / `InpTrailDistancePct` | `0.20% / 0.20%` | Profit threshold to begin trailing and trail distance |
| `InpBreakEvenTriggerPct` / `InpBreakEvenLockPct` | `0.10% / 0.025%` | Break-even trigger and profit lock |
| `InpRiskPercent` | `0.50%` | Theoretical per-trade risk in risk-sizing mode |

> A negative `InpBuyEntryOffsetPct` or `InpSellEntryOffsetPct` places the order on the early-entry side of the fractal. Always test this against the target instrument's spread and broker minimum-distance rules.

## Risk and Backtesting

This is not a martingale strategy and it does not average into losing positions. That does **not** mean it is risk-free. Fractal-breakout systems can experience consecutive false breakouts in ranging markets, and historical results do not predict future performance.

Before using the EA, test at least the following:

- Use every-tick or the highest-quality tick data available.
- Test separate market regimes, including trending and ranging periods.
- Use the target broker's spread, commission, swap, and minimum stop-distance settings.
- Perform out-of-sample validation instead of optimizing only a single historical period.
- Set `InpRiskPercent`, `InpMaxPending`, and `InpMaxPositions` so total exposure fits your risk tolerance.

## Current Scope

This repository contains a single base-strategy implementation. The source tutorial describes a possible future implementation with multiple parameterized strategies, tiered position sizing, and a graphical control panel. Those features are not presented here as implemented or validated functionality.

## Disclaimer

This project is provided solely for research, education, and strategy testing. It is not investment advice and does not promise returns. Automated trading can result in loss of capital. You are responsible for validating the code, understanding your broker's rules, and making your own trading decisions.

## Links

- [rbot.cc](https://rbot.cc/)
