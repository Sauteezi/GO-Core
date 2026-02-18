--[[
Config Schema: housing.lua
- Register under PaSharedConfigRegistry.housing
- properties (table<string, table>)
  - label, entryCoords, price, rent, interiorType, metadata
  - neighborhood (string)
  - territoryFaction (string|nil)
- defaults:
  - rentIntervalHours
  - graceHours
  - stashSlots
  - stashWeight
  - rebuildingGrant
]]

PaSharedConfigRegistry = PaSharedConfigRegistry or {}

PaSharedConfigRegistry.housing = {
    version = '1.0.0',
    defaults = {
        rentIntervalHours = 24,
        graceHours = 12,
        stashSlots = 50,
        stashWeight = 120000,
        rebuildingGrant = 1200,
    },
    properties = {
        mirror_park_101 = {
            label = 'Mirror Park Apt 101',
            entryCoords = { x = 1262.4, y = -429.8, z = 69.8 },
            price = 90000,
            rent = 850,
            interiorType = 'apartment_small',
            neighborhood = 'mirror_park',
            territoryFaction = nil,
            metadata = { tier = 1, style = 'starter', storyNode = 'arrival' },
        },
        rancho_duplex_3 = {
            label = 'Rancho Duplex #3',
            entryCoords = { x = 495.0, y = -1823.5, z = 28.9 },
            price = 70000,
            rent = 700,
            interiorType = 'duplex_compact',
            neighborhood = 'rancho',
            territoryFaction = 'waterfront_collective',
            metadata = { tier = 1, style = 'industrial', storyNode = 'fault_lines' },
        },
        vinewood_hills_42 = {
            label = 'Vinewood Hills #42',
            entryCoords = { x = -716.8, y = 499.2, z = 109.3 },
            price = 185000,
            rent = 1500,
            interiorType = 'house_modern',
            neighborhood = 'vinewood_hills',
            territoryFaction = nil,
            metadata = { tier = 2, style = 'modern', storyNode = 'fault_lines' },
        },
    },
}
