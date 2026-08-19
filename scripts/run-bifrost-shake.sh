#!/usr/bin/env bash
# Bifrost --shake: Yggdrasil stage-1 + stage-2 build/run per target, diff stdout.
#
# Uses the self-contained pure-path entry (programs/sha256-smoke.shake.shen).
# Only that case is run (vector suite is not a deploy-path candidate).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIFROST_DIR="${BIFROST_DIR:-$ROOT/../bifrost}"
export BIFROST_ADAPTERS="${BIFROST_ADAPTERS:-$ROOT/adapters.json}"
export PATH="${HOME}/.local/Homebrew/bin:${PATH}"
export SHEN_KERNEL_DIR="${SHEN_KERNEL_DIR:-$ROOT/../shen-rust/kernel/klambda}"
export BIFROST_YGGDRASIL_DIR="${BIFROST_YGGDRASIL_DIR:-$ROOT/../yggdrasil}"
export SHEN_X_SHA256=pure
# Stage-1 host for yggdrasil (must be a working Shen 41.2). Prefer urdr pin.
export BIFROST_SHEN_CL="${BIFROST_SHEN_CL:-$ROOT/../shen-cl/bin/sbcl/shen}"
export YGGDRASIL_HOST="${YGGDRASIL_HOST:-$BIFROST_SHEN_CL}"
# Point yggdrasil stage-2 builders at sibling ports (builders.json dir_env)
export YGGDRASIL_SHEN_GO_DIR="${YGGDRASIL_SHEN_GO_DIR:-$ROOT/../shen-go}"
export YGGDRASIL_SHEN_LUA_DIR="${YGGDRASIL_SHEN_LUA_DIR:-$ROOT/../shen-lua}"
export YGGDRASIL_SHEN_RUST_DIR="${YGGDRASIL_SHEN_RUST_DIR:-$ROOT/../shen-rust}"
export YGGDRASIL_SHEN_CL_DIR="${YGGDRASIL_SHEN_CL_DIR:-$ROOT/../shen-cl}"

cd "$ROOT"
"$ROOT/scripts/bundle-shake-entry.sh"

if [[ -x "$BIFROST_DIR/bifrost" ]]; then
  BIFROST="$BIFROST_DIR/bifrost"
elif command -v bifrost >/dev/null 2>&1; then
  BIFROST="$(command -v bifrost)"
elif [[ -x /tmp/bifrost-bin ]]; then
  BIFROST=/tmp/bifrost-bin
else
  mkdir -p "$ROOT/.bin"
  (cd "$BIFROST_DIR" && go build -o "$ROOT/.bin/bifrost" .)
  BIFROST="$ROOT/.bin/bifrost"
fi

if [[ -z "${YGGDRASIL_BIN:-}" ]]; then
  if command -v yggdrasil >/dev/null 2>&1; then
    export YGGDRASIL_BIN="$(command -v yggdrasil)"
  elif [[ -x /tmp/yggdrasil-bin ]]; then
    export YGGDRASIL_BIN=/tmp/yggdrasil-bin
  else
    (cd "${BIFROST_YGGDRASIL_DIR}" && go build -o "$ROOT/.bin/yggdrasil" .)
    export YGGDRASIL_BIN="$ROOT/.bin/yggdrasil"
  fi
fi

# Deploy suite is smoke-only; -shake rewrites script cases to yggdrasil run.
exec "$BIFROST" \
  -suite "$ROOT/bifrost.shake.suite.json" \
  -shake \
  -heavy \
  "$@"
