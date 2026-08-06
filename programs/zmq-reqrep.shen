\\ Bifrost agreement: REQ/REP over inproc, 3 request/reply round-trips in one
\\ thread (send req → recv rep-side → send reply → recv req-side).
\\ Deterministic transcript: no endpoints, no timings.
\\
\\ Run: ./scripts/shen-x go script programs/zmq-reqrep.shen

(load "shen/x/zmq.shen")

(define shen.x.zrr.check
  Name Got Want -> (if (= Got Want)
                       (do (output "ok ~A~%" Name) 0)
                       (do (output "FAIL ~A~%" Name)
                           (output "  got  ~A~%" Got)
                           (output "  want ~A~%" Want)
                           1)))

(define shen.x.zrr.round
  Req Rep N ->
    (let M (cn "ping-" (str N))
         S1 (shen.x.zmq.send-string Req M)
         Q (shen.x.zmq.recv-string Rep)
         F1 (shen.x.zrr.check (cn "request-" (str N)) Q M)
         S2 (shen.x.zmq.send-string Rep (cn "pong:" M))
         A (shen.x.zmq.recv-string Req)
         F2 (shen.x.zrr.check (cn "reply-" (str N)) A (cn "pong:" M))
      (+ F1 F2)))

(define main
  -> (let Rep (shen.x.zmq.socket rep)
          B (shen.x.zmq.bind Rep "inproc://zmq-reqrep")
          Req (shen.x.zmq.socket req)
          C (shen.x.zmq.connect Req "inproc://zmq-reqrep")
          F1 (shen.x.zrr.round Req Rep 1)
          F2 (shen.x.zrr.round Req Rep 2)
          F3 (shen.x.zrr.round Req Rep 3)
          C1 (shen.x.zmq.close Req)
          C2 (shen.x.zmq.close Rep)
          T (shen.x.zmq.term)
       (if (= (+ F1 (+ F2 F3)) 0)
           (do (output "zmq-reqrep PASS~%") true)
           (do (output "zmq-reqrep FAIL~%") false))))

(main)
