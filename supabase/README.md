# Supabase migrations

Apply migrations in filename order with the Supabase CLI or SQL Editor.

Current migration:

- `migrations/20260715033000_atomic_round_settlement.sql`

Rollback for that migration:

- `rollbacks/20260715033000_atomic_round_settlement.sql`

The Flutter client is backward compatible. Before the migration is applied it
uses the legacy conditional-update settlement path. After the migration is
visible to PostgREST it switches to `settle_game_round_v1` automatically.

Do not place service-role keys or database passwords in this repository.
