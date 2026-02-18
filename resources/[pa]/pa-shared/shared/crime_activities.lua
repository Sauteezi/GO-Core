--[[
Config Schema: crime_activities.lua
- Register under PaSharedConfigRegistry.crime_activities
- modules (table<string, table>): per-activity module configuration.
  - cooldownSeconds (number)
  - requiredItem (string|nil)
  - rpHooks (table): optional RP interaction toggles/chances.
  - tiers (array<table>): progression tiers.
    - id (string)
    - label (string)
    - minLicense (string|nil)
    - minReputation (number)
    - minFactionRank (number)
    - heatDelta (number)
    - payoutDirtyMin (number)
    - payoutDirtyMax (number)
    - evidenceChance (number)
How to extend:
1) Add/adjust tiers here for quick balancing.
2) Keep payout/heat values conservative and raise slowly.
3) Use minReputation + minFactionRank for non-grindy progression gates.
]]

PaSharedConfigRegistry = PaSharedConfigRegistry or {}

PaSharedConfigRegistry.crime_activities = {
    version = '1.0.0',
    modules = {
        robbery_stores = {
            cooldownSeconds = 300,
            requiredItem = 'lockpick',
            rpHooks = { hostages = true, negotiator = true, informantChance = 0.12 },
            tiers = {
                { id = 'corner', label = 'Corner Store', minLicense = nil, minReputation = 0, minFactionRank = 0, heatDelta = 8, payoutDirtyMin = 450, payoutDirtyMax = 900, evidenceChance = 0.25 },
                { id = 'chain', label = 'Chain Market', minLicense = nil, minReputation = 25, minFactionRank = 1, heatDelta = 11, payoutDirtyMin = 850, payoutDirtyMax = 1600, evidenceChance = 0.30 },
            },
        },
        robbery_houses = {
            cooldownSeconds = 480,
            requiredItem = 'lockpick',
            rpHooks = { hostages = false, negotiator = false, fences = true, informantChance = 0.10 },
            tiers = {
                { id = 'suburban', label = 'Suburban House', minLicense = nil, minReputation = 20, minFactionRank = 0, heatDelta = 10, payoutDirtyMin = 900, payoutDirtyMax = 1700, evidenceChance = 0.28 },
                { id = 'estate', label = 'Luxury Estate', minLicense = nil, minReputation = 60, minFactionRank = 2, heatDelta = 14, payoutDirtyMin = 1800, payoutDirtyMax = 3200, evidenceChance = 0.35 },
            },
        },
        boosting = {
            cooldownSeconds = 600,
            requiredItem = 'radio',
            rpHooks = { chopShops = true, fences = true, informantChance = 0.14 },
            tiers = {
                { id = 'd', label = 'D-Class Boost', minLicense = 'driver', minReputation = 35, minFactionRank = 1, heatDelta = 12, payoutDirtyMin = 1600, payoutDirtyMax = 2800, evidenceChance = 0.30 },
                { id = 'b', label = 'B-Class Boost', minLicense = 'driver', minReputation = 85, minFactionRank = 2, heatDelta = 18, payoutDirtyMin = 3200, payoutDirtyMax = 5200, evidenceChance = 0.38 },
            },
        },
        drugs = {
            cooldownSeconds = 420,
            requiredItem = nil,
            rpHooks = { fences = true, informantChance = 0.18 },
            tiers = {
                { id = 'street', label = 'Street Batch', minLicense = nil, minReputation = 15, minFactionRank = 0, heatDelta = 9, payoutDirtyMin = 700, payoutDirtyMax = 1400, evidenceChance = 0.23 },
                { id = 'network', label = 'Distribution Network', minLicense = 'business_bar', minReputation = 90, minFactionRank = 2, heatDelta = 16, payoutDirtyMin = 3000, payoutDirtyMax = 5600, evidenceChance = 0.34 },
            },
        },
        heists = {
            cooldownSeconds = 1200,
            requiredItem = 'radio',
            rpHooks = { hostages = true, negotiator = true, fences = true, chopShops = true, informantChance = 0.22 },
            tiers = {
                { id = 'bank_annex', label = 'Bank Annex', minLicense = nil, minReputation = 120, minFactionRank = 2, heatDelta = 20, payoutDirtyMin = 6000, payoutDirtyMax = 10500, evidenceChance = 0.42 },
                { id = 'vault', label = 'City Vault Job', minLicense = nil, minReputation = 200, minFactionRank = 3, heatDelta = 30, payoutDirtyMin = 12000, payoutDirtyMax = 22000, evidenceChance = 0.55 },
            },
        },
    },
}
