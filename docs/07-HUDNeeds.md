# 07 - HUD + Needs (semi-serious profile)

`pa-hud` provides a custom NUI HUD and a lightweight needs system designed to encourage RP without creating grind.

## HUD features
- Health / armor
- Hunger / thirst
- Stress
- Voice and radio status
- Compact money display (cash + bank)

## Needs design goals
- Slow passive decay using timers (no 0ms loops).
- Stress rises in tense gameplay (shootings/chases).
- Stress lowers via food, rest, and therapy RP.
- Values are intentionally moderate to nudge RP behaviors (restaurants, hospital, social RP) rather than punish players.

## Item hooks
Food/drink effects are registered using:
- `PaInventory:RegisterUsableItem('water_bottle', cb)`
- `PaInventory:RegisterUsableItem('sandwich', cb)`

The callbacks remove the item server-side and then apply needs deltas server-side.
