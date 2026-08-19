#!/usr/bin/env bash
# Stage-1 Yggdrasil multi-file shake (pure path).
#
# Yggdrasil does not follow (load …). We pass pure + portable + body so the
# full call graph is in the user KL footprint.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/.shake/sha256-smoke}"
YGGDRASIL_DIR="${YGGDRASIL_DIR:-$ROOT/../yggdrasil}"
export PATH="${HOME}/.local/Homebrew/bin:${PATH}"
export BIFROST_SHEN_CL="${BIFROST_SHEN_CL:-$ROOT/../shen-cl/bin/sbcl/shen}"
export YGGDRASIL_HOST="${YGGDRASIL_HOST:-$BIFROST_SHEN_CL}"
export SHEN_X_SHA256=pure

PURE="$ROOT/shen/x/sha256-pure.shen"
PORTABLE="$ROOT/shen/x/sha256-portable.shen"
BODY="$ROOT/programs/sha256-smoke-body.shen"
for f in "$PURE" "$PORTABLE" "$BODY" "$YGGDRASIL_DIR/yggdrasil.shen"; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done

mkdir -p "$OUT" "$ROOT/.bin"
rm -rf "$OUT"
mkdir -p "$OUT"

HOST="$YGGDRASIL_HOST"
if [[ ! -x "$HOST" ]]; then
  echo "YGGDRASIL_HOST not executable: $HOST" >&2
  echo "falling back to single-file CLI shake" >&2
  "$ROOT/scripts/bundle-shake-entry.sh" "$ROOT/programs/sha256-smoke.shake.shen"
  R=yggdrasil
  if ! command -v yggdrasil >/dev/null 2>&1; then
    if [[ -x /tmp/yggdrasil-bin ]]; then R=/tmp/yggdrasil-bin
    else (cd "$YGGDRASIL_DIR" && go build -o "$ROOT/.bin/yggdrasil" .) && R="$ROOT/.bin/yggdrasil"
    fi
  fi
  "$R" shake "$ROOT/programs/sha256-smoke.shake.shen" "$OUT"
else
  DRV="$(mktemp "${TMPDIR:-/tmp}/sx-shake.XXXXXX")"
  DRV="${DRV}.shen"
  # Absolute paths in the file list so host cwd = yggdrasil is fine.
  cat > "$DRV" <<EOF
(load "yggdrasil.shen")
(yggdrasil.shake
  ["$PURE"
   "$PORTABLE"
   "$BODY"]
  "$OUT")
EOF
  echo "multi-file shake via $HOST (cwd=$YGGDRASIL_DIR)"
  (cd "$YGGDRASIL_DIR" && "$HOST" script "$DRV")
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
