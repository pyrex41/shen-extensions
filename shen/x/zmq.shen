\\ shen.x.zmq — portable ZeroMQ messaging (host-only, no pure fallback)
\\
\\ Contract:
\\   (shen.x.zmq-backend)            -> host | absent
\\   (shen.x.zmq.socket Type)        Type in {req rep pub sub push pull pair
\\                                            dealer router} -> handle int
\\   (shen.x.zmq.bind S Endpoint)    -> true
\\   (shen.x.zmq.connect S Endpoint) -> true
\\   (shen.x.zmq.send S Frames)      Frames = non-empty list of octet lists
\\                                   -> true | shen.x.zmq.timeout
\\   (shen.x.zmq.recv S)             -> Frames | shen.x.zmq.timeout
\\   (shen.x.zmq.poll Ss Ms)         -> readable subset of Ss, order preserved
\\   (shen.x.zmq.endpoint S)         -> last bound endpoint string
\\   (shen.x.zmq.close S)            -> true
\\   (shen.x.zmq.term)               -> true (closes all sockets; idempotent)
\\   (shen.x.zmq.set-option S Opt V) Opt in {rcvtimeo sndtimeo subscribe
\\                                           unsubscribe linger} -> true
\\   (shen.x.zmq.subscribe S Topic)  Topic string -> true
\\   (shen.x.zmq.unsubscribe S Topic)             -> true
\\   (shen.x.zmq.send-string S Str)   -> true | shen.x.zmq.timeout
\\   (shen.x.zmq.send-strings S Strs) -> true | shen.x.zmq.timeout
\\   (shen.x.zmq.recv-string S)       -> string | shen.x.zmq.timeout
\\   (shen.x.zmq.recv-strings S)      -> list of strings | shen.x.zmq.timeout
\\   (shen.x.zmq.timeout? X)          -> boolean
\\   (shen.x.zmq.with-socket Type F)  -> (F S) with S always closed
\\
\\ There is NO pure fallback (this is I/O). Host ports bind the 10 waist
\\ primitives (shen.x.zmq.socket-host .. shen.x.zmq.term-host) and set the
\\ global shen.x.*zmq-backend* to host; see ports/README.md. On ports without
\\ a host every API call raises a catchable error. Detection reads the global
\\ ONLY — no probe call, since probing would create sockets.

(define shen.x.zmq.host?
  -> (trap-error
       (= (value shen.x.*zmq-backend*) host)
       (/. E false)))

(define shen.x.zmq-backend
  -> (if (shen.x.zmq.host?) host absent))

(define shen.x.zmq.ensure-host
  -> (if (shen.x.zmq.host?)
         true
         (simple-error
           "shen.x.zmq: no host backend on this port (see shen-extensions/ports/README.md)")))

\\ ---- thin wrappers over the host waist ----

(define shen.x.zmq.socket
  Type -> (do (shen.x.zmq.ensure-host)
              (shen.x.zmq.socket-host Type)))

(define shen.x.zmq.bind
  S Endpoint -> (do (shen.x.zmq.ensure-host)
                    (shen.x.zmq.bind-host S Endpoint)))

(define shen.x.zmq.connect
  S Endpoint -> (do (shen.x.zmq.ensure-host)
                    (shen.x.zmq.connect-host S Endpoint)))

(define shen.x.zmq.send
  S Frames -> (do (shen.x.zmq.ensure-host)
                  (shen.x.zmq.send-host S Frames)))

(define shen.x.zmq.recv
  S -> (do (shen.x.zmq.ensure-host)
           (shen.x.zmq.recv-host S)))

(define shen.x.zmq.poll
  Ss Ms -> (do (shen.x.zmq.ensure-host)
               (shen.x.zmq.poll-host Ss Ms)))

(define shen.x.zmq.endpoint
  S -> (do (shen.x.zmq.ensure-host)
           (shen.x.zmq.endpoint-host S)))

(define shen.x.zmq.close
  S -> (do (shen.x.zmq.ensure-host)
           (shen.x.zmq.close-host S)))

(define shen.x.zmq.term
  -> (do (shen.x.zmq.ensure-host)
         (shen.x.zmq.term-host)))

\\ ---- options ----

\\ subscribe/unsubscribe take octet-list topics at the waist; a string value
\\ is converted here. Everything else passes through untouched.
(define shen.x.zmq.option-value
  subscribe V -> (if (string? V) (shen.x.zmq.string->octets V) V)
  unsubscribe V -> (if (string? V) (shen.x.zmq.string->octets V) V)
  _ V -> V)

(define shen.x.zmq.set-option
  S Opt V -> (do (shen.x.zmq.ensure-host)
                 (shen.x.zmq.setopt-host S Opt (shen.x.zmq.option-value Opt V))))

(define shen.x.zmq.subscribe
  S Topic -> (shen.x.zmq.set-option S subscribe Topic))

(define shen.x.zmq.unsubscribe
  S Topic -> (shen.x.zmq.set-option S unsubscribe Topic))

\\ ---- string convenience ----

(define shen.x.zmq.send-string
  S Str -> (shen.x.zmq.send S [(shen.x.zmq.string->octets Str)]))

(define shen.x.zmq.send-strings
  S Strs -> (shen.x.zmq.send S (map (/. Str (shen.x.zmq.string->octets Str)) Strs)))

(define shen.x.zmq.recv-string
  S -> (shen.x.zmq.recv-string-h (shen.x.zmq.recv S)))

(define shen.x.zmq.recv-string-h
  shen.x.zmq.timeout -> shen.x.zmq.timeout
  [Frame] -> (shen.x.zmq.octets->string Frame)
  _ -> (simple-error "shen.x.zmq: recv-string: multipart message"))

(define shen.x.zmq.recv-strings
  S -> (shen.x.zmq.recv-strings-h (shen.x.zmq.recv S)))

(define shen.x.zmq.recv-strings-h
  shen.x.zmq.timeout -> shen.x.zmq.timeout
  Frames -> (map (/. Frame (shen.x.zmq.octets->string Frame)) Frames))

(define shen.x.zmq.timeout?
  shen.x.zmq.timeout -> true
  _ -> false)

\\ ---- with-socket: make socket, apply F, ALWAYS close ----

\\ The success-path close is trapped so a body that already closed S (close is
\\ public API) still returns its value instead of raising a spurious
\\ closed-or-unknown-handle error; close-reraise does the same on the error path.
(define shen.x.zmq.with-socket
  Type F -> (let S (shen.x.zmq.socket Type)
              (let R (trap-error (F S) (/. E (shen.x.zmq.close-reraise S E)))
                (do (trap-error (shen.x.zmq.close S) (/. E true))
                    R))))

(define shen.x.zmq.close-reraise
  S E -> (do (trap-error (shen.x.zmq.close S) (/. E2 true))
             (simple-error (error-to-string E))))

\\ ---- string/octet helpers (self-contained; do not depend on sha256.shen) ----

\\ Portable string length: (length S) is list-only on some ports (e.g. shen-go).
(define shen.x.zmq.string-length
  S -> (shen.x.zmq.string-length-h S 0))

\\ The trap-error is confined to probing one index and the recursion is a tail
\\ call OUTSIDE it, so handler frames never nest (pcall-per-trap-error ports
\\ have shallow C-call limits) and depth is O(1) on tail-call-optimising ports.
(define shen.x.zmq.string-length-h
  S I -> (if (trap-error (do (pos S I) true) (/. E false))
             (shen.x.zmq.string-length-h S (+ I 1))
             I))

\\ Octet/string conversions are tail-recursive with accumulators: frame sizes
\\ are peer-controlled, so non-tail recursion of depth = message size would
\\ overflow the stack on ports without stack growth.
(define shen.x.zmq.string->octets
  S -> (shen.x.zmq.string->octets-h S (- (shen.x.zmq.string-length S) 1) []))

(define shen.x.zmq.string->octets-h
  S I Acc -> (if (< I 0)
                 Acc
                 (shen.x.zmq.string->octets-h S (- I 1)
                   [(string->n (pos S I)) | Acc])))

(define shen.x.zmq.octets->string
  Bs -> (shen.x.zmq.octets->string-h Bs ""))

(define shen.x.zmq.octets->string-h
  [] Acc -> Acc
  [B | Bs] Acc -> (shen.x.zmq.octets->string-h Bs (cn Acc (n->string B))))
