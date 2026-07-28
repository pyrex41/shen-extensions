#!/usr/bin/env bash
# Pure-oracle agreement lane: the same Bifrost suite with SHEN_X_SHA256=pure
# exported, so every port actually executes the pure Shen SHA-256 instead of
# its host backend. shen-cl (no host backend) is included, giving a 4-impl
# matrix. Guards against a green host-vs-host matrix hiding a broken or
# never-executed pure oracle.
#
# Usage:
#   ./scripts/run-bifrost-pure.sh
#   ./scripts/run-bifrost-pure.sh -impls shen-go,shen-lua
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export SHEN_X_SHA256=pure
if [[ "$*" != *-impls* ]]; then
  set -- -impls shen-go,shen-lua,shen-rust,shen-cl "$@"
fi
exec "$ROOT/scripts/run-bifrost.sh" "$@"
