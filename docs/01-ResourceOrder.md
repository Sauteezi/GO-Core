# 01 - Resource Order

Resource order matters in FiveM. Start dependencies first, then foundational PA resources, then feature modules.

## Required dependencies (start first)

```cfg
ensure oxmysql
ensure ox_lib
ensure pma-voice
ensure ox_target
```

## Recommended Port Aurora startup order

```cfg
ensure pa-shared
ensure pa-core
ensure pa-logging
ensure pa-perms
ensure pa-economy
ensure pa-inventory
ensure pa-ui
ensure pa-hud
ensure pa-guard
ensure pa-target
ensure pa-jobs
ensure pa-business
ensure pa-vehicles
ensure pa-housing
ensure pa-dispatch
ensure pa-police
ensure pa-ems
ensure pa-fire
ensure pa-crime
ensure pa-robbery-stores
ensure pa-robbery-houses
ensure pa-boosting
ensure pa-drugs
ensure pa-heists
ensure pa-factions
ensure pa-doj
ensure pa-media
ensure pa-story
ensure pa-admin
ensure pa-job-delivery
ensure pa-job-taxi
ensure pa-job-sanitation
ensure pa-job-tow
ensure pa-job-construction
ensure pa-bridge-qb
ensure pa-bridge-esx
ensure pa-devtools
```

## Recommended practice

- Copy from `docs/server_cfg_example.txt` as your baseline.
- Keep `pa-shared` and `pa-core` at the top of PA resources.
- `pa-core` is the only hard gameplay dependency for other `pa-*` gameplay modules.
- Keep bridges (`pa-bridge-*`) near the bottom unless a hard dependency says otherwise.
- Every `pa-*` resource includes startup dependency checks and will print beginner-friendly errors if order is wrong.
