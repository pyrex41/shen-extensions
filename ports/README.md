# Port host backends

Each Shen port may bind `shen.x.sha256-octets-host` (arity 1: octet list → 32-byte list)
and optionally set `shen.x.*sha256-backend*` to `host`. Detection in
`shen/x/sha256.shen` is: successful `(shen.x.sha256-octets-host [])`.

| Port | Where | Notes |
| --- | --- | --- |
| shen-go | `kl/shenx_sha256.go` + `InstallShenX` after boot | `crypto/sha256` |
| shen-lua | end of `prims.install_native_stdlib` | OpenSSL FFI |
| shen-rust | `primitives::register_shenx` from hot overrides | `sha2` crate |
| shen-cl | `ports/shen-cl/sha256-host.lsp` | requires `shen-cl.load-lisp` in image |

`SHEN_X_SHA256=pure` disables host install on go/lua/rust.
