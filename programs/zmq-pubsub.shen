\\ Bifrost agreement: PUB/SUB topic-filter proof, deterministic under the
\\ slow-joiner race:
\\   1. subscribe FIRST (topic "A"), then connect;
\\   2. loop (bounded 100): publish "A hello" + "B nope", poll SUB ~100ms,
\\      repeat until readable;
\\   3. drain with a small rcvtimeo: every matched message must be "A hello";
\\      the drain ends on the timeout symbol, proving "B nope" was filtered.
\\ Never prints counts, endpoints, or timings.
\\
\\ Run: ./scripts/shen-x go script programs/zmq-pubsub.shen

(load "shen/x/zmq.shen")

(define shen.x.zps.ready
  Pub Sub 0 -> false
  Pub Sub N -> (let S1 (shen.x.zmq.send-string Pub "A hello")
                    S2 (shen.x.zmq.send-string Pub "B nope")
                    R (shen.x.zmq.poll [Sub] 100)
                 (if (= R [Sub])
                     true
                     (shen.x.zps.ready Pub Sub (- N 1)))))

\\ Drain matched messages first; end cleanly on the timeout symbol.
(define shen.x.zps.drain
  Sub -> (let R (shen.x.zmq.recv-string Sub)
           (if (shen.x.zmq.timeout? R)
               true
               (if (= R "A hello")
                   (shen.x.zps.drain Sub)
                   false))))

(define main
  -> (let Pub (shen.x.zmq.socket pub)
          B (shen.x.zmq.bind Pub "inproc://zmq-pubsub")
          Sub (shen.x.zmq.socket sub)
          SB (shen.x.zmq.subscribe Sub "A")
          C (shen.x.zmq.connect Sub "inproc://zmq-pubsub")
          Ready (shen.x.zps.ready Pub Sub 100)
          P1 (if Ready
                 (output "ok slow-joiner~%")
                 (output "FAIL slow-joiner~%"))
          O (shen.x.zmq.set-option Sub rcvtimeo 200)
          Filtered (shen.x.zps.drain Sub)
          P2 (if Filtered
                 (output "ok filter~%")
                 (output "FAIL filter~%"))
          C1 (shen.x.zmq.close Sub)
          C2 (shen.x.zmq.close Pub)
          T (shen.x.zmq.term)
       (if (and Ready Filtered)
           (do (output "zmq-pubsub PASS~%") true)
           (do (output "zmq-pubsub FAIL~%") false))))

(main)
