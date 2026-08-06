\\ Bifrost agreement: timeout semantics.
\\   - rcvtimeo expiry RETURNS the symbol shen.x.zmq.timeout (never raised);
\\   - poll with Ms 0 (snapshot) and Ms > 0 on an empty socket → [];
\\   - shen.x.zmq.timeout? predicate.
\\ Deterministic transcript: no timings printed.
\\
\\ Run: ./scripts/shen-x go script programs/zmq-timeout.shen

(load "shen/x/zmq.shen")

(define shen.x.zto.check
  Name Got Want -> (if (= Got Want)
                       (do (output "ok ~A~%" Name) 0)
                       (do (output "FAIL ~A~%" Name)
                           (output "  got  ~A~%" Got)
                           (output "  want ~A~%" Want)
                           1)))

(define main
  -> (let S (shen.x.zmq.socket pull)
          B (shen.x.zmq.bind S "inproc://zmq-timeout")
          O (shen.x.zmq.set-option S rcvtimeo 50)
          R (shen.x.zmq.recv S)
          F1 (shen.x.zto.check "rcvtimeo-returns-sentinel"
                               (shen.x.zmq.timeout? R) true)
          F2 (shen.x.zto.check "timeout?-false-on-frames"
                               (shen.x.zmq.timeout? [[1]]) false)
          F3 (shen.x.zto.check "poll-0-empty"
                               (shen.x.zmq.poll [S] 0) [])
          F4 (shen.x.zto.check "poll-positive-empty"
                               (shen.x.zmq.poll [S] 50) [])
          C (shen.x.zmq.close S)
          T (shen.x.zmq.term)
       (if (= (+ F1 (+ F2 (+ F3 F4))) 0)
           (do (output "zmq-timeout PASS~%") true)
           (do (output "zmq-timeout FAIL~%") false))))

(main)
