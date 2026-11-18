# FRONTLINE INTELLIGENCE

A focused, responsive web application with two primary sections:

1. **Frontline** — a Leaflet map of the latest dated public territorial-control snapshot available from the DeepState Map data mirror. The upstream repository states that the dataset represents Russian-occupied territory and is updated daily around 03:00 UTC. The mapped polygon edge is an approximate contact boundary, not a verified tactical frontline or a live position feed.
2. **Arsenal** — a searchable reference catalogue of 43 publicly documented weapons and military systems, with individual profiles, broad specifications, source links, and simplified exploded-view component identification diagrams.

The schematic illustrations are original, generic category-adapted diagrams. They are not exact engineering drawings, not to scale, and do not provide manufacturing dimensions, assembly sequence, or operational procedures. Catalogue coverage is curated and not exhaustive; weapon variants and public claims change over time.

## Run locally

Requires Node.js 18+ (20 recommended). No npm packages are required.

```bash
npm run check
ADMIN_KEY='use-a-long-random-secret' npm start
```

Open `http://localhost:3000`. Health check: `http://localhost:3000/api/health`.

## Data sources and freshness

- **Territorial layer:** [DeepState Map data mirror](https://github.com/cyterat/deepstate-map-data), which documents dated GeoJSON snapshots of Russian-occupied territory and a daily update cadence. The app discovers the newest dated file from the repository's `data` directory and caches it for 15 minutes. The mirror is not the original DeepState Map service and the project is not affiliated with DeepState.
- **Basemap:** [OpenStreetMap](https://www.openstreetmap.org/copyright).
- **Weapons:** Source links are included per entry and should be consulted for current variant-specific specifications. Source licensing and redistribution permissions should be reviewed before commercial use.

If the upstream source or GitHub API is unavailable, the map displays a data-unavailable status rather than fabricating a current frontline. Users can open the original [DeepState Map](https://deepstatemap.live/en) directly.

## Render deployment

The included `render.yaml` is a Render Blueprint. Push this project directory to a GitHub repository, then in Render choose **New + → Blueprint** and select that repository. Render will create the web service, health check, generated `ADMIN_KEY`, and persistent data disk.

Alternatively create a Web Service manually:

- Runtime: Node
- Build command: `npm install`
- Start command: `npm start`
- Health check path: `/api/health`
- Environment variable: `ADMIN_KEY` (generate a long random value)
- Persistent disk mount: `/opt/render/project/src/data`

## API

- `GET /api/health` — service health
- `GET /api/frontline` — newest available dated territorial-control GeoJSON, source and freshness metadata
- `GET /api/weapons` — weapon catalogue
- `GET /api/public` — legacy public editorial data retained for compatibility
- `POST /api/admin/check`, `/api/admin/reports`, `/api/admin/annotations` — legacy editorial endpoints protected by `X-Admin-Key`

## Important limitations

- This is a public-reference product, not an official government or military service.
- Territorial-control geometry is sourced from a community mirror; it can lag, be revised, or be disputed. It is not live unit tracking and should not be used for navigation, safety decisions, targeting, or operational planning.
- The 43 weapon profiles are a curated initial catalogue, not a claim to include every weapon or variant used in the war.
- The current backend uses a simple JSON store for legacy editorial endpoints. It is suitable for a small pilot, not a multi-user production newsroom. A public commercial release should migrate that store to managed PostgreSQL, add account-based roles, audit logs, rate limits, automated backups, monitoring, and a documented editorial process.
- The web app is installable as a PWA on supported devices. Native App Store distribution requires a separate native wrapper and Apple developer review.
