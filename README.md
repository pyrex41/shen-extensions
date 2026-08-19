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

| Port | Backend used by default |
| --- | --- |
| shen-go | Go `crypto/sha256` |
| shen-lua | OpenSSL `libcrypto` through FFI |
| shen-rust | Rust `sha2` crate |
| shen-cl | OpenSSL alien when installed; otherwise pure Shen |

Set `SHEN_X_SHA256=pure` to force the portable implementation when a native
backend is installed. The pure implementation is also the reference used to
verify native results.

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
`github.com/go-zeromq/zmq4` package. Other ports report an absent backend and
raise a clear error when a ZMQ operation is attempted. Set `SHEN_X_ZMQ=off` to
disable backend installation explicitly.

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

## Repository layout

```text
load.shen                         load all extensions
shen/x/sha256.shen                public SHA-256 API and backend selection
shen/x/sha256-pure.shen           pure Shen SHA-256 implementation
shen/x/zmq.shen                   public ZeroMQ API
examples/                         small runnable programs
tests/                            extension test suites
ports/                            host-backend contracts and adapters
programs/                         Bifrost and Yggdrasil test programs
scripts/shen-x                    portable launcher wrapper
scripts/run-bifrost*.sh           cross-port verification
scripts/shake.sh                  Yggdrasil standalone-build check
adapters.json                     local Bifrost port launchers
```

## License

BSD-3-Clause.
