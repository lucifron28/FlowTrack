# Supabase MCP

Supabase is not part of the offline MVP runtime. It is installed for future optional backup, cloud schema preparation, or sync only after approval.

## Current Status

- `supabase_flutter` is listed in project dependencies.
- `Supabase.initialize` is not called during app startup.
- Supabase credentials are not required to run the app.
- No Supabase service role key is present in Flutter client code.
- No cloud sync is implemented.
- `sync_queue` is a local placeholder table only.

## Owner Setup Required Before MCP Work

1. Create a Supabase account.
2. Create a Supabase project.
3. Copy the project URL.
4. Copy the anon/public key.
5. Keep the service role key private.
6. Connect Supabase MCP.
7. Confirm MCP tools are connected.

## Allowed MCP Work After Approval

- Inspect the Supabase project.
- Create non-destructive migrations that mirror the local schema.
- Add approved future-sync columns such as `local_id`, `created_at`, `updated_at`, `deleted_at`, `sync_status`, and `device_id`.
- Enable row-level security.
- Create policies for the approved access model.
- Document all SQL and migrations.

## Not Allowed Without Approval

- Destructive schema changes.
- Data deletion.
- Cloud sync implementation.
- Multi-device behavior.
- Supabase Auth as required offline login.
- Service role keys in Flutter code.
- Any change that makes Supabase required for local inventory, sales, credits, expenses, dashboard, or reports.
