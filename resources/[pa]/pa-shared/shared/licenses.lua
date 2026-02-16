--[[
Config Schema: licenses.lua
- Register under PaSharedConfigRegistry.licenses
- version (string): config revision.
- defaults (table): shared license defaults.
  - renewable (boolean)
  - durationDays (number)
- licenses (table<string, table>): keyed by license id.
  - label (string)
  - issuingAuthority (string)
  - renewable (boolean)
  - durationDays (number)
How to extend:
1) Add licenses by domain (civilian, legal-role, business).
2) Keep IDs stable because player records will reference them.
]]

PaSharedConfigRegistry = PaSharedConfigRegistry or {}

PaSharedConfigRegistry.licenses = {
    version = '1.1.0',
    defaults = {
        renewable = true,
        durationDays = 365,
    },
    licenses = {
        drivers = {
            label = 'Driver License',
            issuingAuthority = 'Port Aurora DMV',
            renewable = true,
            durationDays = 365,
        },
        weapon = {
            label = 'Firearm License',
            issuingAuthority = 'Port Aurora DoJ',
            renewable = true,
            durationDays = 180,
        },
        commercial = {
            label = 'Commercial Operator License',
            issuingAuthority = 'Port Aurora Commerce Board',
            renewable = true,
            durationDays = 365,
        },

        business_restaurant = {
            label = 'Restaurant Business License',
            issuingAuthority = 'Port Aurora Commerce Board',
            renewable = true,
            durationDays = 365,
        },
        business_bar = {
            label = 'Bar Business License',
            issuingAuthority = 'Port Aurora Commerce Board',
            renewable = true,
            durationDays = 365,
        },
        business_mechanic = {
            label = 'Mechanic Business License',
            issuingAuthority = 'Port Aurora Commerce Board',
            renewable = true,
            durationDays = 365,
        },
        business_security = {
            label = 'Security Business License',
            issuingAuthority = 'Port Aurora Commerce Board',
            renewable = true,
            durationDays = 365,
        },
    },
}
