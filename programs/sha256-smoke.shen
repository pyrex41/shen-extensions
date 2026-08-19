\\ Minimal Yggdrasil shake target: load pure SHA-256, hash "abc", print hex.
\\ Self-contained entry for stage-1 shake + deploy-path parity.

(load "shen/x/sha256.shen")

(define main
  -> (do (output "~A~%"
                 (shen.x.sha256-hex (shen.x.string->octets "abc")))
         true))

(main)
