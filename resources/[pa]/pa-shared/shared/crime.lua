--[[
Config Schema: crime.lua
- Register under PaSharedConfigRegistry.crime
- version (string): config revision.
- heat (table): how heat is applied and decays.
  - maxHeat (number): upper clamp for active heat.
  - decayIntervalSeconds (number): tick frequency for decay.
  - decayPerTick (number): heat reduced every decay tick.
  - eventCooldownMs (number): default cooldown per illegal action key.
- evidence (table)
  - defaultChance (number): 0.0-1.0 evidence creation chance.
  - caseEvidenceThreshold (number): auto case escalation threshold.
  - warrantThreshold (number): warrant recommendation threshold.
- laundering (table)
  - minAmount (number)
  - maxAmount (number)
  - feePercent (number): percent fee taken from dirty amount.
  - riskHeatMultiplier (number): heat added per laundering amount chunk.
How to extend:
1) Keep event keys stable so balancing logs are easy to compare.
2) Tune heat decay first before changing evidence thresholds.
3) Keep laundering fees in sync with docs and economy tuning.
]]

PaSharedConfigRegistry = PaSharedConfigRegistry or {}

PaSharedConfigRegistry.crime = {
    version = '1.0.0',
    heat = {
        maxHeat = 200,
        decayIntervalSeconds = 120,
        decayPerTick = 2,
        eventCooldownMs = 30000,
    },
    evidence = {
        defaultChance = 0.25,
        caseEvidenceThreshold = 45,
        warrantThreshold = 70,
    },
    laundering = {
        minAmount = 250,
        maxAmount = 50000,
        feePercent = 0.15,
        riskHeatMultiplier = 1.0,
    },
}
