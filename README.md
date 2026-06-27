# SupaSupport

Multi-tenant helpdesk: iOS app + [supasupport.net](https://supasupport.net) setup wizard. Each organization runs its own Supabase project.

## Cloudflare Pages

**Option A — build from repo root (easiest):**

| Setting | Value |
|---------|--------|
| Root directory | *(leave empty)* |
| Build command | `npm run build` |
| Output directory | `web/dist` |

**Option B — build from `web/` folder:**

| Setting | Value |
|---------|--------|
| Root directory | `web` |
| Build command | `npm ci && npm run build` |
| Output directory | `dist` |

## Local dev

```bash
cd web && npm install && npm run dev
```

See [GETTING_STARTED.md](./GETTING_STARTED.md) and [web/README.md](./web/README.md).
