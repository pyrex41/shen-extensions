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
| Shake / deploy slice | [Ratatoskr](https://github.com/pyrex41/ratatoskr) | tree-shake entry programs |

## SHA-256

```shen
(load "shen/x/sha256.shen")
(shen.x.sha256-hex (shen.x.string->octets "abc"))
\\ => ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad

(shen.x.sha256-backend)   \\ host | pure
```

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

## Bifrost (cross-port)

From this repo (sibling checkouts of ports + bifrost):

```bash
export BIFROST_ADAPTERS=$PWD/adapters.json
export SHEN_KERNEL_DIR=../shen-rust/kernel/klambda   # if needed
export PATH="$HOME/.local/Homebrew/bin:$PATH"         # luajit / openssl

./scripts/run-bifrost.sh
# or:
bifrost -suite ./bifrost.suite.json -heavy \
  -impls shen-go,shen-lua,shen-rust
```

Cases:

- `sha256-vectors-agreement` — NIST/FIPS vectors, marker `ALL PASS`
- `sha256-smoke` — `"abc"` digest agreement (also a Ratatoskr entry)

## Ratatoskr (shake)

```bash
./scripts/shake.sh                 # stage-1 shake of programs/sha256-smoke.shen
# or:
ratatoskr shake programs/sha256-smoke.shen .shake/sha256-smoke
```

Host backends are process-level: shaken standalone artifacts use pure unless
the target builder injects the host primitive. Stage-1 `kernel.kl` parity is
still useful for the pure slice.

## Layout

```
shen/x/sha256.shen       public API + host detect + lazy pure load
shen/x/sha256-pure.shen   pure oracle (not loaded when host is present)
tests/run-sha256.shen    Bifrost vector suite
programs/sha256-smoke.shen
bifrost.suite.json
adapters.json            local launcher paths (edit for your machine)
ports/shen-cl/           optional CL OpenSSL host
scripts/run-bifrost.sh
scripts/shake.sh
```

## License

BSD-3-Clause (same lineage as Shen tooling in this workspace).
