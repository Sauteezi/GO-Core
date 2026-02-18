# 03 - How To Add A Job

This is a beginner-friendly flow for adding a new job.

## Step-by-step

1. Add shared config in `pa-shared` (job name, grades, permissions).
2. Create job server logic in `pa-jobs`.
3. Add UI interactions in `pa-ui` / `pa-hud` if needed.
4. Add dispatch hooks in `pa-dispatch` if the job needs alerts.
5. Add logs in `pa-logging` for critical actions.

## Naming rules you must follow

- Events must start with `pa:`
  - Example: `pa:jobs:setDuty`
- Exports must start with `Pa`
  - Example: `PaSetPlayerJob`

## Validation checklist

- [ ] Duty toggle works.
- [ ] Paycheck logic works.
- [ ] Job permissions enforced by `pa-perms`.
- [ ] Actions are logged.
