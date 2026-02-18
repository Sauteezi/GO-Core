# 18 - Crime Activity Modules (Tiered Progression)

Port Aurora crime progression is split into dedicated modules:

- `pa-robbery-stores`
- `pa-robbery-houses`
- `pa-boosting`
- `pa-drugs`
- `pa-heists`

## Progression model

Each module defines tier entries in shared config and enforces unlock requirements server-side:

- license requirements
- reputation requirements
- faction rank requirements

## Server-authoritative safety

Modules keep active runs server-side and validate completion using:

- rate limits
- distance checks
- tier/cooldown rules
- `pa-crime` heat/case writes

Payouts are dirty-money only (`PaEconomy:AddMoney(..., 'dirty', ...)`).

## RP interaction hooks

Modules emit RP hooks for:

- hostages
- negotiator calls
- fences
- chop shops
- informant chances

## Balancing

Tune all tiers centrally in:

- `resources/[pa]/pa-shared/shared/crime_activities.lua`
