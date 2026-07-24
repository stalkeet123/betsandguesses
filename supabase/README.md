# Supabase migrations

Apply migrations in filename order with the Supabase CLI or SQL Editor.

## Party Mode

Apply these files in order before distributing a client that exposes Party
Mode:

1. `migrations/20260724090000_party_room_mode.sql`
2. `migrations/20260724100000_party_core_schema.sql`
3. `migrations/20260724110000_party_start_snapshot.sql`
4. `migrations/20260724120000_party_gameplay_commands.sql`
5. `migrations/20260724130000_party_settlement_rotation.sql`
6. `migrations/20260724140000_party_reset.sql`

Rollback files use the same timestamps and must be run in reverse order.

Party tables intentionally have no direct client policies or grants. The
Flutter client can only read phase-filtered snapshots and mutate state through
authenticated security-definer RPCs. Classic RPCs and Classic tables are not
replaced.

Do not place service-role keys or database passwords in this repository.
