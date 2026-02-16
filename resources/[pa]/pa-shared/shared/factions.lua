--[[
Config Schema: factions.lua
- Register under PaSharedConfigRegistry.factions
- version (string): config revision.
- defaults (table): optional behavior defaults.
  - maxMembers (number)
  - allowAlliances (boolean)
- factions (table<string, table>): keyed by faction id.
  - label (string)
  - type (string): e.g. legal/criminal/civilian.
  - maxMembers (number)
  - tags (array<string>)
How to extend:
1) Add faction ids and label them for clear admin UX.
2) Keep type values consistent for permission checks.
]]

PaSharedConfigRegistry = PaSharedConfigRegistry or {}

PaSharedConfigRegistry.factions = {
    version = '1.0.0',
    defaults = {
        maxMembers = 20,
        allowAlliances = false,
    },
    factions = {
        pd = {
            label = 'Port Aurora Police',
            type = 'legal',
            maxMembers = 40,
            tags = { 'law', 'response' },
        },
        ems = {
            label = 'Port Aurora EMS',
            type = 'legal',
            maxMembers = 30,
            tags = { 'medical', 'rescue' },
        },
        waterfront_collective = {
            label = 'Waterfront Collective',
            type = 'criminal',
            maxMembers = 15,
            tags = { 'smuggling', 'docks' },
        },
    },
}
