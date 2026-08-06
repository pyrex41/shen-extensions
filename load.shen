\\ One-shot loader for all shen.x extensions.
\\
\\ From this repo root (or with *home-directory* pointed here):
\\   (load "load.shen")
\\
\\ Then use the API with no further port-specific setup:
\\   (shen.x.sha256-hex (shen.x.string->octets "abc"))
\\
\\ If the port installed shen.x.sha256-octets-host, you get native speed;
\\ otherwise pure Shen runs (slower, same digests).

(load "shen/x/sha256.shen")
(load "shen/x/zmq.shen")
