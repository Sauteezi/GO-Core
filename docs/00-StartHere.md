# 00 - Start Here

Welcome to Port Aurora's framework repository.

If you're new, this is the easiest path:

1. Learn the folder layout in the root `README.md`.
2. Confirm all custom resources are placed under `/resources/[pa]/`.
3. Read `01-ResourceOrder.md` to understand startup dependencies.
4. Read `02-Database.md` before writing systems that save data.
5. Use the naming standards everywhere:
   - events start with `pa:`
   - exports start with `Pa`

## Why this structure exists

- Faster onboarding for new developers.
- Clear boundaries between gameplay systems.
- Better long-term maintainability.

## First development tips

- Keep shared constants in `pa-shared`.
- Put framework bootstrap logic in `pa-core`.
- Add logging hooks in `pa-logging` for critical systems.


## Shared config system

`pa-shared` is the single source of truth for default configs.

- `shared/items.lua`
- `shared/jobs.lua`
- `shared/factions.lua`
- `shared/licenses.lua`
- `shared/story_chapters.lua`
- `shared/economy.lua`
- `shared/strings.lua`

Read configs via export: `PaShared:GetConfig(name)`. Returned tables are immutable snapshots (copy-on-read).


## Safety utilities

Use `pa-guard` exports in sensitive server events:
- `PaGuard:RateLimit(src, key, maxPerWindow, windowMs)`
- `PaGuard:ValidateDistance(src, targetCoords, maxDist)`

Always log violations via `pa-logging` for auditability.


## Character UI flow

`pa-ui` ships a basic NUI for character select/create/delete and spawn selection.
All NUI actions call server events, and `pa-core` performs validation and database writes server-side.
