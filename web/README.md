# SupaSupport Web

Marketing site + setup wizard + web ticket client for [supasupport.net](https://supasupport.net).

## Local dev

```bash
cd web
npm install
npm run dev
```

Open http://localhost:5173

## Build

```bash
npm run build
```

Output: `web/dist/`

## Deploy to Cloudflare Pages

1. In Cloudflare Dashboard → **Workers & Pages** → **Create** → **Pages** → **Connect to Git** (or direct upload).
2. Build settings:
   - **Root directory:** `web`
   - **Build command:** `npm ci && npm run build`
   - **Output directory:** `dist`
3. Add custom domain **supasupport.net** (and `www` CNAME if desired).
4. Or from CLI after `npx wrangler login`:

```bash
cd web
npm run deploy
```

## Routes

| Path | Purpose |
|------|---------|
| `/` | Landing page |
| `/setup` | 6-step Supabase setup wizard (full SQL + QR) |
| `/connect` | Paste connect JSON |
| `/login` | Sign in (after connect) |
| `/tickets` | Ticket list (authenticated) |

## Notes

- The wizard embeds `supabase/bootstrap.sql` from the repo at build time.
- Only the **anon / publishable** key belongs in connect JSON — never the service role key.
- Google OAuth redirect URL for web sign-in: `https://YOUR_PROJECT.supabase.co/auth/v1/callback` plus your site origin for the web app callback (`/auth/callback`).
