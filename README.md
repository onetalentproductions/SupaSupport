# SupaSupport

**Supabase-backed support ticketing** — each organization runs its own Supabase project. The iOS app connects via **QR code** (no central registry, no slugs).

Original FBCVR project is unchanged at `../FBCVRTickets`.

## Architecture

- **Connect**: Admin shares a JSON QR / link encoding `{ url, key, invite? }`
- **Auth**: Google or Sign in with Apple against *their* Supabase
- **Access**: Invite token, pre-added email, or optional domain rule (in SQL)
- **Departments**: Configurable per org (1 = hidden picker, 2 = toggle, 3+ = menu)

## New Supabase project (greenfield)

1. Create a free [Supabase](https://supabase.com) project
2. Run `supabase/bootstrap.sql` in SQL Editor
3. Create Storage bucket **`ticket-media`** (public read if you want attachment URLs)
4. Enable Google + Apple auth; add OAuth redirect URLs for web
5. Bootstrap first admin:

```sql
INSERT INTO pending_members (email, role, department_slugs)
VALUES ('you@example.com', 'admin', ARRAY['media','facilities']);
```

6. Generate a connect payload (admin app → Add User → invite, or manually):

```json
{"v":1,"name":"My Org","url":"https://YOUR.ref.supabase.co","key":"YOUR_ANON_KEY","invite":"OPTIONAL_TOKEN","bucket":"ticket-media"}
```

7. Open **SupaSupport** iOS → Scan QR or paste JSON → Sign in

## Migrate existing FBCVR Supabase

Run `supabase/migrate_fbcvr_to_supasupport.sql` on your existing project, then verify members:

```sql
INSERT INTO org_members (user_id, email, role, department_slugs)
SELECT id, email, 'admin', ARRAY['media','facilities']
FROM auth.users WHERE lower(email) IN (
  'austinsmith@fbcvr.com','zack@fbcvr.com','sonya@fbcvr.com','hunter@fbcvr.com','onetalentproductions@gmail.com'
)
ON CONFLICT (user_id) DO NOTHING;
```

Generate connect JSON with your existing URL + anon key.

## Apple App Review

Include a **review connect QR** in App Review notes:

1. Create a demo Supabase project with `bootstrap.sql`
2. Add `pending_members` for `fbcvrtickets.review@gmail.com`
3. Generate invite JSON with review token
4. Attach QR screenshot + paste JSON in review notes

## iOS

- Open `FBCVRTickets.xcodeproj` in Xcode (folder name legacy; app displays **SupaSupport**)
- Bundle ID: `com.onetalentproductions.SupaSupport`
- Register new App ID + provisioning for SupaSupport

## Web (supasupport.net)

- `/setup` — bootstrap SQL helper
- `/connect` — paste connect JSON
