# SupaSupport

Multi-tenant helpdesk: iOS app + [supasupport.net](https://supasupport.net) setup wizard. Each organization runs its own Supabase project.

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
