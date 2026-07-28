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

## Multi-file shake order (this repo)

```text
shen/x/sha256-pure.shen      pure oracle (fallback)
shen/x/sha256-portable.shen   API: host if present else pure
programs/sha256-smoke-body.shen
```

See `scripts/shake.sh` and `scripts/bundle-shake-entry.sh`.
