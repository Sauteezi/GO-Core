# 08 - Jobs Core (City Hall + duty + paychecks)

`pa-jobs` is the shared job framework for civilian and department roles.

## Job model
Each job definition includes:
- `name` / `label`
- `grades`
- `payRules`
- `dutyLocations`
- optional `uniforms`
- `jobActions` target zones
- `requirements` (licenses/reputation)

Source of truth: `pa-shared/shared/jobs.lua`.

## Exports
- `PaJobs:SetJob(src, jobName, grade)`
- `PaJobs:SetDuty(src, onDuty)`
- `PaJobs:GetJob(src)`

## City Hall Job Center
- NUI menu opens at City Hall (or with `/jobcenter`).
- Starter jobs list includes requirement summaries.
- Job assignment is server-validated.

## Paychecks
- Processed server-side on interval timer.
- Deposits go through `pa-economy` (`PaEconomy:AddMoney` to `bank`).
- Reason is explicit (`paycheck:<job>:g<grade>`) for audit clarity.
- Paycheck issues are logged through `pa-logging` economy events.
