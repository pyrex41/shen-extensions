#!/usr/bin/env bash
# Full local gate: Bifrost agreement + Yggdrasil stage-1 + optional deploy shake.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== 1/4 Bifrost agreement (load-from-source, host backends) ==="
"$ROOT/scripts/run-bifrost.sh" "$@"

echo
echo "=== 2/4 Bifrost agreement (SHEN_X_SHA256=pure, pure oracle, +shen-cl) ==="
"$ROOT/scripts/run-bifrost-pure.sh" "$@"

echo
echo "=== 3/4 Yggdrasil stage-1 multi-file shake (pure path) ==="
"$ROOT/scripts/shake.sh"

echo
echo "=== 4/4 Bifrost --shake deploy path (optional; set SX_SHAKE_DEPLOY=1) ==="
if [[ "${SX_SHAKE_DEPLOY:-}" == "1" ]]; then
  "$ROOT/scripts/run-bifrost-shake.sh" "$@"
else
  echo "skipped (export SX_SHAKE_DEPLOY=1 to build+run standalone artifacts)"
fi

echo
echo "check: OK"
