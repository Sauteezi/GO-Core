# 12 - Housing (homes as RP hubs)

`pa-housing` provides purchase/rent, key permissions, and storage with story-aware neighborhood dynamics.

## Core features
- Property definitions with entry coords, price, rent, interior type, and metadata.
- Purchase and rent workflows (realtor UI + server validation).
- Key sharing/revoking (`owner` and `tenant` access model).
- Storage via `ox_inventory` stashes, access controlled by housing keys.

## Realtor + rent due
- Beginner-friendly realtor UI for browse/rent/buy.
- Rent due loop with grace period to avoid overly punishing immediate eviction.
- Automatic rent attempt when owner is online and grace-based revocation if unpaid.

## Story and territory tie-ins
- Rebuilding grants awarded on housing onboarding actions.
- Neighborhood reputation increases from housing activity.
- Gang pressure tracks territory-sensitive neighborhoods and can block access when very high.
- Story hook event emitted: `pa:story:housingRebuildProgress`.
