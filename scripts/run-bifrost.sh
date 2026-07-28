#!/usr/bin/env bash
# Cross-port agreement via Bifrost (load-from-source path).
#
# Usage:
#   ./scripts/run-bifrost.sh                         # heavy agreement suite
#   ./scripts/run-bifrost.sh -impls shen-go,shen-lua  # subset
#   ./scripts/run-bifrost.sh -only sha256-smoke
#
# Deploy-path (Ratatoskr shake+build+run) is a separate script:
#   ./scripts/run-bifrost-shake.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIFROST_DIR="${BIFROST_DIR:-$ROOT/../bifrost}"
export BIFROST_ADAPTERS="${BIFROST_ADAPTERS:-$ROOT/adapters.json}"
export PATH="${HOME}/.local/Homebrew/bin:${PATH}"
export SHEN_KERNEL_DIR="${SHEN_KERNEL_DIR:-$ROOT/../shen-rust/kernel/klambda}"
export BIFROST_RATATOSKR_DIR="${BIFROST_RATATOSKR_DIR:-$ROOT/../ratatoskr}"
export RATATOSKR_BIN="${RATATOSKR_BIN:-}"

cd "$ROOT"

resolve_bifrost() {
  if [[ -x "$BIFROST_DIR/bifrost" ]]; then
    echo "$BIFROST_DIR/bifrost"
  elif command -v bifrost >/dev/null 2>&1; then
    command -v bifrost
  elif [[ -x /tmp/bifrost-bin ]]; then
    echo /tmp/bifrost-bin
  elif [[ -d "$BIFROST_DIR" ]]; then
    (cd "$BIFROST_DIR" && go build -o "$ROOT/.bin/bifrost" .)
    echo "$ROOT/.bin/bifrost"
  else
    echo "bifrost not found; set BIFROST_DIR or install bifrost" >&2
    exit 1
  fi
}

BIFROST="$(resolve_bifrost)"
# Default impls: ports with host SHA (go/lua/rust). Override with -impls.
if [[ "$*" != *-impls* ]]; then
  set -- -impls shen-go,shen-lua,shen-rust "$@"
fi
exec "$BIFROST" -suite "$ROOT/bifrost.suite.json" -heavy "$@"
