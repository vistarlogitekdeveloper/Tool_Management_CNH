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

## Building

```bash
flutter build web     --release --dart-define=API_BASE_URL=https://your-api/api/v1
flutter build apk     --release --dart-define=API_BASE_URL=https://your-api/api/v1
flutter build windows --release --dart-define=API_BASE_URL=https://your-api/api/v1
```

The web build is a static bundle in `build/web` — serve it with any web server.

## Deploying to Cloudflare Pages

This repository includes a GitHub Actions workflow at `.github/workflows/deploy-cloudflare-pages.yml`.
It builds the Flutter web release and deploys `build/web` to Cloudflare Pages whenever `main` changes.

1. Create a Cloudflare Pages project. Keep the project name for the `CLOUDFLARE_PAGES_PROJECT` variable.
2. Create a Cloudflare API token with permission to edit Pages projects, then add it to the repository as the `CLOUDFLARE_API_TOKEN` secret.
3. Add the Cloudflare account ID as the `CLOUDFLARE_ACCOUNT_ID` repository secret.
4. Add `CLOUDFLARE_PAGES_PROJECT` as a repository variable with the Pages project name.
5. Add `API_BASE_URL` as a repository variable with the deployed backend URL, for example `https://api.example.com/api/v1`.
6. Push to `main`, or run the `Deploy Flutter web to Cloudflare Pages` workflow manually.

The backend must allow requests from the Cloudflare Pages domain through CORS. Because `API_BASE_URL` is compiled into the web bundle, changing it requires another deployment.

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
