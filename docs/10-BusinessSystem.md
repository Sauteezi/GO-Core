# 10 - Business system (player-run economy glue)

`pa-business` connects player-run organizations with invoices, payroll, business balances, and production.

## Core features
- Business registry loaded from `pa-shared/shared/businesses.lua`
- Roles per business: `owner`, `manager`, `employee`
- Internal business bank balance and payroll spending
- Invoice + receipt flow with explicit statuses
- Recipe-based production for restaurants/bars

## Money movement and logging
- Invoice payments use `PaEconomy:TransferMoney`
- Payroll uses `PaEconomy:AddMoney`
- Business license payments use `PaEconomy:RemoveMoney`
- Every invoice payment is logged via `PaLogging:LogEconomy`

## Civilian impact hooks
- Restaurants/bars can trigger meal effects (`pa:hud:businessMeal`) to reduce stress and restore needs.
- Mechanics expose service discount hooks (`PaBusiness:GetServiceDiscount`).
- Security firms can be hired for events (`pa:business:hireSecurity`, story hook event emitted).

## Configurable sinks
- `business_license_fees` and `business_taxes` are configured in `pa-shared/shared/economy.lua`.
- Business license requirements are defined in `pa-shared/shared/licenses.lua`.
