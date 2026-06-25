# FBCVR Tickets — Web

Web companion for the FBCVR Tickets iOS app. Uses the **same Supabase project** as mobile.

- **Production URL:** https://fbcvr.support
- **Privacy Policy:** https://fbcvr.support/privacy

## Free hosting (recommended): Cloudflare Pages

Cloudflare Pages is free and works well with custom domains like `fbcvr.support`.

### 1. Prepare environment variables

Copy `web/.env.example` to `web/.env.local` for local dev:

```bash
cd web
cp .env.example .env.local
```

Set:

- `VITE_SUPABASE_URL` — your Supabase project URL
- `VITE_SUPABASE_ANON_KEY` — your Supabase publishable/anon key (same as iOS `AppConfig`)

### 2. Configure Supabase Auth URLs

Supabase Dashboard → **Authentication → URL Configuration**

| Setting | Value |
|---------|--------|
| **Site URL** | `https://fbcvr.support` |
| **Redirect URLs** | `https://fbcvr.support/auth/callback` |
| | `http://localhost:5173/auth/callback` |

### 3. Configure Google OAuth (if not already)

Google Cloud Console → your **Web OAuth client**:

**Authorized JavaScript origins**

- `https://fbcvr.support`
- `http://localhost:5173`

**Authorized redirect URIs**

- `https://atgrgtkbwfcxvibgkqla.supabase.co/auth/v1/callback`
- (Supabase handles the OAuth callback; your app uses `/auth/callback` after Supabase redirects back)

Ensure the Web client ID is listed in **Supabase → Auth → Google**.

### 4. Deploy to Cloudflare Pages

1. Push this repo to GitHub (if not already)
2. [Cloudflare Dashboard](https://dash.cloudflare.com) → **Workers & Pages → Create → Pages → Connect to Git**
3. Select the repo
4. Build settings — use **one** of these options:

**Option A (recommended): set root directory to `web`**

| Setting | Value |
|---------|--------|
| **Root directory** | `web` |
| **Build command** | `npm ci && npm run build` |
| **Build output directory** | `dist` |

**Option B: build from repo root (if Root directory must stay blank)**

| Setting | Value |
|---------|--------|
| **Root directory** | *(leave empty)* |
| **Build command** | `bash build-web.sh` |
| **Build output directory** | `web/dist` |

If you see `npm ci` / `package-lock.json` errors, Cloudflare is building from the wrong folder — use one of the configs above.

Cloudflare uses `web/wrangler.toml` for SPA routing (`/privacy`, `/tickets`, etc.). Do **not** add a `public/_redirects` file — it causes an infinite-loop error with Wrangler.

If your deploy command is `npx wrangler deploy`, run it from the `web` directory after the build.

5. **Environment variables — you do not need Worker variables**

This project deploys as **static assets only** (HTML/JS/CSS). Cloudflare will show:

> *Variables cannot be added to a Worker that only has static assets.*

That is expected. **Ignore Worker environment variables.**

Supabase URL and publishable key are already baked into `web/src/lib/config.ts` (same public values as the iOS app). No Cloudflare secrets are required for the site to load.

Optional: for local dev only, copy `web/.env.example` → `web/.env.local`.

If you ever need build-time overrides, add them under **Build configuration → Environment variables** (the build step), not under Worker settings. Then redeploy.

6. Deploy

### 5. Connect `fbcvr.support`

If the domain is already on Cloudflare:

1. Pages project → **Custom domains → Set up a custom domain**
2. Enter `fbcvr.support`
3. Cloudflare adds the DNS record automatically

If the domain is elsewhere, point a `CNAME` for `@` or `www` to your `*.pages.dev` hostname (Cloudflare will show exact instructions).

---

## Local development

```bash
cd web
npm install
npm run dev
```

Open http://localhost:5173

---

## App Store privacy policy URL

Use this in App Store Connect:

**https://fbcvr.support/privacy**

---

## Features (v1)

- Google sign-in (same allowlist as mobile: `@fbcvr.com` + approved test accounts)
- Ticket list (user sees own; admin sees all)
- Create ticket with optional image/video attachments
- Ticket thread with replies
- Admin status actions (Complete / Out of Scope / Reopen)
- Public privacy policy page

---

## Alternative free hosts

| Host | Notes |
|------|--------|
| **Cloudflare Pages** | Recommended — free, fast, custom domain |
| **Vercel** | Also free; connect `web` as root, same build settings |
| **Netlify** | Same idea; `public/_redirects` handles SPA routing |

---

## Project structure

```
web/
  src/
    lib/          Supabase + auth + ticket API
    pages/        Login, tickets, privacy, etc.
    components/   Layout, badges, route guard
  public/
    _redirects    SPA fallback for Cloudflare/Netlify
```

Build output is static files only — no server to maintain.
