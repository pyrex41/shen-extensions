# shen-extensions

Portable, opt-in libraries for Shen programs.

This repository provides stable `shen.x.*` APIs for capabilities that are not
part of core Shen. A program uses the same Shen functions on every port; each
port can supply an efficient native backend where one is available.

The repository currently contains two extensions:

| Extension | What it provides | Availability |
| --- | --- | --- |
| [SHA-256](#sha-256) | Byte and hexadecimal SHA-256 digests | Every supported port through a native backend or pure Shen fallback |
| [ZeroMQ](#zeromq) | Sockets, messaging, polling, and timeouts | Ports with a ZMQ backend; currently shen-go |

`shen-extensions` runs on top of an existing Shen implementation. It is not a
new Shen runtime or a replacement for a port.

## Quick start

Run Shen with this repository as its home directory, then load every extension:

```shen
(load "load.shen")
```

You can also load one extension directly:

```shen
(load "shen/x/sha256.shen")
(load "shen/x/zmq.shen")
```

### Shen Batteries modules

When the Shen Batteries module loader is available, the same extensions can
be loaded as named modules. Set the module home to this repository before the
first `library.use` call:

```shen
(load "/path/to/shen-batteries/library.shen")
(library.set-home "/path/to/shen-extensions")
(library.use [shen/x])
```

The canonical modules are `shen/x`, `shen/x/sha256`, and `shen/x/zmq`, with
descriptors at `shen/x.shenmod`, `shen/x/sha256.shenmod`, and
`shen/x/zmq.shenmod`. Shen Batteries resolves each `sources` path relative to
the directory that contains the descriptor (`<module-home>/<parent-of-name>/`),
not from the repository root: `shen/x.shenmod` therefore lists `x/package.shen`
(the file at `shen/x/package.shen`), while `shen/x/sha256.shenmod` lists
`sha256.shen`. Root-level legacy aliases such as `shen.x.shenmod` still use
paths from the module home (`shen/x/compat-package.shen`). The older `shen.x`,
`shen.x.sha256`, and `shen.x.zmq` descriptors remain compatibility aliases. The
existing `load.shen` and direct source loads remain supported for ports that do
not provide the module loader.

The included wrapper sets the Shen home directory for sibling port checkouts:

```bash
./scripts/shen-x go script examples/hello-sha.shen
./scripts/shen-x lua script examples/hello-sha.shen
./scripts/shen-x rust script examples/hello-sha.shen
./scripts/shen-x cl script examples/hello-sha.shen
```

Override a launcher with `SHEN_GO`, `SHEN_LUA`, `SHEN_RUST`, or `SHEN_CL` if
your ports are installed elsewhere.

## How portability works

Application code only calls the public `shen.x.*` API:

```text
Shen program ──> portable shen.x API ──> native port backend, when installed
                                  └────> pure Shen fallback, when provided
```

The port-specific details stay behind that API. SHA-256 includes a pure Shen
implementation, so it works even when a port has no native crypto backend.
ZeroMQ performs host I/O and has no meaningful pure fallback; on an unsupported
port its functions raise a catchable Shen error instead.

### How the pieces fit together

The extension layer combines three deliberately separate concerns:

```text
module descriptor       selects and orders source files
        |
portable shen.x API     keeps application code identical across ports
        |
feature query           reports which native backends this process installed
        |
host backend or pure Shen implementation
```

The `.shenmod` descriptors make the extensions usable through Shen Batteries,
while `load.shen` remains the compatibility entry point for ports without its
module loader. Module loading is about names, dependencies, and source order;
it does not force a host backend.

Backend selection remains an extension-level runtime decision. SHA-256 falls
back to pure Shen when `shen.x/sha256-host` is absent (or when
`SHEN_X_SHA256=pure` is set). ZeroMQ requires host I/O and reports an absent
backend through its existing catchable error. Ports expose the installed
capabilities through `shen.x.features.current`, so Shen Batteries code can
inspect or conditionally expand against the same facts without changing the
portable API.

## SHA-256

```shen
(load "shen/x/sha256.shen")

(shen.x.sha256-hex (shen.x.string->octets "abc"))
\\ => ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad

(shen.x.sha256-backend)
\\ => host or pure
```

The public API is:

| Symbol | Meaning |
| --- | --- |
| `shen.x.sha256-octets` | Hash a list of bytes (`0..255`) and return 32 bytes |
| `shen.x.sha256-hex` | Render a digest as 64 lowercase hexadecimal characters |
| `shen.x.string->octets` | Convert a Shen string to bytes |
| `shen.x.sha256-backend` | Report `host` or `pure` |

Backend support:

| Port | Backend used by default | Implementation |
| --- | --- | --- |
| shen-go | Go `crypto/sha256` | [`kl/shenx_sha256.go`](https://github.com/pyrex41/shen-go/blob/master/kl/shenx_sha256.go) |
| shen-lua | OpenSSL `libcrypto` through FFI | [`prims.lua`](https://github.com/pyrex41/shen-lua/blob/main/prims.lua#L1111-L1175) |
| shen-rust | Rust `sha2` crate | [`primitives.rs`](https://github.com/pyrex41/shen-rust/blob/main/crates/shen-rust/src/primitives.rs#L647-L685) |
| shen-cl | Self-contained optimized Common Lisp | [`src/sha256.lsp`](https://github.com/pyrex41/shen-cl/blob/master/src/sha256.lsp) |

Set `SHEN_X_SHA256=pure` to force the portable implementation when a native
backend is installed. The pure implementation is also the reference used to
verify native results.

### Performance of the current implementations

The pure path is not the original naive prototype. A
[performance rewrite](https://github.com/pyrex41/shen-extensions/commit/150831c7c70b2a27b8685eb6181338d9478b198b)
replaced per-operation table construction and slow division with four-byte
words, memoized constants, bit-list walks, and byte-wise carry addition. At the
time, that changed the pure vector suite from effectively non-finishing on
some ports to about 0.11–1.3 seconds across the four ports.

It is also not a theoretical performance ceiling for pure Shen. The current
hot path still creates intermediate bit lists for 32-bit Boolean operations
and rotations, and constructs the message schedule with immutable list
traversals. Fused byte operations, persistent lookup tables, or a more suitable
schedule representation may improve it further while preserving portability.

This representative local run (2026-08-19) hashed a warmed-up 64-byte message
with the current port builds on an Apple M4. The benchmark uses 100,000
iterations for the host path and 10 for the pure path, then compares hashes
per second:

| Port | Host hashes/sec | Current pure hashes/sec | Host/current-pure ratio |
| --- | ---: | ---: | ---: |
| shen-go | 483,000 | 4.5 | about 108,000x |
| shen-lua | 124,000 | 8.9 | about 13,900x |
| shen-rust | 309,000 | 8.5 | about 36,200x |
| shen-cl | 414,000 | 59.9 | about 6,900x |

Run the same comparison on any port with:

```bash
./scripts/shen-x go script programs/sha256-benchmark.shen
SHEN_X_SHA256=pure ./scripts/shen-x go script programs/sha256-benchmark.shen
```

These figures compare the checked-in implementations; they do not claim that
pure Shen cannot do better. They are illustrative rather than general-purpose
crypto benchmarks, include conversion between Shen byte lists and host values,
and will vary with the machine, runtime, and message size. The benchmark is
included so the comparison can be reproduced and revisited as the pure path is
improved.

## ZeroMQ

```shen
(load "shen/x/zmq.shen")

(let Pull (shen.x.zmq.socket pull)
     Bound (shen.x.zmq.bind Pull "inproc://hello")
     Push (shen.x.zmq.socket push)
     Connected (shen.x.zmq.connect Push "inproc://hello")
     Sent (shen.x.zmq.send-string Push "hello, zmq")
     Message (shen.x.zmq.recv-string Pull)
     Terminated (shen.x.zmq.term)
  Message)
\\ => "hello, zmq"
```

The API covers:

| Area | Symbols |
| --- | --- |
| Sockets | `shen.x.zmq.socket`, `bind`, `connect`, `endpoint` |
| Messages | `send`, `recv`, `send-string`, `recv-string`, multipart variants |
| Readiness | `poll`, `shen.x.zmq.timeout`, `timeout?` |
| Options | `set-option`, `subscribe`, `unsubscribe` |
| Cleanup | `close`, `term`, `with-socket` |
| Status | `shen.x.zmq-backend` returns `host` or `absent` |

Socket types are `req`, `rep`, `pub`, `sub`, `push`, `pull`, `pair`, `dealer`,
and `router`. Binary frames are lists of bytes. Timeouts return the symbol
`shen.x.zmq.timeout`; other failures are catchable errors prefixed with
`shen.x.zmq: `.

shen-go currently supplies the only ZMQ backend, using the pure-Go
`github.com/go-zeromq/zmq4` package; its implementation is
[`kl/shenx_zmq.go`](https://github.com/pyrex41/shen-go/blob/master/kl/shenx_zmq.go).
Other ports report an absent backend and raise a clear error when a ZMQ
operation is attempted. Set `SHEN_X_ZMQ=off` to disable backend installation
explicitly.

See [`examples/hello-zmq.shen`](examples/hello-zmq.shen) for a runnable example
and [`ports/README.md`](ports/README.md) for the host-backend contract.

## Tests and cross-port verification

The ordinary tests exercise the public API. Bifrost and Yggdrasil are
maintainer tools used to prove that the same extension behaves consistently
across ports and in standalone builds; they are not required by applications
that use this repository.

| Command | What it checks |
| --- | --- |
| `./scripts/shen-x cl script tests/run-sha256.shen` | SHA-256 reference vectors on one port |
| `make bifrost` | Identical SHA-256 results across available ports |
| `make bifrost-zmq` | Deterministic ZMQ behavior on ports with a backend |
| `make shake` | A standalone SHA-256 slice generated by Yggdrasil |
| `make bifrost-shake` | Cross-port agreement of standalone artifacts |
| `make check` | The full local integration gate |

The integration scripts expect sibling checkouts by default:

```text
~/projects/
  shen-extensions/
  bifrost/
  yggdrasil/
  shen-cl/
  shen-go/
  shen-lua/
  shen-rust/
```

Their locations can be overridden with the `BIFROST_*`, `YGGDRASIL_*`, and
`SHEN_*` environment variables used by the scripts.

## Adding a backend

A port backend implements the small host-facing contract and marks that
backend as available. User programs continue to call only the public Shen API.

The exact primitive names, arities, return values, error behavior, and
installation points are documented in [`ports/README.md`](ports/README.md).

Ports that integrate with Shen Batteries should also expose the zero-arity
`shen.x.features.current` query. It returns namespaced capabilities for the
backends installed in that process, currently `shen.x/sha256-host` and
`shen.x/zmq-host`. A disabled or unavailable backend must be omitted; the
portable SHA-256 module must continue to work without its host feature.

## Repository layout

```text
load.shen                         load all extensions
shen/x.shenmod                    canonical aggregate module descriptor
shen/x/*.shenmod                  canonical per-extension descriptors
shen.x*.shenmod                   temporary legacy descriptor aliases
shen/x/sha256.shen                public SHA-256 API and backend selection
shen/x/sha256-pure.shen           pure Shen SHA-256 implementation
shen/x/zmq.shen                   public ZeroMQ API
examples/                         small runnable programs
tests/                            extension test suites
ports/                            host-backend contracts and adapters
programs/                         Bifrost and Yggdrasil test programs
programs/sha256-benchmark.shen    reproducible host-versus-pure comparison
scripts/shen-x                    portable launcher wrapper
scripts/run-bifrost*.sh           cross-port verification
scripts/shake.sh                  Yggdrasil standalone-build check
adapters.json                     local Bifrost port launchers
```

## License

BSD-3-Clause.
