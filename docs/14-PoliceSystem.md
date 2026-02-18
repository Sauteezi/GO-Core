# 14) Police System (`pa-police`)

`pa-police` provides serious-structure policing with semi-serious pacing and short-form paperwork.

## Core features

- Duty control linked to `pa-jobs` police role and grade.
- Rank/grade-gated permissions for advanced actions.
- Loadout restrictions by grade (armory-safe list export).
- Traffic enforcement flow via citations.
- Arrest + jail processing with concise charge capture.
- Short-template report writing with optional freeform notes.

## MDT (lightweight)

- Person lookup (`characters`) by name/citizen ID.
- Plate lookup (`vehicles`) with owner details.
- Citation records, warrants, and case notes.
- Simple roster + duty status visibility for active units.

## Evidence-lite

- Evidence bagging through `pa-inventory` (`evidence_bag`).
- Basic collection modes: GSR, blood, casings (and extensible types).
- Server validation for cooldown and distance checks (`pa-guard`).

## DOJ integration path

The system stores structured citations/warrants/case notes/arrests so `pa-doj` can later consume or mirror records for court workflows.
