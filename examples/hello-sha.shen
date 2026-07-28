\\ Minimal user program: Shen + extension only.
\\ Run from anywhere via:
\\   ./scripts/shen-x go script examples/hello-sha.shen
\\   ./scripts/shen-x lua examples/hello-sha.shen
\\
\\ Or manually from the extensions root:
\\   (load "load.shen")
\\   …same body…

(load "load.shen")

(define main
  -> (do (output "backend=~A~%" (shen.x.sha256-backend))
         (output "~A~%"
                 (shen.x.sha256-hex (shen.x.string->octets "abc")))
         true))

(main)
