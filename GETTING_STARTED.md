# SupaSupport — Getting started

Your **FBCVRTickets** project is unchanged. This is the new public multi-tenant app.

## App icons

| Asset | Purpose |
|-------|---------|
| `AppIcon.appiconset/AppIcon.png` | **Default** home screen icon — replace with your SupaSupport artwork (1024×1024) |
| `AppIcon-fbcvr.appiconset/AppIcon-fbcvr.png` | **FBCVR** alternate icon (server `icon_key = fbcvr`) |
| `AppIcon-Default-Placeholder.appiconset/` | Reference copy only; edit `AppIcon.png` for the real default |

When a user connects to an org, the app reads `org_settings.icon_key` from their Supabase. If that key is bundled in this app version (e.g. `fbcvr`), the home screen icon switches. Otherwise it stays on the default.

To add a new client icon later: add `AppIcon-{key}.appiconset`, add `{key}` to `BrandIconService.bundledAlternateIconKeys`, add to `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in Xcode, ship an update.

---

## Step-by-step (do in order)

### 1. Apple Developer — new app ID

1. [developer.apple.com](https://developer.apple.com) → Identifiers → **+**
2. App ID: `com.onetalentproductions.SupaSupport`
3. Enable: Sign in with Apple, Push Notifications
4. Create provisioning (Xcode usually handles this)

### 2. Supabase — upgrade your FBCVR project

Open [SQL Editor](https://supabase.com/dashboard/project/atgrgtkbwfcxvibgkqla/sql) and run **`supabase/bootstrap.sql`** from this repo.

If you already have tickets tables, run table-by-table or use `migrate_fbcvr_to_supasupport.sql` first, then copy any missing functions from `bootstrap.sql`.

Set FBCVR branding:

```sql
UPDATE org_settings SET
  org_name = 'FBCVR',
  icon_key = 'fbcvr',
  access_mode = 'invite_only'
WHERE id = 1;
```

Ensure admins exist:

```sql
INSERT INTO org_members (user_id, email, role, department_slugs)
SELECT id, email, 'admin', ARRAY['media','facilities']
FROM auth.users WHERE lower(email) IN (
  'austinsmith@fbcvr.com','zack@fbcvr.com','sonya@fbcvr.com',
  'hunter@fbcvr.com','onetalentproductions@gmail.com'
)
ON CONFLICT (user_id) DO NOTHING;
```

Storage: bucket **`ticket-media`** (if not already).

### 3. Generate connect QR for staff

Replace `YOUR_ANON_KEY` with your Supabase publishable/anon key:

```json
{"v":1,"name":"FBCVR","url":"https://atgrgtkbwfcxvibgkqla.supabase.co","key":"YOUR_ANON_KEY","bucket":"ticket-media"}
```

Paste into any QR generator. Staff scan → sign in.

For Apple Review later: create invite with `pending_members` for review email + invite token in JSON.

### 4. Xcode — SupaSupport

1. Open **`/Users/austin-ip/Documents/Code/SupaSupport/FBCVRTickets.xcodeproj`**
2. Replace **`AppIcon.appiconset/AppIcon.png`** with your default SupaSupport icon (1024×1024)
3. Confirm **`AppIcon-fbcvr.png`** looks right (currently copied from FBCVR logo)
4. Team: **245U359959**, bundle **com.onetalentproductions.SupaSupport**
5. Build & run on a **physical iPhone**
6. Scan FBCVR connect QR → sign in → icon should switch to FBCVR (iOS may show a one-time alert)

### 5. Google / Apple auth

Same Supabase project — ensure Google OAuth client IDs include iOS + Web, Apple Sign In enabled. Google **Web client ID** is already in `AppConfig.swift`.

### 6. Domain (when ready)

Register **supasupport.net** → Cloudflare → Pages from `web/` folder. Setup wizard: `/setup`, connect: `/connect`.

### 7. App Store (when ready)

- New listing **SupaSupport** (not FBCVR Tickets)
- Review notes: demo connect QR + test account
- Encryption: exempt (HTTPS only)

---

## Repo location

```
/Users/austin-ip/Documents/Code/SupaSupport
```

Git: initial commit on `main`. Push to GitHub when you want a remote.

---

## What not to do yet

- Don’t change **FBCVRTickets** bundle / App Store listing for this — SupaSupport is a separate app
- Don’t worry about push on SupaSupport until core connect + tickets work
- Monthly client icons: batch new `AppIcon-{key}` sets when you’re ready
