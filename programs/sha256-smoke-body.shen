\\ Smoke body only (no loads). Used after pure+portable in multi-file shake.
(define main
  -> (do (output "~A~%"
                 (shen.x.sha256-hex (shen.x.string->octets "abc")))
         true))

(main)
