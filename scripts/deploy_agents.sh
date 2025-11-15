#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${FIREBASE_PROJECT:-helical-button-461921-v6}"

info() {
  echo "==> $1"
}

warn() {
  echo "WARNING: $1" >&2
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_cmd firebase
need_cmd npm
need_cmd bash
need_cmd sed

if ! command -v flutter >/dev/null 2>&1; then
  warn "flutter is not on PATH; skipping formatter/test steps."
else
  if [[ "${SKIP_FORMAT:-0}" != "1" ]]; then
    info "Formatting Dart sources"
    if ! flutter format "$ROOT_DIR/lib" "$ROOT_DIR/test"; then
      warn "flutter format failed (set SKIP_FORMAT=1 to skip); deployment will continue."
    fi
  else
    info "Skipping formatter (SKIP_FORMAT=1)"
  fi

  info "Running Flutter tests"
  pushd "$ROOT_DIR" >/dev/null
  flutter test
  popd >/dev/null
fi

info "Installing and testing Cloud Functions"
pushd "$ROOT_DIR/functions" >/dev/null
npm ci
npm run lint
npm test
npm run build
popd >/dev/null

info "Deploying functions to ${PROJECT_ID}"
firebase use "$PROJECT_ID"
firebase deploy --only functions --project "$PROJECT_ID"

info "Deployment completed"
