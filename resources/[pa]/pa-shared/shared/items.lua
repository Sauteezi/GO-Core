--[[
Config Schema: items.lua
- Register under PaSharedConfigRegistry.items
- version (string): config revision for migrations and changelog tracking.
- defaults (table): fallback values used when an item omits optional fields.
- items (table<string, table>): keyed by item id.
  - label (string): player-facing name.
  - description (string): short description.
  - weight (number): inventory weight units.
  - stackable (boolean): whether items can stack.
  - category (string): grouping for UI/filtering.
  - illegal (boolean): marks contraband/high-risk items.
  - isEvidence (boolean): marks police evidence items.
  - isMedical (boolean): marks medical-use items.
  - isFood (boolean): marks consumable food/hydration items.
How to extend:
1) Add a new entry under items with a unique id key.
2) Keep id lowercase with underscores.
3) Use flags (`illegal`, `isEvidence`, `isMedical`, `isFood`) so pa-inventory can apply rules and logs consistently.
]]

PaSharedConfigRegistry = PaSharedConfigRegistry or {}

PaSharedConfigRegistry.items = {
    version = '1.2.0',
    defaults = {
        weight = 1,
        stackable = true,
        category = 'misc',
        illegal = false,
        isEvidence = false,
        isMedical = false,
        isFood = false,
    },
    items = {
        water_bottle = {
            label = 'Water Bottle',
            description = 'Hydration for long shifts in Port Aurora.',
            weight = 1,
            stackable = true,
            category = 'consumable',
            isFood = true,
        },
        sandwich = {
            label = 'Sandwich',
            description = 'Quick meal from a local deli.',
            weight = 1,
            stackable = true,
            category = 'consumable',
            isFood = true,
        },
        medkit = {
            label = 'Medical Kit',
            description = 'Used to stabilize and patch up injuries.',
            weight = 3,
            stackable = true,
            category = 'medical',
            isMedical = true,
        },
        evidence_bag = {
            label = 'Evidence Bag',
            description = 'Properly seals and stores collected evidence.',
            weight = 1,
            stackable = true,
            category = 'evidence',
            isEvidence = true,
        },
        lockpick = {
            label = 'Lockpick',
            description = 'A thin tool for unauthorized lock manipulation.',
            weight = 1,
            stackable = true,
            category = 'tool',
            illegal = true,
        },
        radio = {
            label = 'Portable Radio',
            description = 'Used for faction and emergency communication.',
            weight = 2,
            stackable = false,
            category = 'equipment',
        },
        repair_kit = {
            label = 'Repair Kit',
            description = 'Basic toolkit for roadside mechanical work.',
            weight = 5,
            stackable = true,
            category = 'tool',
        },
    },
}
