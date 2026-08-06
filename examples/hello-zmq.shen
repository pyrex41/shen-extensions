\\ Minimal user program: push/pull hello over inproc.
\\ Requires a port with a zmq host backend (shen-go today):
\\   ./scripts/shen-x go script examples/hello-zmq.shen
\\
\\ Or manually from the extensions root:
\\   (load "shen/x/zmq.shen")
\\   …same body…

(load "shen/x/zmq.shen")

(define main
  -> (let Pull (shen.x.zmq.socket pull)
          B (shen.x.zmq.bind Pull "inproc://hello")
          Push (shen.x.zmq.socket push)
          C (shen.x.zmq.connect Push "inproc://hello")
          S (shen.x.zmq.send-string Push "hello, zmq")
          R (shen.x.zmq.recv-string Pull)
          T (shen.x.zmq.term)
       (do (output "~A~%" R)
           true)))

(main)
