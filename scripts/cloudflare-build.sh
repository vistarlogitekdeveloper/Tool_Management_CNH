#!/usr/bin/env bash
#
# Build the Flutter web bundle for a Cloudflare deploy.
#
# Invoked by wrangler itself through the [build] block in wrangler.toml, so it
# runs on every `wrangler deploy` — from Cloudflare's Git integration, from
# GitHub Actions, or from a laptop — and the deploy never depends on a build
# step being configured correctly somewhere else.
#
# Cloudflare's build image ships Node, Python, Go and friends but no Flutter
# SDK, so this installs one when it has to.

set -euo pipefail

FLUTTER_VERSION="3.35.0"
FLUTTER_DIR="${HOME}/flutter"
API_BASE_URL="${API_BASE_URL:-https://uat-api.vistarlogitek.com/api/v1/tool-management}"

# Nothing tracked in git produces build/, so a bundle here can only have been
# built moments ago by this same job — the Actions workflow builds before it
# calls wrangler. Reusing it saves re-running a three-minute compile; a fresh
# clone (Cloudflare) has no build/web and falls through to the real build.
if [ -f build/web/main.dart.js ] && ! grep -q 'FLUTTER_BASE_HREF' build/web/index.html; then
  echo "==> Bundle already built this run, reusing it"
  exit 0
fi

if command -v flutter >/dev/null 2>&1; then
  echo "==> Using the Flutter already on PATH: $(command -v flutter)"
else
  if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
    echo "==> Installing Flutter ${FLUTTER_VERSION}"
    curl -fsSL --retry 3 -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
    tar -xf /tmp/flutter.tar.xz -C "${HOME}"
    rm -f /tmp/flutter.tar.xz
  fi
  export PATH="${FLUTTER_DIR}/bin:${PATH}"
  # The SDK checkout is owned by a different user than the build runs as.
  git config --global --add safe.directory "${FLUTTER_DIR}" || true
fi

flutter --version
flutter pub get
flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL}"

# Never let the unbuilt source template reach the CDN again: that is the exact
# failure this whole path exists to prevent, and it is silent from the outside —
# the site just renders blank.
if [ ! -f build/web/main.dart.js ]; then
  echo "ERROR: main.dart.js missing — the build did not run" >&2
  exit 1
fi
if grep -q 'FLUTTER_BASE_HREF' build/web/index.html; then
  echo 'ERROR: build/web/index.html still holds the $FLUTTER_BASE_HREF placeholder' >&2
  exit 1
fi

echo "==> Bundle ready: $(du -sh build/web | cut -f1), $(find build/web -type f | wc -l) files"
