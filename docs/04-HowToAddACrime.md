# 04 - How To Add A Crime

Use this guide when adding a new criminal activity or chain.

## Step-by-step

1. Define crime activity data (required item, cooldown, heat/evidence values).
2. Call `PaCrime:CommitIllegalActivity(src, payload)` from your server event.
3. If rewards include money, use `pa-economy` (dirty account for illegal payouts).
4. Add follow-up hooks for `pa-police` / `pa-dispatch` / `pa-doj` as needed.

## Required server validations

Every illegal event should enforce:

- rate limit (`PaGuard:RateLimit`),
- distance check (`PaGuard:ValidateDistance`),
- cooldown,
- required item checks (`PaInventory:HasItem`).

`PaCrime:CommitIllegalActivity(...)` already applies these checks when payload fields are provided.

## Consequence model

- Emit heat for every illegal activity (`heat_events`).
- Optionally add evidence to a persistent case (`crime_cases`).
- Let short-term heat decay over time, but keep case evidence for longer-term consequences.

## Naming rules

- Event examples: `pa:crime:requestRobbery`, `pa:crime:commitIllegalActivity`
- Export examples: `PaCrime:CommitIllegalActivity`, `PaCrime:LaunderMoney`
