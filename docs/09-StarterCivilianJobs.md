# 09 - Starter civilian jobs pack

Resources:
- `pa-job-delivery`
- `pa-job-taxi`
- `pa-job-sanitation`
- `pa-job-tow`
- `pa-job-construction`

Each resource depends on:
- `pa-jobs`
- `pa-economy`
- `pa-target`
- `pa-ui`

## Shared mechanics
- Start/stop shift events.
- Route generation with waypoint updates.
- Anti-exploit validation:
  - cooldown checks
  - distance validation via `pa-guard` (`PaGuard:ValidateDistance`)
- Payouts through `PaEconomy:AddMoney` with reputation scaling.

## Flavor features
- Taxi: random NPC tip bonus.
- Sanitation: chance to find a rare item (`evidence_bag`).
- Construction: increments city-project progress and emits story event `pa:story:cityProjectProgress`.
