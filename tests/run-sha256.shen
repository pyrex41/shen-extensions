\\ Bifrost entrypoint: pure-or-host SHA-256 vector suite.
\\ Deterministic output + ALL PASS marker for cross-port agreement.
\\
\\ Run from repo root:
\\   shen-go script tests/run-sha256.shen
\\   bifrost -suite bifrost.suite.json

(load "shen/x/sha256.shen")

(define shen.x.test.check
  Name Got Want Passes Fails ->
    (if (= Got Want)
        (do (output "ok  ~A~%" Name)
            [(+ Passes 1) Fails])
        (do (output "FAIL ~A~%" Name)
            (output "  got  ~A~%" Got)
            (output "  want ~A~%" Want)
            [Passes (+ Fails 1)])))

(define shen.x.test.hex
  Name InputHex WantHex Passes Fails ->
    (shen.x.test.check
      Name
      (shen.x.sha256-hex (shen.x.string->octets InputHex))
      WantHex
      Passes Fails))

\\ NIST / FIPS 180-4 examples (and empty message)
\\ Note: do not print backend name — Bifrost agreement requires byte-identical
\\ stdout across pure and host ports.
(define shen.x.test.run
  ->
    (let S0 (shen.x.test.check
              "empty"
              (shen.x.sha256-hex [])
              "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
              0 0)
         S1 (shen.x.test.hex
              "abc"
              "abc"
              "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
              (hd S0) (hd (tl S0)))
         S2 (shen.x.test.hex
              "abc-long"
              "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
              "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
              (hd S1) (hd (tl S1)))
         S3 (shen.x.test.hex
              "quick-fox"
              "The quick brown fox jumps over the lazy dog"
              "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592"
              (hd S2) (hd (tl S2)))
         S4 (shen.x.test.hex
              "quick-fox-dot"
              "The quick brown fox jumps over the lazy dog."
              "ef537f25c895bfa782526529a9b63d97aa631564d5d789c2b765448c8635fb6c"
              (hd S3) (hd (tl S3)))
         S5 (shen.x.test.check
              "byte-00"
              (shen.x.sha256-hex [0])
              "6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d"
              (hd S4) (hd (tl S4)))
         S6 (shen.x.test.check
              "bytes-0-1-2"
              (shen.x.sha256-hex [0 1 2])
              "ae4b3280e56e2faf83f414a6e3dabe9d5fbe18976544c05fed121accb85b53fc"
              (hd S5) (hd (tl S5)))
         Pass (hd S6)
         Fail (hd (tl S6))
      (do (output "sha256-vectors: ~A/~A passed~%" Pass (+ Pass Fail))
          (if (= Fail 0)
              (do (output "ALL PASS~%") true)
              (do (output "SOME FAIL~%") false)))))

(shen.x.test.run)
