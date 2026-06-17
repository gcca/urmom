(ql:quickload "unix-opts" :silent t)

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
        :arg-parser #'identity)

 (:name :is-active
        :description "Whether the user is active"
        :short #\a
        :long "is_active"
        :type 'boolean
        :default t))

(defun print-help ()
  (opts:describe :prefix "Create a new urmom user."
                 :usage-of "urmom-user_create.lisp"))

(defun main ()
  (when (intersection '("-h" "--help") (opts:argv) :test #'string=)
    (print-help) (opts:exit 0))

  (multiple-value-bind (options _)
                       (handler-case (opts:get-opts)
                         (error (message)
                                (format t "Error: ~a~%" message)
                                (print-help)
                                (opts:exit 1)))

                       (format t
                               "Creating user with the following options:~@
                                Username: ~a~%Password: ~a~%Email: ~a~%Is Active: ~a~%"
                               (getf options :username)
                               (getf options :password)
                               (getf options :email)
                               (getf options :is-active))))
