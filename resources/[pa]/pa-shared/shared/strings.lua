--[[
Config Schema: strings.lua
- Register under PaSharedConfigRegistry.strings
- version (string): config revision.
- locale (string): default language code.
- strings (table<string, string>): localization keys and values.
How to extend:
1) Add stable, dot-notated keys (domain.action.state).
2) Keep player-facing copy concise and roleplay-appropriate.
]]

PaSharedConfigRegistry = PaSharedConfigRegistry or {}

PaSharedConfigRegistry.strings = {
    version = '1.0.0',
    locale = 'en-US',
    strings = {
        ['core.welcome'] = 'Welcome to Port Aurora.',
        ['jobs.duty.on'] = 'You are now on duty.',
        ['jobs.duty.off'] = 'You are now off duty.',
        ['economy.transaction.failed'] = 'Transaction failed. Please contact staff if this persists.',
        ['inventory.item.missing'] = 'You do not have the required item.',
    },
}
