--[[
Config Schema: businesses.lua
- Register under PaSharedConfigRegistry.businesses
- businesses (table<string, table>)
  - label (string)
  - type (string): restaurant/bar/mechanic/security/other
  - license (string)
  - licenseFee (number)
  - startingBalance (number)
  - payroll (table): role->salary
  - serviceDiscounts (table): serviceType->percentage discount
  - production (table): recipe definitions for simple outputs
]]

PaSharedConfigRegistry = PaSharedConfigRegistry or {}

PaSharedConfigRegistry.businesses = {
    version = '1.0.0',
    businesses = {
        aurora_bistro = {
            label = 'Aurora Bistro',
            type = 'restaurant',
            license = 'business_restaurant',
            licenseFee = 1200,
            startingBalance = 2500,
            payroll = { owner = 0, manager = 350, employee = 250 },
            serviceDiscounts = {},
            production = {
                meal_combo = { outputItem = 'sandwich', outputCount = 2 },
            },
        },
        dusk_lounge = {
            label = 'Dusk Lounge',
            type = 'bar',
            license = 'business_bar',
            licenseFee = 1100,
            startingBalance = 2200,
            payroll = { owner = 0, manager = 340, employee = 240 },
            serviceDiscounts = {},
            production = {
                drink_batch = { outputItem = 'water_bottle', outputCount = 3 },
            },
        },
        dockside_auto = {
            label = 'Dockside Auto',
            type = 'mechanic',
            license = 'business_mechanic',
            licenseFee = 1500,
            startingBalance = 3000,
            payroll = { owner = 0, manager = 420, employee = 300 },
            serviceDiscounts = {
                repairs = 0.2,
            },
            production = {},
        },
        sentinel_security = {
            label = 'Sentinel Security',
            type = 'security',
            license = 'business_security',
            licenseFee = 1700,
            startingBalance = 2800,
            payroll = { owner = 0, manager = 430, employee = 320 },
            serviceDiscounts = {},
            production = {},
        },
    },
}
