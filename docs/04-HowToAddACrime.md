# 04 - How To Add A Crime

Use this guide when adding a new criminal activity or chain.

## Step-by-step

1. Define crime data in `pa-crime` (requirements, rewards, cooldowns).
2. Add economy outcomes in `pa-economy`.
3. Add item outcomes in `pa-inventory`.
4. Add response hooks for `pa-police` / `pa-dispatch`.
5. Add legal interactions in `pa-doj` if needed.

## Security principles

- Keep all validation server-side.
- Never trust client-reported success/failure states.
- Add anti-abuse checks and logging.

## Naming rules

- Event example: `pa:crime:startBoost`
- Export example: `PaCanStartCrime`
