# 16 - Crime Core (Heat, Cases, Dirty Money, Laundering)

`pa-crime` is the shared foundation for illegal actions so consequences are meaningful without making RP grindy.

## Design goals

- **Consequences but playable:** short-term heat decays over time.
- **Persistent investigations:** case evidence does not auto-reset.
- **Server-authoritative validation:** client requests are always validated server-side.

## What `pa-crime` tracks

- **Heat events** (`heat_events`) for each illegal action.
- **Crime cases** (`crime_cases`) that gather evidence and can escalate to warrant recommendations.
- **Dirty money laundering** through approved businesses with configurable fees/risk.
- **Black market access rules** based on heat window, item checks, and proximity.

## Validation rules for illegal events

Every illegal activity should call either:
- `pa:crime:commitIllegalActivity` (event), or
- `PaCrime:CommitIllegalActivity(...)` (export)

Validation includes:
1. rate limiting (`pa-guard`),
2. per-action cooldown,
3. distance checks (`pa-guard`),
4. required item checks (`pa-inventory`).

If validation fails, the action is blocked and logged via `pa-logging`.

## Laundering flow

Use event `pa:crime:requestLaunder` or export `PaCrime:LaunderMoney`.

- Source account: `dirty`
- Destination account: `bank`
- Fee: configured in `pa-shared/shared/crime.lua`
- Risk: laundering also emits heat

## Config location

Tune values in:
- `resources/[pa]/pa-shared/shared/crime.lua`

Key settings:
- `heat.maxHeat`
- `heat.decayIntervalSeconds`
- `heat.decayPerTick`
- `evidence.defaultChance`
- `evidence.warrantThreshold`
- `laundering.feePercent`

## Integration notes

- Robberies should route through `PaCrime:CommitIllegalActivity`.
- Other illegal systems (drugs, boosting, burglary, fraud) should use the same shared API so heat/cases stay consistent.
- PD/DOJ can listen for `pa:crime:warrantRecommended` to create warrants/raid plans.
