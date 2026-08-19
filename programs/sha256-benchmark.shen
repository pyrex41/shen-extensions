\\ Small, reproducible host-vs-pure SHA-256 benchmark.
\\
\\ The two paths use different iteration counts so each run is long enough to
\\ measure without making the pure Shen case unnecessarily slow. Compare the
\\ reported hashes/second, not the raw elapsed time.
\\
\\   ./scripts/shen-x cl script programs/sha256-benchmark.shen
\\   SHEN_X_SHA256=pure ./scripts/shen-x cl script programs/sha256-benchmark.shen

(load "shen/x/sha256.shen")

(define shen.x.sha256-bench.bytes
  0 -> []
  N -> [97 | (shen.x.sha256-bench.bytes (- N 1))])

(define shen.x.sha256-bench.loop
  0 Bytes -> true
  N Bytes -> (do (shen.x.sha256-octets Bytes)
                 (shen.x.sha256-bench.loop (- N 1) Bytes)))

(define shen.x.sha256-bench.iterations
  host -> 100000
  pure -> 10)

(define shen.x.sha256-bench.main
  -> (let Backend (shen.x.sha256-backend)
          Iterations (shen.x.sha256-bench.iterations Backend)
          Bytes (shen.x.sha256-bench.bytes 64)
          Warmup (shen.x.sha256-octets Bytes)
          Start (get-time run)
          Done (shen.x.sha256-bench.loop Iterations Bytes)
          Seconds (- (get-time run) Start)
       (do (output "backend=~A hashes=~A bytes/hash=64 seconds=~A hashes/second=~A~%"
                   Backend Iterations Seconds (/ Iterations Seconds))
           true)))

(shen.x.sha256-bench.main)
