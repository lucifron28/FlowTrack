# Supabase MCP

Supabase is optional and future-facing for FlowTrack. It must not be required for owner login, inventory, sales, credits, expenses, dashboard, reports, or settings.

## Current Status

- `supabase_flutter` is installed.
- `Supabase.initialize` is not called during app startup.
- Supabase credentials are not required to run the offline MVP.
- No service role key is present in Flutter client code.
- `sync_queue` is only a local placeholder table.

## Setup Steps For Owner

1. Create a Supabase account.
2. Create a project.
3. Copy the project URL.
4. Copy the anon/public key.
5. Keep the service role key private.
6. Connect Supabase MCP.
7. Confirm MCP tools are available.

## What MCP May Do After Approval

- Inspect the Supabase project.
- Create migrations that mirror local tables.
- Add future sync fields such as `local_id`, `created_at`, `updated_at`, `deleted_at`, `sync_status`, and `device_id`.
- Enable RLS on exposed tables.
- Create policies matching the approved access model.
- Document all SQL and migrations.

## What MCP Must Not Do Without Approval

- Make destructive changes.
- Delete or overwrite data.
- Add multi-device sync behavior.
- Expose service role keys to Flutter.
- Make Supabase Auth required for offline login.
- Change the local-first source-of-truth rule.
