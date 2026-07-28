\\ shen.x.sha256-pure — pure Shen oracle (loaded only when host is absent)
\\ Do not load this file directly when a host backend is available; use shen/x/sha256.shen.
\\
\\ Representation (urdr.prng technique, ADR-approved same-owner code):
\\   a u32 word is a 4-element big-endian byte list [B0 B1 B2 B3];
\\   logical ops decompose bytes to bit lists via a weights walk and zip
\\   32 per-bit integer comparisons; rotr/shr are list rotations/shifts;
\\   addition is a reversed byte walk with carry. No host division, no
\\   lookup tables rebuilt per call, no O(n) nth in the hot path.

\\ ---- list helpers ----

(define shen.x.list.nth
  N L -> (if (and (cons? L) (= N 0))
             (hd L)
             (if (and (cons? L) (> N 0))
                 (shen.x.list.nth (- N 1) (tl L))
                 (simple-error "shen.x.list.nth"))))

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

\\ ---- small pure division (padding/constants only; never in the round path) ----

(define shen.x.quot-slow
  N M -> (if (< N M)
             0
             (let Q (shen.x.quot-slow N (* M 2))
                  R (- N (* Q (* M 2)))
               (if (< R M)
                   (* Q 2)
                   (+ (* Q 2) 1)))))

\\ Big-endian fixed-width byte decomposition of a nonnegative integer.
(define shen.x.fixed-be
  N 0 Out -> Out
  N C Out -> (let Q (shen.x.quot-slow N 256)
               (shen.x.fixed-be Q (- C 1) [(- N (* Q 256)) | Out])))

\\ ---- bit ops ----

(define shen.x.bit.not
  0 -> 1
  1 -> 0)

(define shen.x.bit.and
  1 1 -> 1
  _ _ -> 0)

(define shen.x.bit.xor
  A B -> (if (= A B) 0 1))

\\ byte (0..255) -> 8-element bit list, msb first, via weights walk
(define shen.x.byte.bits-w
  _ [] -> []
  N [W | Ws] ->
    (if (>= N W)
        [1 | (shen.x.byte.bits-w (- N W) Ws)]
        [0 | (shen.x.byte.bits-w N Ws)]))

(define shen.x.byte.bits
  N -> (shen.x.byte.bits-w N [128 64 32 16 8 4 2 1]))

(define shen.x.byte.from-bits-h
  [] N -> N
  [B | Bs] N -> (shen.x.byte.from-bits-h Bs (+ (* N 2) B)))

(define shen.x.byte.from-bits
  Bs -> (shen.x.byte.from-bits-h Bs 0))

\\ ---- u32 words as 4-byte big-endian lists ----

(define shen.x.word.bits
  [A B C D] ->
    (shen.x.list.append (shen.x.byte.bits A)
      (shen.x.list.append (shen.x.byte.bits B)
        (shen.x.list.append (shen.x.byte.bits C)
                            (shen.x.byte.bits D)))))

(define shen.x.bits.word
  Bs -> [(shen.x.byte.from-bits
           (shen.x.list.take 8 Bs))
         (shen.x.byte.from-bits
           (shen.x.list.take 8 (shen.x.list.drop 8 Bs)))
         (shen.x.byte.from-bits
           (shen.x.list.take 8 (shen.x.list.drop 16 Bs)))
         (shen.x.byte.from-bits
           (shen.x.list.take 8 (shen.x.list.drop 24 Bs)))])

(define shen.x.bits.not
  [] -> []
  [A | As] -> [(shen.x.bit.not A) | (shen.x.bits.not As)])

(define shen.x.bits.and
  [] [] -> []
  [A | As] [B | Bs] ->
    [(shen.x.bit.and A B) | (shen.x.bits.and As Bs)])

(define shen.x.bits.xor
  [] [] -> []
  [A | As] [B | Bs] ->
    [(shen.x.bit.xor A B) | (shen.x.bits.xor As Bs)])

(define shen.x.word.not
  W -> (shen.x.bits.word
         (shen.x.bits.not (shen.x.word.bits W))))

(define shen.x.word.and
  A B -> (shen.x.bits.word
           (shen.x.bits.and
             (shen.x.word.bits A)
             (shen.x.word.bits B))))

(define shen.x.word.xor
  A B -> (shen.x.bits.word
           (shen.x.bits.xor
             (shen.x.word.bits A)
             (shen.x.word.bits B))))

(define shen.x.word.xor3
  A B C -> (shen.x.word.xor (shen.x.word.xor A B) C))

(define shen.x.word.rotr
  W N -> (let Bs (shen.x.word.bits W)
           (shen.x.bits.word
             (shen.x.list.append
               (shen.x.list.drop (- 32 N) Bs)
               (shen.x.list.take (- 32 N) Bs)))))

(define shen.x.word.shr
  W N -> (shen.x.bits.word
           (shen.x.list.append
             (shen.x.list.repeat N 0)
             (shen.x.list.take
               (- 32 N) (shen.x.word.bits W)))))

\\ mod-2^32 addition: reversed byte walk with carry (final carry dropped)
(define shen.x.word.add-rev
  [] [] _ Out -> Out
  [A | As] [B | Bs] Carry Out ->
    (let S (+ (+ A B) Carry)
      (if (>= S 256)
          (shen.x.word.add-rev As Bs 1 [(- S 256) | Out])
          (shen.x.word.add-rev As Bs 0 [S | Out]))))

(define shen.x.word.add2
  A B -> (shen.x.word.add-rev
           (shen.x.list.reverse A) (shen.x.list.reverse B) 0 []))

(define shen.x.word.add-all
  [W] -> W
  [W | Ws] -> (shen.x.word.add2 W (shen.x.word.add-all Ws)))

\\ decimal u32 -> word (constants only, once per session via memoized tables)
(define shen.x.u32->word
  N -> (shen.x.fixed-be N 4 []))

(define shen.x.u32s->words
  [] -> []
  [N | Ns] -> [(shen.x.u32->word N) | (shen.x.u32s->words Ns)])

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
  [A B C D | Rest] -> [[A B C D] | (shen.x.bytes->words Rest)]
  _ -> (simple-error "shen.x.bytes->words: length not multiple of 4"))

(define shen.x.words->bytes
  [] -> []
  [W | Ws] -> (shen.x.list.append W (shen.x.words->bytes Ws)))

\\ ---- padding ----

\\ one walk: [ByteLength LengthMod64]
(define shen.x.msg-info
  [] N Mod -> [N Mod]
  [_ | Bs] N Mod ->
    (shen.x.msg-info Bs (+ N 1) (if (= Mod 63) 0 (+ Mod 1))))

\\ 64-bit big-endian bit-length as 8 bytes
(define shen.x.bitlen-bytes
  ByteLen -> (shen.x.fixed-be (* ByteLen 8) 8 []))

(define shen.x.sha256-pad
  Bs ->
    (let Info (shen.x.msg-info Bs 0 0)
         L (hd Info)
         Mod (hd (tl Info))
         Mod1 (if (= Mod 63) 0 (+ Mod 1))
         Z (if (<= Mod1 56)
               (- 56 Mod1)
               (- 120 Mod1))
      (shen.x.list.append
        Bs
        (shen.x.list.append
          [128]
          (shen.x.list.append
            (shen.x.list.repeat Z 0)
            (shen.x.bitlen-bytes L))))))

\\ ---- constants ----
\\ Decimal u32 literals kept inside 0-arity defuns so (load) does not echo
\\ giant lists (Bifrost). Word forms are memoized via (set)/(value) globals
\\ guarded by trap-error, mirroring the shen.x.ensure-pure pattern, so the
\\ conversion runs once per session — never per call.

(define shen.x.sha256-IV
  -> [1779033703 3144134277 1013904242 2773480762
      1359893119 2600822924 528734635 1541459225])

(define shen.x.sha256-IV-words
  -> (trap-error
       (value shen.x.*sha256-IV-words*)
       (/. E (set shen.x.*sha256-IV-words*
               (shen.x.u32s->words (shen.x.sha256-IV))))))

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

(define shen.x.sha256-K-words
  -> (trap-error
       (value shen.x.*sha256-K-words*)
       (/. E (set shen.x.*sha256-K-words*
               (shen.x.u32s->words (shen.x.sha256-K))))))

\\ ---- schedule + compress ----

(define shen.x.ch
  X Y Z -> (shen.x.word.xor
             (shen.x.word.and X Y)
             (shen.x.word.and (shen.x.word.not X) Z)))

(define shen.x.maj
  X Y Z -> (shen.x.word.xor3
             (shen.x.word.and X Y)
             (shen.x.word.and X Z)
             (shen.x.word.and Y Z)))

(define shen.x.big-sigma0
  X -> (shen.x.word.xor3
         (shen.x.word.rotr X 2)
         (shen.x.word.rotr X 13)
         (shen.x.word.rotr X 22)))

(define shen.x.big-sigma1
  X -> (shen.x.word.xor3
         (shen.x.word.rotr X 6)
         (shen.x.word.rotr X 11)
         (shen.x.word.rotr X 25)))

(define shen.x.small-sigma0
  X -> (shen.x.word.xor3
         (shen.x.word.rotr X 7)
         (shen.x.word.rotr X 18)
         (shen.x.word.shr X 3)))

(define shen.x.small-sigma1
  X -> (shen.x.word.xor3
         (shen.x.word.rotr X 17)
         (shen.x.word.rotr X 19)
         (shen.x.word.shr X 10)))

(define shen.x.schedule
  Ws 64 -> Ws
  Ws I ->
    (let W15 (shen.x.list.nth (- I 15) Ws)
         W2  (shen.x.list.nth (- I 2) Ws)
         W16 (shen.x.list.nth (- I 16) Ws)
         W7  (shen.x.list.nth (- I 7) Ws)
         Next (shen.x.word.add-all
                [(shen.x.small-sigma1 W2)
                 W7
                 (shen.x.small-sigma0 W15)
                 W16])
      (shen.x.schedule (shen.x.list.append Ws [Next]) (+ I 1))))

(define shen.x.sha256-round
  [A B C D E F G H] K W ->
    (let T1 (shen.x.word.add-all
              [H (shen.x.big-sigma1 E) (shen.x.ch E F G) K W])
         T2 (shen.x.word.add2
              (shen.x.big-sigma0 A)
              (shen.x.maj A B C))
      [(shen.x.word.add2 T1 T2)
       A B C
       (shen.x.word.add2 D T1)
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
  [A | As] [B | Bs] -> [(shen.x.word.add2 A B) | (shen.x.add-states As Bs)])

(define shen.x.compress
  State BlockBytes ->
    (let W0 (shen.x.bytes->words BlockBytes)
         Ws (shen.x.schedule W0 16)
         Work (shen.x.sha256-rounds State (shen.x.sha256-K-words) Ws 0)
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
            (shen.x.sha256-IV-words)
            (shen.x.sha256-pad Bs)))
        (simple-error "shen.x.sha256-octets: expected list of bytes 0..255")))
