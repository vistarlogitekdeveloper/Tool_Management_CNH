# CNH TMS — Tool Management System (Flutter client)

The client application for the CNH Pune Plant Tool Management System. One Flutter
codebase covering the full tool lifecycle — master data, stock, issue and return,
tracking, calibration, repair and scrap, purchase and reporting — targeting **web,
Android, iOS and Windows**.

> **This repository is the frontend only.**
> It is a client for the TMS REST API, which lives separately. The app builds and
> runs without it, but stops at the sign-in screen until an API is reachable.

---

## Requirements

| | |
|---|---|
| Flutter | 3.9 or newer (Dart SDK `^3.9.0`) |
| Backend | A reachable TMS API — see [Configuration](#configuration) |

```bash
flutter --version
flutter pub get
```

## Configuration

The API base URL is a **build-time** constant, not a runtime setting, so each build
is pinned to its environment. Pass it with `--dart-define`:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api/v1
```

It defaults to `http://localhost:4000/api/v1` when omitted. Everything else —
plant name, currency, approval thresholds, calibration windows, which alerts fire —
is served by the API from its settings table, so the client needs no rebuild when
the plant changes a rule.

## Running

```bash
flutter run -d chrome     --dart-define=API_BASE_URL=http://localhost:4000/api/v1
flutter run -d windows    --dart-define=API_BASE_URL=http://localhost:4000/api/v1
flutter run -d android    --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1   # emulator host
```

## Demo sign-ins

Seeding the backend (`npm run seed`) creates one account per role profile. The
password for all four is `Tms@2026`, taken from the backend's `SEED_PASSWORD`
environment variable — set that before seeding to use a different one.

| Username | Password | Role | Sees |
|---|---|---|---|
| `rahul.k` | `Tms@2026` | Administrator | All nine modules, plus Administration |
| `sunil.k` | `Tms@2026` | Store Keeper | Tool Master, Inventory, Issue & Return, Tracking, Purchase |
| `sneha.p` | `Tms@2026` | Quality Engineer | Calibration, Repair & Scrap, Reports |
| `prakash.r` | `Tms@2026` | Operator | Issue & Return, Tracking |

The role decides which modules appear and which actions are permitted; signing in
as each is the quickest way to see the permission model working.

> **These are demo accounts, and this README is public.** They exist only where
> the seeder has been run. Change the password, or disable the accounts, on any
> deployment reachable from the internet — `rahul.k` holds every permission in
> the system. Administration → Users can reset a password or deactivate a user,
> and an administrator reset forces a change at next sign-in.

## Building

```bash
flutter build web     --release --dart-define=API_BASE_URL=https://your-api/api/v1
flutter build apk     --release --dart-define=API_BASE_URL=https://your-api/api/v1
flutter build windows --release --dart-define=API_BASE_URL=https://your-api/api/v1
```

The web build is a static bundle in `build/web` — serve it with any web server.

## Deploying to Cloudflare

The web build is deployed as a **Cloudflare Worker serving static assets**
(`wrangler.toml`), published by the GitHub Actions workflow at
`.github/workflows/deploy-cloudflare-workers.yml` on every push to `main`.

> **The build must run in GitHub Actions, not on Cloudflare.** Cloudflare's build
> image has no Flutter SDK, so a dashboard-connected Git build cannot produce
> `build/web`. It publishes the unbuilt `web/` source instead — an `index.html`
> still holding the literal `$FLUTTER_BASE_HREF` placeholder, with no
> `main.dart.js` and no assets. The site loads as a blank white page.
>
> If the Worker is currently connected to this repository through the Cloudflare
> dashboard, **disconnect that Git integration**, or it will keep overwriting
> each good deployment with the source tree.

Setup:

1. Create a Cloudflare API token with permission to edit Workers, and add it to
   the repository as the `CLOUDFLARE_API_TOKEN` secret.
2. Add the Cloudflare account ID as the `CLOUDFLARE_ACCOUNT_ID` secret.
3. Optionally set an `API_BASE_URL` repository *variable* to override the
   default backend URL compiled into the bundle.
4. Push to `main`, or run the workflow manually.

The worker name (`tool-management-cnh`) and the asset directory (`build/web`)
live in `wrangler.toml`. The workflow refuses to publish a bundle that is missing
`main.dart.js` or still contains the base-href placeholder, so the blank-page
failure cannot reach production again silently.

Cache rules are in `web/_headers`, copied into the bundle by the build:
`index.html`, the service worker and `version.json` are never stored, because
each one names the versioned assets and a cached copy pins the browser to the
previous build. Hashed assets are cached for a year.

### Building on Cloudflare instead

If you would rather keep the Cloudflare dashboard's Git integration than move to
Actions, point its **build command** at the bundled script, which installs the
Flutter SDK into the build container first:

```
Build command:   bash scripts/cloudflare-build.sh
Deploy command:  npx wrangler deploy
```

Without a build command, Cloudflare clones the repository and runs
`wrangler deploy` straight away; `build/web` does not exist and the deploy fails.
This is the slower of the two routes — the SDK is re-downloaded on every build —
so prefer Actions unless adding the two repository secrets is awkward.

Run one or the other, not both, or the two will race to publish the same Worker.

The backend must allow the Worker's origin through CORS. Because `API_BASE_URL`
is compiled into the web bundle, changing it requires another deployment.

## Tests

```bash
flutter analyze   # static analysis
flutter test      # unit tests
```

Covers session and token storage (including the guarantee that an unreachable
platform keystore degrades to a session-only login rather than falling back to
plaintext) and the attachment upload/download contract.

## Layout

```
lib/
  core/
    config/      build-time config (--dart-define)
    network/     ApiClient — bearer injection, silent refresh, envelope unwrap
    storage/     session persistence; tokens in the platform secure store
    router/      routes + role-aware redirects
    theme/       colours, spacing, typography
    widgets/     design system — cards, data grid, dialogs, form fields, charts
    utils/       formatters (en_IN), responsive helpers, downloads
  models/        typed API models with defensive parsing
  features/
    <module>/
      data/          repository + Riverpod providers
      presentation/  screens and dialogs
```

## Modules

Dashboard · Tool Master · Inventory · Issue & Return · Tool Tracking ·
Calibration · Repair & Scrap · Purchase · Reports, plus Administration.

The signed-in user's role decides which appear — the sidebar, the routes and every
action button read the same permission list returned by the API. **UI gating is
convenience only; the server enforces the same rules on every request.**

## Notes on the build

- **State** — Riverpod; **routing** — `go_router` with role-aware redirects.
- **Networking** — Dio behind a thin `ApiClient` that injects the bearer token,
  refreshes silently on a 401, and unwraps the API's `{ success, data, meta }`
  envelope so screens never see it.
- **Session** — the token pair is held in the platform secure store (Keychain,
  the Keystore-backed Android store, DPAPI, libsecret), read once before the first
  frame and cached in memory because the request interceptor reads it synchronously.
- **Parsing** — every model goes through defensive readers, so a nullable column or
  an added field cannot crash a shop-floor tablet mid-shift.
- **Responsive** — every data grid falls back to a stacked card list below 720px and
  dialogs become bottom sheets, so the same build works on a phone at the machine.

---

Built by **Vistarlogitek**.
