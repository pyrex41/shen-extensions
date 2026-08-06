# Port host backends for shen.x

## Contract (live REPL / `script`)

After kernel boot, optionally bind:

| Symbol | Arity | Meaning |
| --- | ---: | --- |
| `shen.x.sha256-octets-host` | 1 | list of 0..255 → 32-byte list |
| `shen.x.*sha256-backend*` | global | set to symbol `host` when installed |

Disable with `SHEN_X_SHA256=pure`.

User Shen never names the host function. They only call:

```shen
(load "load.shen")   \\ or (load "shen/x/sha256.shen")
(shen.x.sha256-hex (shen.x.string->octets "…"))
```

## Contract (Ratatoskr shaken / standalone)

Stage-2 builders must install the same host binding **after** the shaken
kernel loads and **before** user chunks run, so pure-path user KL that does

```shen
(if (shen.x.host-sha256?)
    (shen.x.sha256-octets-host Bs)
    (shen.x.sha256-octets-pure Bs))
```

hits native crypto.

| Port | Live install | Shaken install |
| --- | --- | --- |
| shen-go | `kl.InstallShenX()` from `cmd/shen` | `InstallShenX()` in generated `main.go` (ratatoskr-build) |
| shen-lua | end of `prims.install_native_stdlib` | same (ratatoskr-build already calls `install_native_stdlib`) |
| shen-rust | `register_shenx` via hot overrides | same (`boot_from_kl_source` → hot overrides) |
| shen-cl | `ports/shen-cl/sha256-host.lsp` | TBD (image must export load-lisp / bake host) |

## ZMQ host waist (`shen.x.zmq`)

ZMQ is **host-only**: there is no pure fallback (it is I/O). On ports without
a host, the user API (`shen/x/zmq.shen`) raises the catchable error
`shen.x.zmq: no host backend on this port (see shen-extensions/ports/README.md)`.
Users never call the waist primitives directly.

| Symbol | Arity | Meaning |
| --- | ---: | --- |
| `shen.x.zmq.socket-host` | 1 | type sym (`req rep pub sub push pull pair dealer router`) → handle int |
| `shen.x.zmq.bind-host` | 2 | handle, endpoint string → `true` |
| `shen.x.zmq.connect-host` | 2 | handle, endpoint string → `true` |
| `shen.x.zmq.send-host` | 2 | handle, frames (non-empty list of lists of 0..255; atomic multipart) → `true` \| `shen.x.zmq.timeout` |
| `shen.x.zmq.recv-host` | 1 | handle → frames \| `shen.x.zmq.timeout` |
| `shen.x.zmq.setopt-host` | 3 | handle, opt sym, value → `true` |
| `shen.x.zmq.poll-host` | 2 | handle list, ms int → readable subset (input order) |
| `shen.x.zmq.endpoint-host` | 1 | handle → last bound endpoint (real port substituted after `:0` bind) |
| `shen.x.zmq.close-host` | 1 | handle → `true` |
| `shen.x.zmq.term-host` | 0 | close all sockets, reset context; idempotent → `true` |
| `shen.x.*zmq-backend*` | global | set to symbol `host` when installed |

Options (v1): `rcvtimeo` int ms (-1 = block forever, default), `sndtimeo`
int ms (-1 default), `subscribe` / `unsubscribe` octet-list, `linger` int ms
(MAY be a no-op). Poll ms: `0` immediate snapshot, `> 0` wait up to ms for ≥1
ready, `-1` block. Timeouts RETURN the symbol `shen.x.zmq.timeout`; every
error is a Shen error prefixed `shen.x.zmq: ` (exact strings are part of the
contract — see `shen/x/zmq.shen` and `programs/zmq-errors.shen`).

**Install contract**: bind all 10 primitives AND set `shen.x.*zmq-backend*`
to the symbol `host`. Kill switch: `SHEN_X_ZMQ=off` → install nothing.
Detection is via the global ONLY (no probe call — probing would create
sockets).

**Shaken builds**: stage-2 builders already call `InstallShenX()` after the
shaken kernel loads, so zmq comes for free on shen-go standalone artifacts.

| Port | Backend | Status |
| --- | --- | --- |
| shen-go | `github.com/go-zeromq/zmq4` (pure Go, no cgo — static binary preserved) | shipped (`kl.InstallShenX`) |
| shen-lua | — | TBD |
| shen-rust | — | TBD |
| shen-cl | — | TBD |

## Multi-file shake order (this repo)

```text
shen/x/sha256-pure.shen      pure oracle (fallback)
shen/x/sha256-portable.shen   API: host if present else pure
programs/sha256-smoke-body.shen
```

See `scripts/shake.sh` and `scripts/bundle-shake-entry.sh`.
