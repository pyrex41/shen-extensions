\\ shen.x.sha256 — portable SHA-256 over octet lists (FIPS 180-4)
\\
\\ Contract:
\\   (shen.x.sha256-octets Bs)  Bs = proper list of integers in 0..255
\\                           -> 32-element list of integers in 0..255
\\   (shen.x.sha256-hex Bs)     -> 64-char lowercase hex string
\\   (shen.x.sha256-backend)    -> pure | host
\\
\\ Host ports bind shen.x.sha256-octets-host. Pure oracle lives in
\\ shen/x/sha256-pure.shen and is lazy-loaded only when host is absent
\\ (so Lua never compiles pure tables on the host path; no load-echo noise).

(define shen.x.host-sha256?
  -> (trap-error
       (do (shen.x.sha256-octets-host []) true)
       (/. E false)))

(define shen.x.sha256-backend
  -> (if (shen.x.host-sha256?) host pure))

(define shen.x.ensure-pure
  -> (trap-error
       (value shen.x.*pure-loaded*)
       (/. E (do (load "shen/x/sha256-pure.shen")
                 (set shen.x.*pure-loaded* true)))))

(define shen.x.sha256-octets
  Bs -> (if (shen.x.host-sha256?)
            (shen.x.sha256-octets-host Bs)
            (do (shen.x.ensure-pure)
                (shen.x.sha256-octets-pure Bs))))

\\ ---- hex ----

(define shen.x.hex-digit
  0 -> "0"
  1 -> "1"
  2 -> "2"
  3 -> "3"
  4 -> "4"
  5 -> "5"
  6 -> "6"
  7 -> "7"
  8 -> "8"
  9 -> "9"
  10 -> "a"
  11 -> "b"
  12 -> "c"
  13 -> "d"
  14 -> "e"
  15 -> "f"
  N -> (simple-error "shen.x.hex-digit"))

(define shen.x.quot-small
  N M -> (if (< N M) 0 (+ 1 (shen.x.quot-small (- N M) M))))

(define shen.x.rem-small
  N M -> (- N (* M (shen.x.quot-small N M))))

(define shen.x.byte-hex
  B -> (cn (shen.x.hex-digit (shen.x.quot-small B 16))
           (shen.x.hex-digit (shen.x.rem-small B 16))))

(define shen.x.octets-hex
  [] -> ""
  [B | Bs] -> (cn (shen.x.byte-hex B) (shen.x.octets-hex Bs)))

(define shen.x.sha256-hex
  Bs -> (shen.x.octets-hex (shen.x.sha256-octets Bs)))

\\ Portable string length: (length S) is list-only on some ports (e.g. shen-go).
(define shen.x.string-length
  S -> (shen.x.string-length-h S 0))

(define shen.x.string-length-h
  S I -> (trap-error
           (do (pos S I)
               (shen.x.string-length-h S (+ I 1)))
           (/. E I)))

(define shen.x.string->octets
  S -> (shen.x.string->octets-h S 0 (shen.x.string-length S)))

(define shen.x.string->octets-h
  S I N -> (if (>= I N)
               []
               [(string->n (pos S I))
                | (shen.x.string->octets-h S (+ I 1) N)]))
