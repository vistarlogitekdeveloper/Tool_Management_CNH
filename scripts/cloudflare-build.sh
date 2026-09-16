#!/usr/bin/env bash
#
# Build the Flutter web bundle inside Cloudflare Workers Builds.
#
# Cloudflare's build image ships Node, Python, Go, Ruby and friends, but no
# Flutter SDK — `wrangler deploy` therefore finds no build/web and fails. This
# installs the SDK, builds, and verifies the result.
#
# Set it as the *build command* in the Cloudflare dashboard:
#
#     bash scripts/cloudflare-build.sh
#
# leaving the deploy command as `npx wrangler deploy`.
#
# Prefer GitHub Actions where you can: it caches the SDK, so builds take about
# three minutes instead of downloading ~700MB every time. See
# .github/workflows/deploy-cloudflare-workers.yml.

set -euo pipefail

FLUTTER_VERSION="3.35.0"
FLUTTER_DIR="${HOME}/flutter"
API_BASE_URL="${API_BASE_URL:-https://uat-api.vistarlogitek.com/api/v1/tool-management}"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "==> Installing Flutter ${FLUTTER_VERSION}"
  curl -fsSL --retry 3 -o /tmp/flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar -xf /tmp/flutter.tar.xz -C "${HOME}"
  rm -f /tmp/flutter.tar.xz
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"
# The build image runs as a different user than the SDK checkout expects.
git config --global --add safe.directory "${FLUTTER_DIR}" || true

flutter --version
flutter pub get
flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL}"

# Never let the source template reach the CDN again.
if [ ! -f build/web/main.dart.js ]; then
  echo "ERROR: main.dart.js missing — the build did not run" >&2
  exit 1
fi
if grep -q 'FLUTTER_BASE_HREF' build/web/index.html; then
  echo 'ERROR: build/web/index.html still holds the $FLUTTER_BASE_HREF placeholder' >&2
  exit 1
fi

echo "==> Bundle ready: $(du -sh build/web | cut -f1), $(find build/web -type f | wc -l) files"
