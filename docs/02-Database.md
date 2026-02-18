# 02 - Database

This project expects a server-authoritative data model.

## Basic guidance

- Treat the database as the source of truth for persistent player state.
- Never trust client-provided money/item/permission values.
- Write changes on the server and replicate validated state to clients.

## Suggested data domains

- Characters
- Accounts/balances
- Inventories
- Vehicles
- Properties/housing
- Jobs and progression
- Crime/legal records

## Schema and migrations

- Canonical schema file: `sql/pa_schema.sql`
- Includes starter rows for jobs and staff roles to help first boot.
- Uses `CREATE TABLE IF NOT EXISTS` plus indexes/foreign keys for common 128-player query paths.
- Includes generic `logs` table for structured logger output (`level`, `resource`, `message`, `meta`, `correlation_id`, `created_at`).

## Applying the schema

### Development / local bootstrap (safe mode)

1. Ensure `oxmysql` is running.
2. Ensure `pa-devtools` is running.
3. Run command: `/pa-devtools apply-schema`

This applies statements from `resources/[pa]/pa-devtools/sql/pa_schema.sql` in safe mode and stops on first error.

### Production recommendation

- **Do not rely on in-server auto-apply for production changes.**
- Apply `sql/pa_schema.sql` manually using your DB client and proper change control.
- Keep backups before running migrations.

## Best practices

- Use migrations for schema changes.
- Add indexes for frequent lookups.
- Log high-risk mutations through `pa-logging`.
- Keep DB access wrappers in `pa-core` or domain modules.


## Economy notes

`pa-economy` uses a ledger model with account types (`cash`, `bank`, `dirty`, optional `business`).
All balance mutations should write a `transactions` row including before/after balances in metadata.
