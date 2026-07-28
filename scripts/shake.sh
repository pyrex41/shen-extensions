#!/usr/bin/env bash
# Stage-1 Ratatoskr multi-file shake (pure path).
#
# Ratatoskr does not follow (load …). We pass pure + portable + body so the
# full call graph is in the user KL footprint.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/.shake/sha256-smoke}"
RATATOSKR_DIR="${RATATOSKR_DIR:-$ROOT/../ratatoskr}"
export PATH="${HOME}/.local/Homebrew/bin:${PATH}"
export BIFROST_SHEN_CL="${BIFROST_SHEN_CL:-$ROOT/../urdr-shen-cl-41.2/bin/sbcl/shen}"
export RATATOSKR_HOST="${RATATOSKR_HOST:-$BIFROST_SHEN_CL}"
export SHEN_X_SHA256=pure

PURE="$ROOT/shen/x/sha256-pure.shen"
PORTABLE="$ROOT/shen/x/sha256-portable.shen"
BODY="$ROOT/programs/sha256-smoke-body.shen"
for f in "$PURE" "$PORTABLE" "$BODY" "$RATATOSKR_DIR/ratatoskr.shen"; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done

mkdir -p "$OUT" "$ROOT/.bin"
rm -rf "$OUT"
mkdir -p "$OUT"

HOST="$RATATOSKR_HOST"
if [[ ! -x "$HOST" ]]; then
  echo "RATATOSKR_HOST not executable: $HOST" >&2
  echo "falling back to single-file CLI shake" >&2
  "$ROOT/scripts/bundle-shake-entry.sh" "$ROOT/programs/sha256-smoke.shake.shen"
  R=ratatoskr
  if ! command -v ratatoskr >/dev/null 2>&1; then
    if [[ -x /tmp/ratatoskr-bin ]]; then R=/tmp/ratatoskr-bin
    else (cd "$RATATOSKR_DIR" && go build -o "$ROOT/.bin/ratatoskr" .) && R="$ROOT/.bin/ratatoskr"
    fi
  fi
  "$R" shake "$ROOT/programs/sha256-smoke.shake.shen" "$OUT"
else
  DRV="$(mktemp "${TMPDIR:-/tmp}/sx-shake.XXXXXX")"
  DRV="${DRV}.shen"
  # Absolute paths in the file list so host cwd = ratatoskr is fine.
  cat > "$DRV" <<EOF
(load "ratatoskr.shen")
(ratatoskr.shake
  ["$PURE"
   "$PORTABLE"
   "$BODY"]
  "$OUT")
EOF
  echo "multi-file shake via $HOST (cwd=$RATATOSKR_DIR)"
  (cd "$RATATOSKR_DIR" && "$HOST" script "$DRV")
  rm -f "$DRV"
fi

if [[ ! -f "$OUT/kernel.kl" ]]; then
  echo "shake failed: no $OUT/kernel.kl" >&2
  exit 1
fi

echo "shake wrote $OUT"
ls -la "$OUT"
# Footprint check: pure symbols must appear somewhere in emitted KL
if ! grep -q 'sha256' "$OUT"/*.kl; then
  echo "error: no sha256 symbols in emitted KL" >&2
  exit 1
fi
echo "footprint: ok (sha256 symbols present)"
