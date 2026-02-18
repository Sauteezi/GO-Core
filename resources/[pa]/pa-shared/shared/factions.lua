--[[
Config Schema: factions.lua
- Register under PaSharedConfigRegistry.factions
- version (string): config revision.
- defaults (table)
  - maxMembers (number)
  - territoryStep (number): default influence shift per qualified action.
  - territoryMaxInfluence (number)
- factions (table<string, table>): keyed by faction id.
  - label (string)
  - type (string): gang/biker_club/syndicate/cartel/legal_org
  - maxMembers (number)
  - tags (array<string>)
  - ranks (table<string, table>)
    - order (number)
    - label (string)
    - permissions (array<string>)
  - territoryZones (array<table>) optional
    - key (string)
    - label (string)
    - center (vector3-like table x/y/z)
    - radius (number)
  - storage (table)
    - label (string)
    - slots (number)
    - weight (number)
  - frontBusinessKeys (array<string>): businesses eligible to be linked as faction fronts.
How to extend:
1) Keep `type` consistent so legal/criminal policy checks are predictable.
2) Add permissions to ranks instead of hardcoding role checks in feature resources.
3) Territory pressure is intentionally slow; prefer events over repetitive grind loops.
]]

PaSharedConfigRegistry = PaSharedConfigRegistry or {}

PaSharedConfigRegistry.factions = {
    version = '1.1.0',
    defaults = {
        maxMembers = 20,
        territoryStep = 1,
        territoryMaxInfluence = 100,
    },
    factions = {
        harbor_serpents = {
            label = 'Harbor Serpents MC',
            type = 'biker_club',
            maxMembers = 24,
            tags = { 'bikes', 'docks', 'smuggling' },
            ranks = {
                president = { order = 5, label = 'President', permissions = { '*', 'member_manage', 'front_manage' } },
                enforcer = { order = 4, label = 'Enforcer', permissions = { 'territory_push', 'funds_withdraw', 'storage_access', 'launder' } },
                rider = { order = 3, label = 'Rider', permissions = { 'territory_push', 'funds_deposit', 'storage_access', 'launder' } },
                prospect = { order = 1, label = 'Prospect', permissions = { 'storage_access' } },
            },
            territoryZones = {
                { key = 'dockyards', label = 'Dockyards', center = { x = 987.0, y = -3040.0, z = 5.9 }, radius = 180.0 },
            },
            storage = { label = 'Serpents Lockup', slots = 120, weight = 275000 },
            frontBusinessKeys = { 'dockside_auto', 'dusk_lounge' },
        },
        prism_collective = {
            label = 'Prism Collective',
            type = 'syndicate',
            maxMembers = 18,
            tags = { 'white_collar', 'laundering', 'brokerage' },
            ranks = {
                director = { order = 5, label = 'Director', permissions = { '*', 'member_manage', 'front_manage' } },
                broker = { order = 3, label = 'Broker', permissions = { 'territory_push', 'funds_withdraw', 'storage_access', 'launder' } },
                associate = { order = 2, label = 'Associate', permissions = { 'funds_deposit', 'storage_access', 'launder' } },
            },
            territoryZones = {
                { key = 'downtown', label = 'Downtown Financial', center = { x = -125.0, y = -638.0, z = 168.0 }, radius = 140.0 },
            },
            storage = { label = 'Prism Archive', slots = 90, weight = 200000 },
            frontBusinessKeys = { 'aurora_bistro', 'dusk_lounge' },
        },
        port_aurora_united = {
            label = 'Port Aurora United',
            type = 'legal_org',
            maxMembers = 32,
            tags = { 'union', 'workers', 'community' },
            ranks = {
                chair = { order = 4, label = 'Chair', permissions = { '*', 'member_manage', 'front_manage' } },
                delegate = { order = 3, label = 'Delegate', permissions = { 'territory_push', 'funds_withdraw', 'funds_deposit', 'storage_access' } },
                organizer = { order = 2, label = 'Organizer', permissions = { 'funds_deposit', 'storage_access', 'launder' } },
                member = { order = 1, label = 'Member', permissions = { 'storage_access' } },
            },
            territoryZones = {
                { key = 'industrial_park', label = 'Industrial Park', center = { x = 900.0, y = -2100.0, z = 30.0 }, radius = 180.0 },
            },
            storage = { label = 'Union Supply Room', slots = 100, weight = 220000 },
            frontBusinessKeys = { 'aurora_bistro' },
        },
        mar_de_sombra = {
            label = 'Mar de Sombra',
            type = 'cartel',
            maxMembers = 12,
            tags = { 'rare', 'high_risk', 'cross_border' },
            ranks = {
                patron = { order = 5, label = 'Patrón', permissions = { '*', 'member_manage', 'front_manage' } },
                operador = { order = 3, label = 'Operador', permissions = { 'territory_push', 'funds_withdraw', 'storage_access', 'launder' } },
                corredor = { order = 2, label = 'Corredor', permissions = { 'territory_push', 'funds_deposit', 'storage_access', 'launder' } },
            },
            territoryZones = {
                { key = 'east_port', label = 'East Port', center = { x = 1200.0, y = -3000.0, z = 5.5 }, radius = 160.0 },
            },
            storage = { label = 'Sombra Cache', slots = 70, weight = 180000 },
            frontBusinessKeys = { 'dockside_auto', 'sentinel_security' },
        },
    },
}
