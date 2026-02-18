# Port Aurora Core (GO-Core)

Port Aurora Core is a **custom FiveM framework layout** designed for:

- **Serious / semi-serious RP** gameplay expectations.
- **Server-authoritative logic** so game state is owned by the server whenever possible.
- **Performance-first architecture** with clean module boundaries.
- **100% custom-branded player-facing features** (UI, HUD, jobs, systems, and role content).

This repository provides a clean starting structure for all Port Aurora resources under a single namespace.

## Repository Layout

```text
/resources/[pa]/
  pa-core
  pa-shared
  pa-logging
  pa-perms
  pa-economy
  pa-inventory
  pa-ui
  pa-hud
  pa-jobs
  pa-business
  pa-job-construction
  pa-job-tow
  pa-job-sanitation
  pa-job-taxi
  pa-job-delivery
  pa-target
  pa-vehicles
  pa-housing
  pa-dispatch
  pa-police
  pa-ems
  pa-fire
  pa-crime
  pa-robbery-stores
  pa-robbery-houses
  pa-boosting
  pa-drugs
  pa-heists
  pa-factions
  pa-doj
  pa-media
  pa-story
  pa-admin
  pa-guard
  pa-bridge-qb
  pa-bridge-esx
  pa-devtools
/docs
```

## Naming Rules (Strict)

All custom resources are prefixed with `pa-`.

### Events
- Any event exported/emitted by `pa-*` resources **must** be prefixed with:
  - `pa:`
- Examples:
  - `pa:core:playerLoaded`
  - `pa:economy:paycheck`

### Exports
- Any export from `pa-*` resources **must** be prefixed with:
  - `Pa`
- Examples:
  - `exports('PaGetPlayer', function(source) ... end)`
  - `exports('PaAddMoney', function(source, amount) ... end)`

## Quick Start

1. Clone this repository into your FiveM server workspace.
2. Ensure your server's `resources` path points to this repository's `/resources` directory.
3. Keep all Port Aurora custom resources inside `/resources/[pa]/`.
4. Read the docs in order:
   - `docs/00-StartHere.md`
   - `docs/01-ResourceOrder.md`
   - `docs/02-Database.md`
   - `docs/03-HowToAddAJob.md`
   - `docs/04-HowToAddACrime.md`
   - `docs/05-UITheme.md`
  - `docs/06-InventoryUISkin.md`
  - `docs/07-HUDNeeds.md`
  - `docs/08-JobsCore.md`
  - `docs/09-StarterCivilianJobs.md`
  - `docs/10-BusinessSystem.md`
  - `docs/11-VehiclesSystem.md`
  - `docs/12-HousingSystem.md`
  - `docs/13-DispatchSystem.md`
  - `docs/14-PoliceSystem.md`
  - `docs/15-EMSSystem.md`
  - `docs/16-CrimeCore.md`
  - `docs/17-FactionsSystem.md`
  - `docs/18-CrimeActivities.md`
  - `docs/19-DOJSystem.md`
  - `docs/server_cfg_example.txt`
5. Copy `docs/server_cfg_example.txt` into your `server.cfg` and adjust credentials/webhooks.


## pa-shared (Single Source of Configs)

`pa-shared` ships versioned defaults for:

- items
- jobs
- factions
- licenses
- story chapters
- economy sinks
- strings/localization

Use the single export `PaShared:GetConfig(name)` to fetch immutable (copy-on-read) config tables.




## pa-ui Character NUI

`pa-ui` includes a beginner-friendly NUI character flow with:

- character list
- create character
- delete character (server-validated confirmation)
- spawn selection (`city_hall`, `apartment`, `pd` for police whitelist only)
- `skip tutorial` toggle saved in character metadata

UI styling is centralized in `resources/[pa]/pa-ui/web/theme.json`.


### UI primitives and wrappers

`pa-ui` ships reusable branded primitives:

- toast notifications
- modal confirm
- input dialog
- progress indicator
- compact interaction hint

Client exports:
- `PaUI:Notify(type, title, message, duration)`
- `PaUI:Prompt(key, text)`

Policy: replace generic third-party notifications in custom `pa-*` resources with `PaUI` wrappers for consistent Port Aurora branding.


## pa-inventory UI skin layer (ox_inventory)

`pa-inventory/ui` contains a patch-friendly visual overlay for `ox_inventory`:
- `upstream/` = mirrored upstream web snapshot
- `overlay/` = Port Aurora custom theme/layout/markers

Design targets:
- left categories
- center slot grid
- right item detail panel with quick actions (`use/drop/give/split`)
- visible illegal/evidence item markers

See `docs/06-InventoryUISkin.md` for exact changed files and rebase instructions.


## pa-crime core (heat, cases, dirty money, laundering)

`pa-crime` now provides shared illegal activity foundations:

- server-validated illegal activity events (rate limit, distance, cooldown, required item checks)
- dirty money consequences through `heat_events` and persistent `crime_cases`
- configurable laundering through approved businesses (fees, logs, and heat risk)
- decaying short-term heat so play remains fun, while case evidence persists for long-term consequences

Primary exports:
- `PaCrime:CommitIllegalActivity(src, payload)`
- `PaCrime:LaunderMoney(src, businessId, amount, payload)`
- `PaCrime:CanAccessBlackMarket(src, payload)`
- `PaCrime:GetHeat(src)`


## pa-factions (gangs, org crime, and legal factions)

`pa-factions` now supports gangs, biker clubs, syndicates, rare cartels, and legal org groups:

- rank-based member permissions
- optional territory zones with slow pressure/influence shifts
- faction storage with controlled access
- faction treasury using business account tables
- front-business links for laundering and RP story hooks

Primary exports:
- `PaFactions:GetFaction(src)`
- `PaFactions:HasPermission(src, permission)`
- `PaFactions:SetMemberFaction(actorSrc, targetSrc, factionId, rankName)`
- `PaFactions:AddTerritoryPressure(src, factionId, territoryKey, actionType, payload)`
- `PaFactions:DepositFunds(src, factionId, amount, reason)`
- `PaFactions:WithdrawFunds(src, factionId, amount, reason)`
- `PaFactions:LinkFrontBusiness(actorSrc, factionId, businessKey, launderingEnabled)`


## crime activity modules (tiered progression)

The following modules implement tiered crime progression with shared config + server-authoritative state:

- `pa-robbery-stores` (small jobs)
- `pa-robbery-houses` (mid-tier break-ins)
- `pa-boosting` (vehicle jobs)
- `pa-drugs` (supply-chain loops)
- `pa-heists` (late-game operations)

Each module supports:
- unlock gates by license/reputation/faction rank
- server-side run state and completion validation
- dirty-money payouts through `pa-economy`
- RP hook events (hostages, negotiators, fences, chop shops, informants)

Balancing source of truth:
- `resources/[pa]/pa-shared/shared/crime_activities.lua`


## pa-doj (courts, warrants, evidence use)

`pa-doj` now provides a beginner-friendly judicial workflow:

- DOJ whitelist roles via `staff_roles`: `judge`, `prosecutor`, `public_defender`
- case docket that links police reports, citations, warrants, and evidence refs
- weekly court scheduling for predictable sessions
- plea deal proposal/review flow
- judge-only warrant issuance + bail setting (server-validated)
- clear judicial action logging for audits

Primary exports:
- `PaDOJ:HasRole(src, role)`
- `PaDOJ:HasAny(src, roles)`
- `PaDOJ:Require(src, roles, failMessage)`
- `PaDOJ:GetDocket(src)`

## pa-logging (Structured Logging)

`pa-logging` provides structured server logging with:

- Console sink
- DB sink (`logs` table + category writes to `admin_actions` and `transactions`)
- Optional webhook sink

Exports available:
- `PaLogging:NewCorrelationId`
- `PaLogging:LogInfo`
- `PaLogging:LogWarn`
- `PaLogging:LogError`
- `PaLogging:LogAudit`
- `PaLogging:LogEconomy`
- `PaLogging:LogAdmin`

Policy: every `pa-*` module must route economy, inventory, permissions, bans, admin actions, and suspicious behavior through `pa-logging`.




## pa-economy (Ledger-Based + Server-Authoritative)

`pa-economy` supports accounts:
- `cash`
- `bank`
- `dirty`
- optional `business`

All money changes flow through exports:
- `PaEconomy:AddMoney(src, account, amount, reason, meta)`
- `PaEconomy:RemoveMoney(src, account, amount, reason, meta)`
- `PaEconomy:TransferMoney(src, targetSrc, account, amount, reason, meta)`
- `PaEconomy:GetBalance(src, account)`
- `PaEconomy:SetBalance(actorSrc, targetSrc, account, amount, reason, meta)` (staff-only)

Safety guarantees:
- integer-only amounts
- min/max sanity limits
- rate limits
- transaction ledger entries with before/after balances in metadata

Debug commands for staff testing:
- `/balance`
- `/pay`
- `/fine`

Economy sinks are configured in `pa-shared/shared/economy.lua` (rent, insurance, repairs, hospital bills, licensing fees, business taxes).


## pa-inventory (ox_inventory Adapter + Stable API)

`pa-inventory` is the server-side adapter around `ox_inventory` so other `pa-*` modules only depend on stable framework exports:

- `PaInventory:AddItem(src, item, count, metadata, reason)`
- `PaInventory:RemoveItem(src, item, count, metadata, reason)`
- `PaInventory:GetItemCount(src, item, metadata)`
- `PaInventory:HasItem(src, item, count, metadata)`
- `PaInventory:RegisterUsableItem(item, cb)`

Safety and consistency guarantees:
- server-authoritative add/remove only
- forbid zero/negative/non-integer counts
- max per transaction cap
- high-value grant rate limits (illegal/evidence flagged items)
- structured audit logs for every add/remove (item, count, metadata summary, reason)

`pa-shared/shared/items.lua` is the source of truth for labels/weights and item behavior flags (`illegal`, `isEvidence`, `isMedical`, `isFood`).


## pa-jobs core (civ + department framework)

`pa-jobs` is the framework layer all civilian and department jobs use.

Exports:
- `PaJobs:SetJob(src, jobName, grade)`
- `PaJobs:SetDuty(src, onDuty)`
- `PaJobs:GetJob(src)`

Job definitions in `pa-shared/shared/jobs.lua` support:
- grades + pay rules
- duty locations
- optional uniforms
- job actions (target zones)
- starter requirements (licenses/reputation)

City Hall provides a branded NUI Job Center that lists starter jobs and requirements.
Paychecks are always server-side through `pa-economy` with explicit reasons and logs.

## pa-perms (Staff + Whitelist + Department Access)

`pa-perms` reads `staff_roles` (license -> role) and provides roles:

- owner
- dev
- admin
- mod
- support
- whitelisted_pd
- whitelisted_ems
- whitelisted_fire
- whitelisted_doj

Exports:
- `PaPerms:HasRole(src, role)`
- `PaPerms:HasAny(src, roles)`
- `PaPerms:IsWhitelisted(src, dept)`
- `PaPerms:Require(src, roles, failMessage)`

Department duty updates are written to `job_duty` via `pa:perms:setDuty`.
Staff-only permission check failures are logged; normal player restrictions are not spam-logged.

## pa-guard (Shared Safety Utilities)

`pa-guard` provides reusable server safety helpers:

- `PaGuard:RateLimit(src, key, maxPerWindow, windowMs)` token-bucket protection per `source+event key`
- `PaGuard:ValidateDistance(src, targetCoords, maxDist)` ped/coords/distance validation

Sensitive events must call these helpers and log violations through `pa-logging`:
- payouts
- robberies
- item crafting
- admin actions


## pa-hud + needs (semi-serious, fun not punishing)

`pa-hud` ships a custom NUI HUD with:
- health / armor
- hunger / thirst
- stress
- voice + radio status
- compact cash/bank display

Needs profile is intentionally light-touch:
- slow timer-based decay (no 0ms loops)
- stress rises during shootings/chases
- stress lowers through food, rest, and therapy RP

Food/drink effects are wired through `PaInventory:RegisterUsableItem` so item usage remains server-authoritative.


## Starter civilian jobs pack

Starter civilian gameplay resources:
- `pa-job-delivery`
- `pa-job-taxi`
- `pa-job-sanitation`
- `pa-job-tow`
- `pa-job-construction`

Each resource depends on `pa-jobs`, `pa-economy`, `pa-target`, and `pa-ui`, and includes:
- start/stop shift flow
- route generation
- anti-exploit validation (distance + cooldown)
- payout scaling based on reputation

Fun touches:
- taxi NPC tips
- sanitation rare finds
- construction city-project progress events for story hooks


## pa-business (player-run economy glue)

`pa-business` introduces player-run business operations:
- business registry and role-based access (`owner`, `manager`, `employee`)
- business balance, payroll, invoices, and receipts
- simple restaurant/bar production recipes

Money movement is always server-side through `pa-economy` and invoice payments are logged via `pa-logging`.

Civilian impact hooks:
- restaurants/bars reduce stress/hunger via meal effects
- mechanics can provide service discounts
- security businesses can be hired for events

Business license fees and periodic taxes are configurable sinks in shared economy config.


## pa-vehicles (ownership + keys + garages + insurance)

`pa-vehicles` provides:
- owned vehicle persistence (plate/model/props/state/garage/insured)
- key sharing/revoke flows
- garage + impound states
- insurance claims and repair costs as economy sinks

All spawn/despawn operations are server-authoritative, rate limited, and suspicious plate duplication attempts are logged.
A beginner-friendly garage NUI is included in `resources/[pa]/pa-vehicles/web/*`.


## pa-housing (homes as RP hubs)

`pa-housing` provides:
- property purchase/rent with realtor workflow
- housing key sharing and revocation
- storage stashes via `ox_inventory` gated by housing key permissions

Housing is tied to story and world state:
- rebuilding grants
- neighborhood reputation tracking
- gang-pressure in territorial neighborhoods

Rent due is designed to be fair (grace window) rather than overly punishing.


## pa-dispatch (shared calls for PD/EMS/Fire)

`pa-dispatch` provides:
- shared emergency call creation and triage
- unit assignment and status timeline updates
- persistent incident records in `dispatch_calls`
- minimal branded dispatch feed UI with assign/status actions

Core exports:
- `PaDispatch:CreateCall`
- `PaDispatch:AssignUnit`
- `PaDispatch:UpdateStatus`
- `PaDispatch:CloseCall`

All major call updates are logged through `pa-logging` for audit trails.

## pa-police (serious structure, semi-serious pacing)

`pa-police` provides:
- police duty state, unit roster, and grade/rank checks
- traffic stops flow through citations and short arrest processing
- short-template report writing (minimal paperwork + optional freeform)
- lightweight MDT for person/plate lookup, citations, warrants, and case notes
- evidence-lite collection (GSR/blood/casing) with server cooldown + distance validation

The data model is prepared for later `pa-doj` court integration.

## pa-ems (medical RP that is actually fun)

`pa-ems` provides:
- EMS duty, revive, and transport workflows
- injury states (`minor`, `major`, `critical`) with hospital-bed transport
- major-incident records with simple UI and short inputs
- hospital billing + insurance reduction through `pa-economy`
- Good Samaritan 911 + CPR actions with cooldown and proximity checks

Revive flows require supplies (`medkit`/`bandage`) and server-side validation to prevent abuse.

## pa-core Foundation

`pa-core` owns the server-authoritative player model and lifecycle.

- Caches Player objects by `source` with identity, character, job, duty, account snapshot, metadata, and `lastSaveAt`.
- Handles connect/disconnect save lifecycle and character select/logout events (`pa:core:*`).
- Exposes server exports: `PaCore:GetPlayer`, `PaCore:GetCharId`, `PaCore:GetLicense`, `PaCore:Kick`.
- Clients are not trusted to set money, items, or jobs directly.

## Project Goals

Port Aurora aims to provide a maintainable base where each system is isolated, testable, and easy for new contributors to understand. New features should preserve:

- stable server performance,
- roleplay consistency,
- auditability/log visibility,
- and strong branding coherence.


## Startup Safety

Every `pa-*` resource includes a dependency check on startup. If a required dependency is missing, the resource prints a clear error with a fix step and stops itself to avoid undefined behavior.


## Database Bootstrap

- Canonical schema: `sql/pa_schema.sql`
- Dev safe apply command: `/pa-devtools apply-schema`
- Production: run SQL manually with backups/change control.
