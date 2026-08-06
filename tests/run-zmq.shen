\\ Bifrost entrypoint: host-only ZMQ suite (shen/x/zmq.shen).
\\ All checks inline (duplicated minimal asserts from programs/zmq-*.shen),
\\ one line per group, final ALL PASS marker. Deterministic: never prints
\\ endpoints, ports, counts, or timings.
\\
\\ Run from repo root:
\\   ./scripts/shen-x go script tests/run-zmq.shen
\\   make bifrost-zmq

(load "shen/x/zmq.shen")

(define shen.x.zt.group
  Name Result Passes Fails ->
    (if (= Result true)
        (do (output "ok  ~A~%" Name)
            [(+ Passes 1) Fails])
        (do (output "FAIL ~A~%" Name)
            [Passes (+ Fails 1)])))

(define shen.x.zt.all
  [] -> true
  [true | Rest] -> (shen.x.zt.all Rest)
  [_ | _] -> false)

\\ ---- push/pull: inproc + tcp (:0, endpoint read back, never printed) ----

(define shen.x.zt.pp-one
  Endpoint ->
    (let Pull (shen.x.zmq.socket pull)
         B (shen.x.zmq.bind Pull Endpoint)
         Ep (shen.x.zmq.endpoint Pull)
         Push (shen.x.zmq.socket push)
         C (shen.x.zmq.connect Push Ep)
         S1 (shen.x.zmq.send Push [[104 105]])
         R1 (shen.x.zmq.recv Pull)
         S2 (shen.x.zmq.send Push [[1 2 3] [] [255 0 128]])
         R2 (shen.x.zmq.recv Pull)
         C1 (shen.x.zmq.close Push)
         C2 (shen.x.zmq.close Pull)
      (shen.x.zt.all [(= R1 [[104 105]])
                      (= R2 [[1 2 3] [] [255 0 128]])])))

(define shen.x.zt.pushpull
  -> (shen.x.zt.all [(shen.x.zt.pp-one "inproc://zt-pushpull")
                     (shen.x.zt.pp-one "tcp://127.0.0.1:0")]))

\\ ---- req/rep: 3 round-trips in one thread over inproc ----

(define shen.x.zt.rr-round
  Req Rep N ->
    (let M (cn "ping-" (str N))
         S1 (shen.x.zmq.send-string Req M)
         Q (shen.x.zmq.recv-string Rep)
         S2 (shen.x.zmq.send-string Rep (cn "pong:" M))
         A (shen.x.zmq.recv-string Req)
      (shen.x.zt.all [(= Q M) (= A (cn "pong:" M))])))

(define shen.x.zt.reqrep
  -> (let Rep (shen.x.zmq.socket rep)
          B (shen.x.zmq.bind Rep "inproc://zt-reqrep")
          Req (shen.x.zmq.socket req)
          C (shen.x.zmq.connect Req "inproc://zt-reqrep")
          R1 (shen.x.zt.rr-round Req Rep 1)
          R2 (shen.x.zt.rr-round Req Rep 2)
          R3 (shen.x.zt.rr-round Req Rep 3)
          C1 (shen.x.zmq.close Req)
          C2 (shen.x.zmq.close Rep)
       (shen.x.zt.all [R1 R2 R3])))

\\ ---- pub/sub: subscribe first, publish+poll retry (slow joiner), then
\\      drain matched and end on the timeout symbol (filter proof) ----

(define shen.x.zt.ps-ready
  Pub Sub 0 -> false
  Pub Sub N -> (let S1 (shen.x.zmq.send-string Pub "A hello")
                    S2 (shen.x.zmq.send-string Pub "B nope")
                    R (shen.x.zmq.poll [Sub] 100)
                 (if (= R [Sub])
                     true
                     (shen.x.zt.ps-ready Pub Sub (- N 1)))))

(define shen.x.zt.ps-drain
  Sub -> (let R (shen.x.zmq.recv-string Sub)
           (if (shen.x.zmq.timeout? R)
               true
               (if (= R "A hello")
                   (shen.x.zt.ps-drain Sub)
                   false))))

(define shen.x.zt.pubsub
  -> (let Pub (shen.x.zmq.socket pub)
          B (shen.x.zmq.bind Pub "inproc://zt-pubsub")
          Sub (shen.x.zmq.socket sub)
          SB (shen.x.zmq.subscribe Sub "A")
          C (shen.x.zmq.connect Sub "inproc://zt-pubsub")
          Ready (shen.x.zt.ps-ready Pub Sub 100)
          O (shen.x.zmq.set-option Sub rcvtimeo 200)
          Filtered (shen.x.zt.ps-drain Sub)
          C1 (shen.x.zmq.close Sub)
          C2 (shen.x.zmq.close Pub)
       (shen.x.zt.all [Ready Filtered])))

\\ ---- timeout: rcvtimeo sentinel, poll 0/positive on empty, predicate ----

(define shen.x.zt.timeout
  -> (let S (shen.x.zmq.socket pull)
          B (shen.x.zmq.bind S "inproc://zt-timeout")
          O (shen.x.zmq.set-option S rcvtimeo 50)
          R (shen.x.zmq.recv S)
          P0 (shen.x.zmq.poll [S] 0)
          P1 (shen.x.zmq.poll [S] 50)
          C (shen.x.zmq.close S)
       (shen.x.zt.all [(shen.x.zmq.timeout? R)
                       (= (shen.x.zmq.timeout? [[1]]) false)
                       (= P0 [])
                       (= P1 [])])))

\\ ---- errors: contract strings verbatim (host present) ----

(define shen.x.zt.caught
  Thunk -> (trap-error (do (thaw Thunk) "no error raised")
                       (/. E (error-to-string E))))

(define shen.x.zt.errors
  -> (let Push (shen.x.zmq.socket push)
          Pull (shen.x.zmq.socket pull)
          E1 (shen.x.zt.caught (freeze (shen.x.zmq.socket foo)))
          E2 (shen.x.zt.caught (freeze (shen.x.zmq.close 999)))
          E3 (shen.x.zt.caught (freeze (shen.x.zmq.set-option Push badopt 1)))
          E4 (shen.x.zt.caught (freeze (shen.x.zmq.send Push [[256]])))
          E5 (shen.x.zt.caught (freeze (shen.x.zmq.endpoint Push)))
          B (shen.x.zmq.bind Pull "inproc://zt-errors")
          C (shen.x.zmq.connect Push "inproc://zt-errors")
          SM (shen.x.zmq.send Push [[104] [105]])
          E6 (shen.x.zt.caught (freeze (shen.x.zmq.recv-string Pull)))
          C1 (shen.x.zmq.close Push)
          C2 (shen.x.zmq.close Pull)
       (shen.x.zt.all
         [(= E1 "shen.x.zmq: unknown socket type: foo")
          (= E2 "shen.x.zmq: closed or unknown socket handle: 999")
          (= E3 "shen.x.zmq: unknown option: badopt")
          (= E4 "shen.x.zmq: expected list of frames (lists of ints 0..255)")
          (= E5 (cn "shen.x.zmq: socket not bound: " (str Push)))
          (= E6 "shen.x.zmq: recv-string: multipart message")])))

\\ ---- runner ----

(define shen.x.zt.run
  -> (let S0 (shen.x.zt.group "zmq-pushpull" (shen.x.zt.pushpull) 0 0)
          S1 (shen.x.zt.group "zmq-reqrep" (shen.x.zt.reqrep)
                              (hd S0) (hd (tl S0)))
          S2 (shen.x.zt.group "zmq-pubsub" (shen.x.zt.pubsub)
                              (hd S1) (hd (tl S1)))
          S3 (shen.x.zt.group "zmq-timeout" (shen.x.zt.timeout)
                              (hd S2) (hd (tl S2)))
          S4 (shen.x.zt.group "zmq-errors" (shen.x.zt.errors)
                              (hd S3) (hd (tl S3)))
          T (shen.x.zmq.term)
          Pass (hd S4)
          Fail (hd (tl S4))
       (do (output "zmq-groups: ~A/~A passed~%" Pass (+ Pass Fail))
           (if (= Fail 0)
               (do (output "ALL PASS~%") true)
               (do (output "SOME FAIL~%") false)))))

(shen.x.zt.run)
