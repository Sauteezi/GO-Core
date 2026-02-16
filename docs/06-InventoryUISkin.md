# 06 - Inventory UI skin layer (ox_inventory)

Port Aurora keeps inventory gameplay logic in `ox_inventory` and applies custom branding via a skin layer in:

- `resources/[pa]/pa-inventory/ui/`

## Exactly which UI files were changed

Port Aurora custom files:
- `resources/[pa]/pa-inventory/ui/overlay/theme.json`
- `resources/[pa]/pa-inventory/ui/overlay/pa_inventory_skin.css`
- `resources/[pa]/pa-inventory/ui/overlay/pa_inventory_skin.js`
- `resources/[pa]/pa-inventory/ui/overlay/preview.html`
- `resources/[pa]/pa-inventory/ui/README.md`
- `resources/[pa]/pa-inventory/ui/scripts/rebase_ox_inventory_ui.sh`

Upstream snapshot folder (do not hand-edit):
- `resources/[pa]/pa-inventory/ui/upstream/*`

## Layout conventions

The PA skin layer targets a 3-column layout:
- Left: category navigation
- Center: slot grid
- Right: item details + quick actions (`use`, `drop`, `give`, `split`)

It also adds explicit markers for flagged items:
- `ILLEGAL`
- `EVIDENCE`

## Rebase/upgrade process

1. Pull latest `ox_inventory` into a temporary location.
2. Run:
   - `resources/[pa]/pa-inventory/ui/scripts/rebase_ox_inventory_ui.sh /path/to/ox_inventory`
3. Compare upstream selector changes against `overlay/pa_inventory_skin.css` and `overlay/pa_inventory_skin.js`.
4. Adjust only files in `overlay/` for compatibility.
5. Validate rendering and interactions (`use/drop/give/split`) in-game.
6. Commit both the refreshed `upstream/` snapshot and any overlay adjustments.
