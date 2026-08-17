#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== ZENQIVO QA =="

echo
echo "[1/4] Backend syntax"
node --check "$ROOT/backend/server.js"

echo
echo "[2/4] Backend integration test"
(
  cd "$ROOT/backend"
  npm test
)

echo
echo "[3/4] Flutter dependencies/analyze/test"
if command -v flutter >/dev/null 2>&1; then
  (
    cd "$ROOT"
    flutter pub get
    flutter analyze
    flutter test
  )
else
  echo "SKIP: Flutter SDK not found in PATH."
fi

echo
echo "[4/4] Sensitive-file check"
blocked=(
  "$ROOT/android/key.properties"
  "$ROOT/backend/.env"
  "$ROOT/backend/zenqivo.sqlite"
)
failed=0
for file in "${blocked[@]}"; do
  if [[ -f "$file" ]]; then
    echo "WARNING: local sensitive/runtime file exists: ${file#$ROOT/}"
    # Existence is allowed locally, but it must be ignored by Git.
  fi
done

required_ignores=(
  "android/key.properties"
  "*.jks"
  "*.keystore"
  "backend/.env"
  "backend/zenqivo.sqlite"
)
for pattern in "${required_ignores[@]}"; do
  if ! grep -Fqx "$pattern" "$ROOT/.gitignore"; then
    echo "ERROR: .gitignore is missing: $pattern"
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

echo
echo "ZENQIVO QA completed."
