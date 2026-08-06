# shen-extensions — Bifrost agreement + Ratatoskr shake
.PHONY: help test bifrost bifrost-pure bifrost-zmq bifrost-shake shake bundle check

help:
	@echo "targets:"
	@echo "  make bifrost         # cross-port agreement (go/lua/rust host path)"
	@echo "  make bifrost-pure    # agreement with SHEN_X_SHA256=pure (go/lua/rust/cl, pure oracle)"
	@echo "  make bifrost-zmq     # zmq agreement cases (shen-go only — sole zmq host today)"
	@echo "  make shake           # Ratatoskr stage-1 multi-file pure shake"
	@echo "  make bifrost-shake   # Bifrost --shake deploy-path (standalone artifacts)"
	@echo "  make bundle          # regenerate programs/sha256-smoke.shake.shen"
	@echo "  make check           # bifrost + bifrost-pure + shake (SX_SHAKE_DEPLOY=1 for deploy too)"
	@echo "  make test            # alias for check"

test: check

bifrost:
	./scripts/run-bifrost.sh

bifrost-pure:
	./scripts/run-bifrost-pure.sh

# zmq is host-only and only shen-go ships a host today. Its cases live in
# their own suite manifest (bifrost.zmq.suite.json) so the default cross-port
# lanes (bifrost/bifrost-pure/check) never run them on hostless ports.
bifrost-zmq:
	BIFROST_SUITE=bifrost.zmq.suite.json ./scripts/run-bifrost.sh -impls shen-go

bifrost-shake: bundle
	./scripts/run-bifrost-shake.sh

shake:
	./scripts/shake.sh

bundle:
	./scripts/bundle-shake-entry.sh

check:
	./scripts/check.sh
