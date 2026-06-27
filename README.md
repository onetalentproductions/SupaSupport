# SupaSupport

Multi-tenant helpdesk: iOS app + [supasupport.net](https://supasupport.net) setup wizard. Each organization runs its own Supabase project.

## Cloudflare secrets (instant sign-in credentials)

In **Workers & Pages → supasupport → Settings → Variables and secrets**, add:

| Secret | Purpose |
|--------|---------|
| `GOOGLE_OAUTH_CLIENT_ID` | Web OAuth client from your Google Cloud project |
| `GOOGLE_OAUTH_CLIENT_SECRET` | Matching client secret |
| `APPLE_SERVICES_ID` | Optional — Apple Sign In for iOS |
| `APPLE_TEAM_ID` | Optional |
| `APPLE_KEY_ID` | Optional |
| `APPLE_PRIVATE_KEY` | Optional — full `.p8` contents |

The setup wizard calls `/api/oauth-config` and returns these for copy-paste into Supabase Auth. **Web sign-in** uses email magic link; **iOS** uses the shared Google/Apple values (native sign-in — no redirect URI per customer).

## Cloudflare (Workers + static assets)

The repo includes `wrangler.jsonc` at the root. It deploys **built** files from `web/dist` only (never `web/node_modules`).

| Setting | Value |
|---------|--------|
| **Build command** | `npm run build && npx wrangler deploy` |
| **Root directory** | *(empty — repo root)* |

Or run locally after `npm install` at repo root:

```bash
npm run deploy
```

**Do not** point Wrangler assets at `web/` — that folder contains `node_modules` and will fail the 25 MiB asset limit.

### Cloudflare Pages (alternative)

| Root directory | Build command | Output |
|----------------|---------------|--------|
| *(empty)* | `npm run build` | `web/dist` |

See [GETTING_STARTED.md](./GETTING_STARTED.md) and [web/README.md](./web/README.md).
