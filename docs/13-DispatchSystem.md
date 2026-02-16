# 13) Dispatch System (`pa-dispatch`)

`pa-dispatch` is the shared emergency call backbone for PD/EMS/Fire roleplay.

## What it provides

- Server-authoritative call lifecycle with exports:
  - `PaDispatch:CreateCall(src, payload)`
  - `PaDispatch:AssignUnit(src, callId, unit)`
  - `PaDispatch:UpdateStatus(src, callId, status, note)`
  - `PaDispatch:CloseCall(src, callId, note)`
- Branded minimal dispatch NUI feed with unit assignment helpers.
- Persistent storage in `dispatch_calls` for staff incident review.
- Audit logging of major updates through `pa-logging`.

## Call model

Each call tracks:

- `id`
- `type`
- `priority`
- `coords`
- `description`
- `callerCharId`
- `assignedUnits`
- `statusTimeline`
- `status`
- `createdAt`

## Staff review

Calls are saved to `dispatch_calls` with JSON snapshots for `coords`, `assigned_units`, and the full status timeline.

This allows staff tooling and after-action review without relying on volatile in-memory state.
