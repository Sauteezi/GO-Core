# 11 - Vehicles (ownership, keys, garages, insurance)

`pa-vehicles` provides server-authoritative vehicle lifecycle and garage UX.

## Core capabilities
- Owned vehicles persistence (`vehicles` table) with:
  - plate
  - model
  - `props_json`
  - state
  - garage location
  - `insured` flag
- Keys persistence (`vehicle_keys`) with owner/shared keys.
- Garage + impound state transitions.
- Insurance claim flow and repair-cost economy sinks.

## Security model
- Spawn/despawn are server-authorized events only.
- Rate limits are enforced via `pa-guard`.
- Suspicious plate duplication attempts are blocked and logged (`pa-logging`).

## UI
- Beginner-friendly garage NUI in `resources/[pa]/pa-vehicles/web/*`.
- Uses branded notification pathways through `pa-ui` event conventions.

## SQL updates
- `vehicles` includes `props_json` and `insured` columns.
- Added `vehicle_insurance_claims` table for claim history.
