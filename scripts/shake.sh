#!/usr/bin/env bash
# Stage-1 Ratatoskr shake of the sha256 smoke program.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/.shake/sha256-smoke}"
RATATOSKR_DIR="${RATATOSKR_DIR:-$ROOT/../ratatoskr}"
export PATH="${HOME}/.local/Homebrew/bin:${PATH}"
export BIFROST_SHEN_CL="${BIFROST_SHEN_CL:-$ROOT/../urdr-shen-cl-41.2/bin/sbcl/shen}"
export RATATOSKR_HOST="${RATATOSKR_HOST:-$BIFROST_SHEN_CL}"

mkdir -p "$OUT"

if command -v ratatoskr >/dev/null 2>&1; then
  R=ratatoskr
elif [[ -x /tmp/ratatoskr-bin ]]; then
  R=/tmp/ratatoskr-bin
elif [[ -x "$RATATOSKR_DIR/ratatoskr" ]]; then
  R="$RATATOSKR_DIR/ratatoskr"
else
  (cd "$RATATOSKR_DIR" && go build -o "$ROOT/.bin/ratatoskr" .)
  R="$ROOT/.bin/ratatoskr"
fi

# Shake from repo root so (load "shen/x/sha256.shen") resolves.
cd "$ROOT"
"$R" shake "$ROOT/programs/sha256-smoke.shen" "$OUT"
echo "shake wrote $OUT"
ls -la "$OUT"
