# 05 - UI Theme

Port Aurora is custom-branded. Visible UI should feel consistent.

## Theme goals

- Clear readability in bright and dark scenes.
- Minimal HUD clutter.
- Consistent spacing, colors, and typography.

## Where to implement UI

- Core UI components: `pa-ui`
- HUD state and overlays: `pa-hud`
- Feature-specific additions should still follow base style tokens.

## Branding standards

- Use Port Aurora naming and identity in visible labels.
- Avoid importing third-party branded visuals directly.
- Keep all outward-facing components clearly part of the PA identity.

## Naming standards reminder

- Events: `pa:*`
- Exports: `Pa*`


## UI primitives

Use shared `pa-ui` primitives for consistent look and behavior:
- toast notifications
- confirm modal
- input prompt
- progress indicator
- interaction hint

Use client exports `PaUI:Notify` and `PaUI:Prompt` instead of generic third-party notification APIs in custom resources.
