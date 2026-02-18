# 17 - Factions System (Gangs, Organized Crime, Legal Orgs)

`pa-factions` provides faction gameplay glue for criminal and legal organization RP.

## Supported faction types

- gangs
- biker clubs
- syndicates
- cartels (rare)
- legal orgs (unions, political/community groups)

## Core features

- rank + permission model per faction
- optional territory zones
- slow territory pressure shifts (no grind loops)
- faction storage with permission checks
- faction treasury via business account tables
- front-business links for laundering and story RP

## Slow pressure design

Territory influence is intentionally slow:

- action cooldowns and rate limits
- small influence changes per qualified event
- proximity and server checks required

This keeps territory conflict meaningful without rewarding constant repetitive farming.

## Data/config locations

- Faction definitions/ranks/zones: `resources/[pa]/pa-shared/shared/factions.lua`
- Runtime service: `resources/[pa]/pa-factions/server/faction_service.lua`
- Core tables: `faction_members`, `faction_territory`, `reputation`, `faction_fronts`

## Key exports

- `PaFactions:GetFaction(src)`
- `PaFactions:HasPermission(src, permission)`
- `PaFactions:SetMemberFaction(...)`
- `PaFactions:AddTerritoryPressure(...)`
- `PaFactions:DepositFunds(...)`
- `PaFactions:WithdrawFunds(...)`
- `PaFactions:LinkFrontBusiness(...)`
