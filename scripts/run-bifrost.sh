#!/usr/bin/env bash
# Cross-port agreement for shen-extensions via Bifrost.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIFROST_DIR="${BIFROST_DIR:-$ROOT/../bifrost}"
export BIFROST_ADAPTERS="${BIFROST_ADAPTERS:-$ROOT/adapters.json}"
export PATH="${HOME}/.local/Homebrew/bin:${PATH}"
# shen-rust kernel when using release binary
export SHEN_KERNEL_DIR="${SHEN_KERNEL_DIR:-$ROOT/../shen-rust/kernel/klambda}"

cd "$ROOT"

if [[ -x "$BIFROST_DIR/bifrost" ]]; then
  BIFROST="$BIFROST_DIR/bifrost"
elif command -v bifrost >/dev/null 2>&1; then
  BIFROST="$(command -v bifrost)"
elif [[ -f "$BIFROST_DIR/bifrost.py" ]]; then
  BIFROST=(python3 "$BIFROST_DIR/bifrost.py")
else
  echo "bifrost not found; set BIFROST_DIR or install bifrost" >&2
  exit 1
fi

if [[ -x "$BIFROST_DIR/bifrost" ]] || command -v bifrost >/dev/null 2>&1; then
  exec "$BIFROST" -suite "$ROOT/bifrost.suite.json" -heavy "$@"
else
  exec "${BIFROST[@]}" --suite "$ROOT/bifrost.suite.json" --heavy "$@"
fi
