# 15) EMS System (`pa-ems`)

`pa-ems` provides fun medical RP with server-authoritative checks and lightweight operations.

## EMS gameplay
- Duty state for EMS units via `pa-jobs`.
- Revive and transport flows with proximity validation.
- Injury states: `minor`, `major`, `critical`.
- Hospital bed transport and release handling.
- Major-incident records and fair billing with insurance reduction.

## Good Samaritan actions
- Civilian 911 calls routed into `pa-dispatch`.
- Basic civilian CPR action.
- Both actions are rate-limited and proximity-validated to reduce abuse.

## Safety + economy
- Revives require inventory supplies (`medkit` or `bandage`) and consume an item.
- Hospital billing uses `pa-economy` with meaningful but non-oppressive insurance adjustment.
- Major actions and bills are logged via `pa-logging`.
