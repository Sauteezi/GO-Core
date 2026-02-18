# 19 - DOJ System (Courts, Warrants, Evidence)

`pa-doj` is the court/legal coordination module for Port Aurora.

## DOJ roles (whitelist)

Roles are read from `staff_roles.role_name` and limited to:

- `judge`
- `prosecutor`
- `public_defender`

## Docket system

DOJ cases combine legal references into one view:

- police reports
- citations
- warrants
- evidence references

## Court scheduling (weekly)

Judges can schedule cases to weekly court slots using day-of-week + hour inputs.

## Plea workflow

- Prosecutor / public defender can propose plea terms.
- Judges can accept or reject pleas.

## Judge-only actions

- issue warrants (server-side validated insert into `police_warrants`)
- set bail on DOJ cases

## Beginner-friendly UI and templates

The NUI is intentionally simple: one docket list and basic action forms with short templates and direct action buttons.

## Core files

- `resources/[pa]/pa-doj/server/doj_service.lua`
- `resources/[pa]/pa-doj/client/main.lua`
- `resources/[pa]/pa-doj/web/*`
