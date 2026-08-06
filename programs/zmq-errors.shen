\\ Bifrost agreement: contract error strings (host present).
\\ Traps each reachable error and prints the caught message VERBATIM:
\\   unknown socket type, bad handle, unknown option, malformed send payload,
\\   endpoint before bind, recv-string on a multipart message.
\\ Handles are allocated in a fixed order (real sockets first), so the
\\ handle-bearing messages are deterministic.
\\
\\ Run: ./scripts/shen-x go script programs/zmq-errors.shen

(load "shen/x/zmq.shen")

(define shen.x.zer.caught
  Thunk -> (trap-error (do (thaw Thunk) "no error raised")
                       (/. E (error-to-string E))))

(define shen.x.zer.all
  [] -> true
  [true | Rest] -> (shen.x.zer.all Rest)
  [_ | _] -> false)

(define main
  -> (let Push (shen.x.zmq.socket push)
          Pull (shen.x.zmq.socket pull)
          E1 (shen.x.zer.caught (freeze (shen.x.zmq.socket foo)))
          E2 (shen.x.zer.caught (freeze (shen.x.zmq.close 999)))
          E3 (shen.x.zer.caught (freeze (shen.x.zmq.set-option Push badopt 1)))
          E4 (shen.x.zer.caught (freeze (shen.x.zmq.send Push [[256]])))
          E5 (shen.x.zer.caught (freeze (shen.x.zmq.endpoint Push)))
          B (shen.x.zmq.bind Pull "inproc://zmq-errors")
          C (shen.x.zmq.connect Push "inproc://zmq-errors")
          SM (shen.x.zmq.send Push [[104] [105]])
          E6 (shen.x.zer.caught (freeze (shen.x.zmq.recv-string Pull)))
          P1 (output "~A~%" E1)
          P2 (output "~A~%" E2)
          P3 (output "~A~%" E3)
          P4 (output "~A~%" E4)
          P5 (output "~A~%" E5)
          P6 (output "~A~%" E6)
          Ok (shen.x.zer.all
               [(= E1 "shen.x.zmq: unknown socket type: foo")
                (= E2 "shen.x.zmq: closed or unknown socket handle: 999")
                (= E3 "shen.x.zmq: unknown option: badopt")
                (= E4 "shen.x.zmq: expected list of frames (lists of ints 0..255)")
                (= E5 (cn "shen.x.zmq: socket not bound: " (str Push)))
                (= E6 "shen.x.zmq: recv-string: multipart message")])
          C1 (shen.x.zmq.close Push)
          C2 (shen.x.zmq.close Pull)
          T (shen.x.zmq.term)
       (if Ok
           (do (output "zmq-errors PASS~%") true)
           (do (output "zmq-errors FAIL~%") false))))

(main)
