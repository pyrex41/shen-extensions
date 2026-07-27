\\ shen.x.sha256-pure — pure Shen oracle (loaded only when host is absent)
\\ Do not load this file directly when a host backend is available; use shen/x/sha256.shen.

\\ ---- u32 arithmetic ----

(define shen.x.u32.mod
  N -> (shen.x.u32.mod-pos N))

(define shen.x.u32.mod-pos
  N -> (if (< N 0)
           (shen.x.u32.mod-pos (+ N 4294967296))
           (if (>= N 4294967296)
               (shen.x.u32.mod-pos (- N 4294967296))
               N)))

(define shen.x.u32.add
  A B -> (shen.x.u32.mod (+ A B)))

(define shen.x.u32.add3
  A B C -> (shen.x.u32.add (shen.x.u32.add A B) C))

(define shen.x.u32.add4
  A B C D -> (shen.x.u32.add (shen.x.u32.add3 A B C) D))

(define shen.x.u32.add5
  A B C D E -> (shen.x.u32.add (shen.x.u32.add4 A B C D) E))

\\ Binary quotient N/M for nonnegative integers.
\\ Fast path: host `/` when the result is an exact integer (power-of-2
\\ shifts and aligned divides on every port).
(define shen.x.quot
  N M -> (if (or (< N 0) (<= M 0))
             (simple-error "shen.x.quot: need N>=0 M>0")
             (if (< N M)
                 0
                 (let Q (/ N M)
                   (if (integer? Q)
                       Q
                       (shen.x.quot-slow N M))))))

(define shen.x.quot-slow
  N M -> (if (< N M)
             0
             (let Q (shen.x.quot-slow N (* M 2))
                  R (- N (* Q (* M 2)))
               (if (< R M)
                   (* Q 2)
                   (+ (* Q 2) 1)))))

(define shen.x.rem
  N M -> (- N (* M (shen.x.quot N M))))

\\ Tables as 0-arity defines so (load) does not echo giant lists (Bifrost).
(define shen.x.pow2-table
  -> [1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768
      65536 131072 262144 524288 1048576 2097152 4194304 8388608
      16777216 33554432 67108864 134217728 268435456 536870912
      1073741824 2147483648 4294967296])

(define shen.x.pow2
  K -> (shen.x.list.nth K (shen.x.pow2-table)))

\\ Nibble (4-bit) op tables: index = A*16+B, values 0..15. Eight nibbles/word.
(define shen.x.nibble-and-table
  -> [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 0 2 2 0 0 2 2 0 0 2 2 0 0 2 2 0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3 0 0 0 0 4 4 4 4 0 0 0 0 4 4 4 4 0 1 0 1 4 5 4 5 0 1 0 1 4 5 4 5 0 0 2 2 4 4 6 6 0 0 2 2 4 4 6 6 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 0 0 0 0 0 0 0 8 8 8 8 8 8 8 8 0 1 0 1 0 1 0 1 8 9 8 9 8 9 8 9 0 0 2 2 0 0 2 2 8 8 10 10 8 8 10 10 0 1 2 3 0 1 2 3 8 9 10 11 8 9 10 11 0 0 0 0 4 4 4 4 8 8 8 8 12 12 12 12 0 1 0 1 4 5 4 5 8 9 8 9 12 13 12 13 0 0 2 2 4 4 6 6 8 8 10 10 12 12 14 14 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15])

(define shen.x.nibble-or-table
  -> [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 1 1 3 3 5 5 7 7 9 9 11 11 13 13 15 15 2 3 2 3 6 7 6 7 10 11 10 11 14 15 14 15 3 3 3 3 7 7 7 7 11 11 11 11 15 15 15 15 4 5 6 7 4 5 6 7 12 13 14 15 12 13 14 15 5 5 7 7 5 5 7 7 13 13 15 15 13 13 15 15 6 7 6 7 6 7 6 7 14 15 14 15 14 15 14 15 7 7 7 7 7 7 7 7 15 15 15 15 15 15 15 15 8 9 10 11 12 13 14 15 8 9 10 11 12 13 14 15 9 9 11 11 13 13 15 15 9 9 11 11 13 13 15 15 10 11 10 11 14 15 14 15 10 11 10 11 14 15 14 15 11 11 11 11 15 15 15 15 11 11 11 11 15 15 15 15 12 13 14 15 12 13 14 15 12 13 14 15 12 13 14 15 13 13 15 15 13 13 15 15 13 13 15 15 13 13 15 15 14 15 14 15 14 15 14 15 14 15 14 15 14 15 14 15 15 15 15 15 15 15 15 15 15 15 15 15 15 15 15 15])

(define shen.x.nibble-xor-table
  -> [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 1 0 3 2 5 4 7 6 9 8 11 10 13 12 15 14 2 3 0 1 6 7 4 5 10 11 8 9 14 15 12 13 3 2 1 0 7 6 5 4 11 10 9 8 15 14 13 12 4 5 6 7 0 1 2 3 12 13 14 15 8 9 10 11 5 4 7 6 1 0 3 2 13 12 15 14 9 8 11 10 6 7 4 5 2 3 0 1 14 15 12 13 10 11 8 9 7 6 5 4 3 2 1 0 15 14 13 12 11 10 9 8 8 9 10 11 12 13 14 15 0 1 2 3 4 5 6 7 9 8 11 10 13 12 15 14 1 0 3 2 5 4 7 6 10 11 8 9 14 15 12 13 2 3 0 1 6 7 4 5 11 10 9 8 15 14 13 12 3 2 1 0 7 6 5 4 12 13 14 15 8 9 10 11 4 5 6 7 0 1 2 3 13 12 15 14 9 8 11 10 5 4 7 6 1 0 3 2 14 15 12 13 10 11 8 9 6 7 4 5 2 3 0 1 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0])

(define shen.x.nibble-op
  Tab A B -> (shen.x.list.nth (+ (* A 16) B) Tab))

(define shen.x.u32.lop
  Tab A B Shift Acc I ->
    (if (> I 7)
        Acc
        (let Na (shen.x.rem (shen.x.quot A (shen.x.pow2 (* I 4))) 16)
             Nb (shen.x.rem (shen.x.quot B (shen.x.pow2 (* I 4))) 16)
             V (shen.x.nibble-op Tab Na Nb)
             NAcc (+ Acc (* V (shen.x.pow2 (* I 4))))
          (shen.x.u32.lop Tab A B Shift NAcc (+ I 1)))))

(define shen.x.u32.and
  A B -> (shen.x.u32.lop (shen.x.nibble-and-table)
           (shen.x.u32.mod A) (shen.x.u32.mod B) 0 0 0))

(define shen.x.u32.or
  A B -> (shen.x.u32.lop (shen.x.nibble-or-table)
           (shen.x.u32.mod A) (shen.x.u32.mod B) 0 0 0))

(define shen.x.u32.xor
  A B -> (shen.x.u32.lop (shen.x.nibble-xor-table)
           (shen.x.u32.mod A) (shen.x.u32.mod B) 0 0 0))

(define shen.x.u32.not
  A -> (shen.x.u32.xor (shen.x.u32.mod A) 4294967295))

(define shen.x.u32.shr
  A N -> (if (<= N 0)
             (shen.x.u32.mod A)
             (shen.x.quot (shen.x.u32.mod A) (shen.x.pow2 N))))

(define shen.x.u32.shl
  A N -> (if (<= N 0)
             (shen.x.u32.mod A)
             (shen.x.u32.mod (* (shen.x.u32.mod A) (shen.x.pow2 N)))))

(define shen.x.u32.rotr
  A N -> (let N (shen.x.rem N 32)
           (shen.x.u32.or
             (shen.x.u32.shr A N)
             (shen.x.u32.shl A (- 32 N)))))

\\ ---- list helpers ----

(define shen.x.list.nth
  N L -> (if (and (cons? L) (= N 0))
             (hd L)
             (if (and (cons? L) (> N 0))
                 (shen.x.list.nth (- N 1) (tl L))
                 (simple-error "shen.x.list.nth"))))

(define shen.x.list.length
  [] -> 0
  [_ | Xs] -> (+ 1 (shen.x.list.length Xs)))

(define shen.x.list.take
  0 _ -> []
  N [X | Xs] -> [X | (shen.x.list.take (- N 1) Xs)]
  _ _ -> (simple-error "shen.x.list.take"))

(define shen.x.list.drop
  0 Xs -> Xs
  N [_ | Xs] -> (shen.x.list.drop (- N 1) Xs)
  _ _ -> (simple-error "shen.x.list.drop"))

(define shen.x.list.append
  [] Ys -> Ys
  [X | Xs] Ys -> [X | (shen.x.list.append Xs Ys)])

(define shen.x.list.repeat
  0 _ -> []
  N X -> [X | (shen.x.list.repeat (- N 1) X)])

(define shen.x.list.reverse
  Xs -> (shen.x.list.reverse-h Xs []))

(define shen.x.list.reverse-h
  [] Acc -> Acc
  [X | Xs] Acc -> (shen.x.list.reverse-h Xs [X | Acc]))

\\ ---- validate octets ----

(define shen.x.octets-ok?
  [] -> true
  [B | Bs] -> (if (and (number? B) (and (>= B 0) (<= B 255)))
                  (shen.x.octets-ok? Bs)
                  false)
  _ -> false)

\\ ---- bytes <-> words (big-endian) ----

(define shen.x.bytes->words
  [] -> []
  [A B C D | Rest] ->
    [(shen.x.u32.add4
       (shen.x.u32.shl A 24)
       (shen.x.u32.shl B 16)
       (shen.x.u32.shl C 8)
       D)
     | (shen.x.bytes->words Rest)]
  _ -> (simple-error "shen.x.bytes->words: length not multiple of 4"))

(define shen.x.word->bytes
  W -> [(shen.x.u32.shr W 24)
        (shen.x.rem (shen.x.u32.shr W 16) 256)
        (shen.x.rem (shen.x.u32.shr W 8) 256)
        (shen.x.rem W 256)])

(define shen.x.words->bytes
  [] -> []
  [W | Ws] -> (shen.x.list.append (shen.x.word->bytes W) (shen.x.words->bytes Ws)))

\\ 64-bit big-endian bit-length as 8 bytes (message length fits u32 bytes for suite)
(define shen.x.bitlen-bytes
  ByteLen ->
    (let Bits (* ByteLen 8)
      (shen.x.list.append
        [0 0 0 0]
        (shen.x.word->bytes (shen.x.u32.mod Bits)))))

\\ ---- padding ----

(define shen.x.sha256-pad
  Bs ->
    (let L (shen.x.list.length Bs)
         Mod (shen.x.rem (+ L 1) 64)
         Z (if (<= Mod 56)
               (- 56 Mod)
               (- 120 Mod))
      (shen.x.list.append
        Bs
        (shen.x.list.append
          [128]
          (shen.x.list.append
            (shen.x.list.repeat Z 0)
            (shen.x.bitlen-bytes L))))))

\\ ---- schedule + compress ----

(define shen.x.sha256-IV
  -> [1779033703 3144134277 1013904242 2773480762
      1359893119 2600822924 528734635 1541459225])

\\ K constants as decimal u32
(define shen.x.sha256-K
  -> [1116352408 1899447441 3049323471 3921009573
      961987163 1508970993 2453635748 2870763221
      3624381080 310598401 607225278 1426881987
      1925078388 2162078206 2614888103 3248222580
      3835390401 4022224774 264347078 604807628
      770255983 1249150122 1555081692 1996064986
      2554220882 2821834349 2952996808 3210313671
      3336571891 3584528711 113926993 338241895
      666307205 773529912 1294757372 1396182291
      1695183700 1986661051 2177026350 2456956037
      2730485921 2820302411 3259730800 3345764771
      3516065817 3600352804 4094571909 275423344
      430227734 506948616 659060556 883997877
      958139571 1322822218 1537002063 1747873779
      1955562222 2024104815 2227730452 2361852424
      2428436474 2756734187 3204031479 3329325298])

(define shen.x.ch
  X Y Z -> (shen.x.u32.xor
             (shen.x.u32.and X Y)
             (shen.x.u32.and (shen.x.u32.not X) Z)))

(define shen.x.maj
  X Y Z -> (shen.x.u32.xor
             (shen.x.u32.and X Y)
             (shen.x.u32.xor
               (shen.x.u32.and X Z)
               (shen.x.u32.and Y Z))))

(define shen.x.big-sigma0
  X -> (shen.x.u32.xor
         (shen.x.u32.rotr X 2)
         (shen.x.u32.xor (shen.x.u32.rotr X 13) (shen.x.u32.rotr X 22))))

(define shen.x.big-sigma1
  X -> (shen.x.u32.xor
         (shen.x.u32.rotr X 6)
         (shen.x.u32.xor (shen.x.u32.rotr X 11) (shen.x.u32.rotr X 25))))

(define shen.x.small-sigma0
  X -> (shen.x.u32.xor
         (shen.x.u32.rotr X 7)
         (shen.x.u32.xor (shen.x.u32.rotr X 18) (shen.x.u32.shr X 3))))

(define shen.x.small-sigma1
  X -> (shen.x.u32.xor
         (shen.x.u32.rotr X 17)
         (shen.x.u32.xor (shen.x.u32.rotr X 19) (shen.x.u32.shr X 10))))

(define shen.x.schedule
  Ws 64 -> Ws
  Ws I ->
    (let W15 (shen.x.list.nth (- I 15) Ws)
         W2  (shen.x.list.nth (- I 2) Ws)
         W16 (shen.x.list.nth (- I 16) Ws)
         W7  (shen.x.list.nth (- I 7) Ws)
         Next (shen.x.u32.add4
                (shen.x.small-sigma1 W2)
                W7
                (shen.x.small-sigma0 W15)
                W16)
      (shen.x.schedule (shen.x.list.append Ws [Next]) (+ I 1))))

(define shen.x.sha256-round
  St K W ->
    (let A (shen.x.list.nth 0 St)
         B (shen.x.list.nth 1 St)
         C (shen.x.list.nth 2 St)
         D (shen.x.list.nth 3 St)
         E (shen.x.list.nth 4 St)
         F (shen.x.list.nth 5 St)
         G (shen.x.list.nth 6 St)
         H (shen.x.list.nth 7 St)
         T1 (shen.x.u32.add5 H (shen.x.big-sigma1 E) (shen.x.ch E F G) K W)
         T2 (shen.x.u32.add (shen.x.big-sigma0 A) (shen.x.maj A B C))
      [(shen.x.u32.add T1 T2)
       A B C
       (shen.x.u32.add D T1)
       E F G]))

(define shen.x.sha256-rounds
  St _ _ 64 -> St
  St Ks Ws I ->
    (shen.x.sha256-rounds
      (shen.x.sha256-round
        St
        (shen.x.list.nth I Ks)
        (shen.x.list.nth I Ws))
      Ks Ws (+ I 1)))

(define shen.x.add-states
  [] [] -> []
  [A | As] [B | Bs] -> [(shen.x.u32.add A B) | (shen.x.add-states As Bs)])

(define shen.x.compress
  State BlockBytes ->
    (let W0 (shen.x.bytes->words BlockBytes)
         Ws (shen.x.schedule W0 16)
         Work (shen.x.sha256-rounds State (shen.x.sha256-K) Ws 0)
      (shen.x.add-states State Work)))

(define shen.x.compress-all
  State [] -> State
  State Bs ->
    (shen.x.compress-all
      (shen.x.compress State (shen.x.list.take 64 Bs))
      (shen.x.list.drop 64 Bs)))

\\ ---- public pure digest ----

(define shen.x.sha256-octets-pure
  Bs ->
    (if (shen.x.octets-ok? Bs)
        (shen.x.words->bytes
          (shen.x.compress-all
            (shen.x.sha256-IV)
            (shen.x.sha256-pad Bs)))
        (simple-error "shen.x.sha256-octets: expected list of bytes 0..255")))

\\ ---- hex ----

