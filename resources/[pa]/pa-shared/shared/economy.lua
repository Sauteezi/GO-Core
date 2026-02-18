--[[
Config Schema: economy.lua
- Register under PaSharedConfigRegistry.economy
- version (string): config revision.
- defaults (table): economy-level defaults.
  - currency (string)
  - payrollTaxRate (number)
  - minTransaction (number): lowest allowed absolute transaction amount.
  - maxTransaction (number): highest allowed absolute transaction amount.
- sinks (table<string, table>): recurring money sinks.
  - label (string)
  - type (string): fixed/percentage.
  - amount (number): interpreted by type.
  - cadenceHours (number): recurrence window.
  - account (string): preferred account target.
How to extend:
1) Add sinks before adding new faucet/reward systems.
2) Keep percentages as decimal values (0.05 = 5%).
3) Keep sink keys stable so balancing scripts can reference them.
]]

PaSharedConfigRegistry = PaSharedConfigRegistry or {}

PaSharedConfigRegistry.economy = {
    version = '1.2.0',
    defaults = {
        currency = 'USD',
        payrollTaxRate = 0.08,
        minTransaction = 1,
        maxTransaction = 250000,
    },
    sinks = {
        rent = {
            label = 'Housing Rent',
            type = 'fixed',
            amount = 1200,
            cadenceHours = 24,
            account = 'bank',
        },
        insurance = {
            label = 'Vehicle Insurance',
            type = 'fixed',
            amount = 450,
            cadenceHours = 168,
            account = 'bank',
        },
        repairs = {
            label = 'Repair Bills',
            type = 'fixed',
            amount = 300,
            cadenceHours = 24,
            account = 'cash',
        },
        hospital_bills = {
            label = 'Hospital Bills',
            type = 'fixed',
            amount = 650,
            cadenceHours = 24,
            account = 'bank',
        },
        licensing_fees = {
            label = 'Licensing Fees',
            type = 'fixed',
            amount = 500,
            cadenceHours = 168,
            account = 'bank',
        },

        business_license_fees = {
            label = 'Business License Fees',
            type = 'fixed',
            amount = 1200,
            cadenceHours = 720,
            account = 'bank',
        },
        business_taxes = {
            label = 'Business Taxes',
            type = 'percentage',
            amount = 0.03,
            cadenceHours = 168,
            account = 'business',
        },
    },
}
