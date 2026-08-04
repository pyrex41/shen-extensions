;;; Host SHA-256 for shen-cl via OpenSSL libcrypto (SBCL alien).
;;; Loaded optionally from shen/x/sha256.shen when shen-cl is the host.
;;; Defines |shen.x.sha256-octets-host| in the :shen package.

(in-package :shen)

#+sbcl
(eval-when (:compile-toplevel :load-toplevel :execute)
  (handler-case
      (progn
        ;; Prefer Homebrew OpenSSL on macOS; fall back to system names.
        (dolist (path '(
                        "/opt/homebrew/opt/openssl@3/lib/libcrypto.dylib"
                        "/usr/local/opt/openssl@3/lib/libcrypto.dylib"
                        "libcrypto.dylib"
                        "libcrypto.so.3"
                        "libcrypto.so"))
          (handler-case
              (progn
                (sb-alien:load-shared-object path :dont-save t)
                (return))
            (error ())))
        (sb-alien:define-alien-routine ("SHA256" %openssl-sha256)
            (* (unsigned 8))
          (data (* (unsigned 8)))
          (n sb-alien:size-t)
          (md (* (unsigned 8))))

        (defun |shen.x.sha256-octets-host| (bs)
          "Bs is a Shen list of integers 0..255; return 32-byte list."
          (let* ((len 0)
                 (cur bs))
            ;; count
            (loop while (consp cur) do
              (incf len)
              (setf cur (cdr cur)))
            (unless (null cur)
              (error "shen.x.sha256-octets-host: expected list of bytes 0..255"))
            (sb-alien:with-alien ((buf (array (unsigned 8) 65536))
                                  (md (array (unsigned 8) 32)))
              (when (> len 65536)
                (error "shen.x.sha256-octets-host: input too long for static buffer"))
              (let ((i 0)
                    (c bs))
                (loop while (consp c) do
                  (let ((b (car c)))
                    (unless (and (integerp b) (<= 0 b 255))
                      (error "shen.x.sha256-octets-host: expected list of bytes 0..255"))
                    (setf (sb-alien:deref buf i) b)
                    (incf i)
                    (setf c (cdr c))))
                (%openssl-sha256
                 (sb-alien:addr (sb-alien:deref buf 0))
                 len
                 (sb-alien:addr (sb-alien:deref md 0)))
                (let ((acc '()))
                  (loop for j from 31 downto 0 do
                    (push (sb-alien:deref md j) acc))
                  acc)))))

        (|put| '|shen.x.sha256-octets-host| '|arity| 1 |*property-vector*|)
        (|set| '|shen.x.*sha256-backend*| '|host|))
    (error (e)
      (format *error-output* "shen-cl host sha256 unavailable: ~A~%" e))))
