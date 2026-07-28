# shen-extensions — Bifrost agreement + Ratatoskr shake
.PHONY: help test bifrost bifrost-shake shake bundle check

help:
	@echo "targets:"
	@echo "  make bifrost         # cross-port agreement (go/lua/rust host path)"
	@echo "  make shake           # Ratatoskr stage-1 multi-file pure shake"
	@echo "  make bifrost-shake   # Bifrost --shake deploy-path (standalone artifacts)"
	@echo "  make bundle          # regenerate programs/sha256-smoke.shake.shen"
	@echo "  make check           # bifrost + shake (set SX_SHAKE_DEPLOY=1 for deploy too)"
	@echo "  make test            # alias for check"

test: check

bifrost:
	./scripts/run-bifrost.sh

bifrost-shake: bundle
	./scripts/run-bifrost-shake.sh

shake:
	./scripts/shake.sh

bundle:
	./scripts/bundle-shake-entry.sh

check:
	./scripts/check.sh
