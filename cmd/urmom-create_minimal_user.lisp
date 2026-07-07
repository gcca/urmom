(ql:quickload :unix-opts :silent t)
(ql:quickload :sqlite :silent t)

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

 (:name :email
        :description "Email address for the new user"
        :short #\e
        :long "email"
        :arg-parser #'identity))

(defun print-help ()
  (opts:describe :prefix "Create a new urmom minimal user."
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
                               "Creating user with the following options:~%Username: ~a~%Email: ~a~%"
                               (getf options :username)
                               (getf options :email))))
