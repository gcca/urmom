(ql:quickload :unix-opts :silent t)
(ql:quickload :sqlite :silent t)
(ql:quickload :cffi :silent t)

(cffi:define-foreign-library libargon2
    (:darwin (:or "libargon2.dylib"
                  "/usr/local/lib/libargon2.dylib"
                  "/opt/homebrew/lib/libargon2.dylib"
                  "build/libargon2.dylib"))
  (:unix (:or "libargon2.so"
              "/usr/lib/libargon2.so"
              "/usr/local/lib/libargon2.so"
              "build/libargon2.so")))

(cffi:use-foreign-library libargon2)

(defconstant +argon2-ok+ 0)
(defconstant +argon2-d+ 0)

(cffi:defcfun ("argon2d_hash_encoded" %argon2d-hash-encoded) :int
  (t-cost :uint32)
  (m-cost :uint32)
  (parallelism :uint32)
  (pwd :pointer)
  (pwdlen :size)
  (salt :pointer)
  (saltlen :size)
  (hashlen :size)
  (encoded :pointer)
  (encodedlen :size))

(cffi:defcfun ("argon2_encodedlen" %argon2-encodedlen) :size
  (t-cost :uint32)
  (m-cost :uint32)
  (parallelism :uint32)
  (saltlen :uint32)
  (hashlen :uint32)
  (type :int))

(cffi:defcfun ("argon2_error_message" %argon2-error-message) :string
  (error-code :int))

(opts:define-opts
    (:name :help
           :description "Print this help text"
           :short #\h
           :long "help")
    (:name :username
           :description "Username for the new user"
           :short #\u
           :long "username"
           :arg-parser #'identity
           :required t)
  (:name :password
         :description "Password for the new user"
         :short #\p
         :long "password"
         :arg-parser #'identity
         :required t)
  (:name :email
         :description "Email address for the new user"
         :short #\e
         :long "email"
         :arg-parser #'identity))

(defun usage ()
  (opts:describe :prefix "Create a new urmom user"
                 :usage-of "urmom-create_user"))

(defun fill-random-bytes (ptr len)
  (with-open-file (in "/dev/urandom" :element-type '(unsigned-byte 8))
    (dotimes (i len)
      (setf (cffi:mem-aref ptr :unsigned-char i) (read-byte in)))))

(defun prepare-password (options)
  (let* ((password (concatenate 'string (getf options :password) (getf options :username)))
         (t-cost 3)
         (m-cost 65536)
         (parallelism 1)
         (salt-len 16)
         (hash-len 32)
         (encoded-len (%argon2-encodedlen t-cost m-cost parallelism salt-len hash-len +argon2-d+)))
    (cffi:with-foreign-string ((pwd pwd-len) password)
      (cffi:with-foreign-pointer (salt salt-len)
        (fill-random-bytes salt salt-len)
        (cffi:with-foreign-pointer (encoded encoded-len)
          (let ((rc (%argon2d-hash-encoded
                     t-cost
                     m-cost
                     parallelism
                     pwd
                     (1- pwd-len)
                     salt
                     salt-len
                     hash-len
                     encoded
                     encoded-len)))
            (unless (= rc +argon2-ok+)
              (error "argon2d failed: ~a" (%argon2-error-message rc)))
            (cffi:foreign-string-to-lisp encoded)))))))

(defun main ()
  (when (intersection '("-h" "--help") (opts:argv) :test #'string=) (usage) (opts:exit 0))

  (multiple-value-bind (options _)
      (handler-case (opts:get-opts)
        (error (message)
          (format t "Error: ~a~%" message)
          (usage)
          (opts:exit 1)))

    (format t "Creating user with: ~%Username: ~a~%Email: ~a~%"
            (getf options :username)
            (getf options :password))

    (sqlite:with-open-database
        (db "data/urmom.db")
      (sqlite:execute-non-query db "INSERT INTO auth_user (username, password) VALUES (?, ?)"
                                (getf options :username) (prepare-password options)
                                )
      )
    )
  )
