\\ Bifrost agreement: PUSH/PULL roundtrip over inproc AND tcp (ephemeral :0),
\\ single-frame and multipart (3 frames incl. an empty frame).
\\ Deterministic transcript: never prints endpoints or ports.
\\
\\ Run: ./scripts/shen-x go script programs/zmq-pushpull.shen

(load "shen/x/zmq.shen")

(define shen.x.zpp.check
  Name Got Want -> (if (= Got Want)
                       (do (output "ok ~A~%" Name) 0)
                       (do (output "FAIL ~A~%" Name)
                           (output "  got  ~A~%" Got)
                           (output "  want ~A~%" Want)
                           1)))

\\ Bind PULL on Endpoint (tcp://127.0.0.1:0 → real port read back via
\\ endpoint, never printed), connect PUSH, roundtrip single + multipart.
(define shen.x.zpp.roundtrip
  Tag Endpoint ->
    (let Pull (shen.x.zmq.socket pull)
         B (shen.x.zmq.bind Pull Endpoint)
         Ep (shen.x.zmq.endpoint Pull)
         Push (shen.x.zmq.socket push)
         C (shen.x.zmq.connect Push Ep)
         S1 (shen.x.zmq.send Push [[104 105]])
         F1 (shen.x.zpp.check (cn Tag "-single")
                              (shen.x.zmq.recv Pull)
                              [[104 105]])
         S2 (shen.x.zmq.send Push [[1 2 3] [] [255 0 128]])
         F2 (shen.x.zpp.check (cn Tag "-multipart")
                              (shen.x.zmq.recv Pull)
                              [[1 2 3] [] [255 0 128]])
         C1 (shen.x.zmq.close Push)
         C2 (shen.x.zmq.close Pull)
      (+ F1 F2)))

(define main
  -> (let FI (shen.x.zpp.roundtrip "inproc" "inproc://zmq-pushpull")
          FT (shen.x.zpp.roundtrip "tcp" "tcp://127.0.0.1:0")
          T (shen.x.zmq.term)
       (if (= (+ FI FT) 0)
           (do (output "zmq-pushpull PASS~%") true)
           (do (output "zmq-pushpull FAIL~%") false))))

(main)
