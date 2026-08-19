\\ Public API for multi-file Yggdrasil / standalone artifacts.
\\ Prefer host when the port installed shen.x.sha256-octets-host (and set
\\ shen.x.*sha256-backend* to host); otherwise pure (load sha256-pure.shen first).
\\
\\ No (load …) — pure must already be in the shake file list.

(define shen.x.host-sha256?
  -> (trap-error
       (= (value shen.x.*sha256-backend*) host)
       (/. E
           (trap-error
             (do (shen.x.sha256-octets-host []) true)
             (/. E2 false)))))

(define shen.x.sha256-backend
  -> (if (shen.x.host-sha256?) host pure))

(define shen.x.sha256-octets
  Bs -> (if (shen.x.host-sha256?)
            (shen.x.sha256-octets-host Bs)
            (shen.x.sha256-octets-pure Bs)))

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
