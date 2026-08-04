# shen-extensions

Optional, portable Shen extensions with **per-port ideal backends** and
**cross-port identity proofs**.

Same Shen API → same output on every port. Host acceleration (OpenSSL,
`crypto/sha256`, Rust `sha2`, …) is optional; pure Shen remains the oracle.

Cross-repo path:

| Layer | Tool | Role |
| --- | --- | --- |
| Contract + pure oracle | this repo | `shen.x.sha256-*` API and FIPS vectors |
| Host backends | each Shen port | ideal native path |
| Agreement | [Bifrost](https://github.com/pyrex41/bifrost) | run suite across ports |
| Shake / deploy slice | [Ratatoskr](https://github.com/pyrex41/ratatoskr) | tree-shake + standalone build |

## User model (Shen only)

```shen
\\ From the extensions repo root, or after setting *home-directory* there:
(load "load.shen")

(shen.x.sha256-hex (shen.x.string->octets "abc"))
\\ => ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad

(shen.x.sha256-backend)   \\ host | pure — automatic
```

No per-port `#ifdef`. If the port installed a native host, digests are fast;
otherwise pure Shen runs with **identical** digests.

```bash
# convenience wrapper sets *home-directory* for you:
./scripts/shen-x go script examples/hello-sha.shen
./scripts/shen-x lua examples/hello-sha.shen
./scripts/shen-x rust script examples/hello-sha.shen
```

## SHA-256 API

| Symbol | Meaning |
| --- | --- |
| `shen.x.sha256-octets` | digest: list of 0..255 → 32 bytes |
| `shen.x.sha256-hex` | lowercase 64-char hex |
| `shen.x.sha256-octets-host` | port-supplied host primitive (optional) |
| `shen.x.sha256-octets-pure` | pure Shen oracle (`sha256-pure.shen`, lazy-loaded) |

Force pure on ports that also have host: `SHEN_X_SHA256=pure`.

### Host backends (ideal path)

| Port | Backend | Status |
| --- | --- | --- |
| **shen-go** | `crypto/sha256` | shipped (`kl.InstallShenX`) |
| **shen-lua** | OpenSSL `libcrypto` via FFI | shipped (`prims.install_native_stdlib`) |
| **shen-rust** | `sha2` crate | shipped (`register_hot_overrides`) |
| **shen-cl** | OpenSSL alien (`ports/shen-cl/sha256-host.lsp`) | image-dependent; pure works but is slow |

## Bifrost + Ratatoskr (cross-port)

Sibling layout expected:

```text
~/projects/
  shen-extensions/   ← this repo
  bifrost/
  ratatoskr/
  shen-go/  shen-lua/  shen-rust/  (host backends)
```

```bash
export PATH="$HOME/.local/Homebrew/bin:$PATH"
export SHEN_KERNEL_DIR=$PWD/../shen-rust/kernel/klambda
# stage-1 host for ratatoskr (working Shen 41.2):
export BIFROST_SHEN_CL=$PWD/../../shen-cl/bin/sbcl/shen
export RATATOSKR_HOST=$BIFROST_SHEN_CL

make bifrost          # load-from-source agreement (host SHA on go/lua/rust)
make shake            # Ratatoskr stage-1 multi-file pure slice
make bifrost-shake    # Bifrost --shake: build+run standalone per target
make check            # bifrost + shake (SX_SHAKE_DEPLOY=1 adds deploy path)
```

| Path | What it proves | Entry |
| --- | --- | --- |
| **Bifrost agreement** | same stdout on every port (host or pure) | `bifrost.suite.json` |
| **Ratatoskr stage-1** | pure call graph → `kernel.kl` + user KL | multi-file: pure + portable + body |
| **Bifrost `--shake`** | standalone artifacts agree (deploy path) | `bifrost.shake.suite.json` |

**Agreement cases** (`make bifrost`):

- `sha256-vectors-agreement` — NIST/FIPS vectors, marker `ALL PASS`
- `sha256-smoke` — `"abc"` via `(load "shen/x/sha256.shen")` (**host** when present)

**Deploy case** (`make bifrost-shake`):

- `sha256-smoke-deploy` — self-contained **pure** bundle

**Why two smoke entries?** Ratatoskr does not follow `(load …)`, so deploy uses
a multi-file / bundled entry that includes pure **and** host-preferring API.
Stage-2 builders inject host crypto (go/lua/rust) so standalone runs stay fast;
pure remains the fallback if host is disabled (`SHEN_X_SHA256=pure`).

## Layout

```
shen/x/sha256.shen               public API + host detect + lazy pure
shen/x/sha256-pure.shen          pure oracle
shen/x/sha256-portable.shen      pure-only API (shake / standalone)
programs/sha256-smoke.shen       Bifrost agreement (load + host)
programs/sha256-smoke-body.shen  multi-file shake body
programs/sha256-smoke.shake.shen bundled pure entry (Bifrost --shake)
tests/run-sha256.shen            vector suite
bifrost.suite.json               load-from-source agreement
bifrost.shake.suite.json         deploy-path (--shake) suite
adapters.json                    local port launchers
scripts/run-bifrost.sh
scripts/run-bifrost-shake.sh
scripts/shake.sh                 multi-file stage-1
scripts/bundle-shake-entry.sh
scripts/check.sh
Makefile
ports/shen-cl/                   optional CL OpenSSL host
```

## License

BSD-3-Clause (same lineage as Shen tooling in this workspace).
