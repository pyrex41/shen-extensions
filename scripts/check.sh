#!/usr/bin/env bash
# Full local gate: Bifrost agreement + Ratatoskr stage-1 + optional deploy shake.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== 1/3 Bifrost agreement (load-from-source, host backends) ==="
"$ROOT/scripts/run-bifrost.sh" "$@"

echo
echo "=== 2/3 Ratatoskr stage-1 multi-file shake (pure path) ==="
"$ROOT/scripts/shake.sh"

echo
echo "=== 3/3 Bifrost --shake deploy path (optional; set SX_SHAKE_DEPLOY=1) ==="
if [[ "${SX_SHAKE_DEPLOY:-}" == "1" ]]; then
  "$ROOT/scripts/run-bifrost-shake.sh" "$@"
else
  echo "skipped (export SX_SHAKE_DEPLOY=1 to build+run standalone artifacts)"
fi

echo
echo "check: OK"
