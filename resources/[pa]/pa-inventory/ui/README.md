# pa-inventory UI skin layer (ox_inventory)

This folder is a **patch-friendly skin layer** for `ox_inventory` web UI.

## Goals
- Keep gameplay/server logic in `ox_inventory`.
- Own a unique Port Aurora visual style in a small overlay.
- Make future upstream merges straightforward.

## Structure
- `upstream/`: local mirror of upstream `ox_inventory/web` files (unmodified snapshot).
- `overlay/`: Port Aurora-only files (theme + layout overrides + optional UI decorators).
- `scripts/rebase_ox_inventory_ui.sh`: helper to refresh `upstream/` from an ox_inventory checkout.

## Files changed by Port Aurora
- `overlay/theme.json`
- `overlay/pa_inventory_skin.css`
- `overlay/pa_inventory_skin.js`
- `overlay/preview.html`

## Rebase workflow
1. Pull latest `ox_inventory` in a separate checkout.
2. Run `scripts/rebase_ox_inventory_ui.sh /path/to/ox_inventory` to refresh `upstream/`.
3. Compare `upstream/` with your current production ox web files.
4. Re-validate selectors used by `overlay/pa_inventory_skin.css`.
5. Re-test key screens (inventory, context actions, give/split/drop).

If upstream changes break selectors, only update `overlay/*` files; avoid editing `upstream/*` directly.
