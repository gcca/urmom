(ql:quickload :unix-opts :silent t)
(ql:quickload :sqlite :silent t)

(opts:define-opts
    (:name :help
           :description "Print this help text"
           :short #\h
           :long "help")

    (:name :username
           :description "Username to show details"
           :short #\u
           :long "username"
           :arg-parser #'identity
           :required t))

(defun usage ()
  (opts:describe :prefix "Show username details."
                 :usage-of "urmom-show_user"))

(defun main ()
  (when (intersection '("-h" "--help") (opts:argv) :test #'string=) (usage) (opts:exit 0))

  (multiple-value-bind (options _)
      (handler-case (opts:get-opts)
        (error (message)
          (format t "Error: ~a~%" message)
          (usage)
          (opts:exit 1)))

    (sqlite:with-open-database
     (conn "data/urmom.db")
     (let ((item (sqlite:execute-to-list
                  conn
                  "SELECT
                     username,
                     email,
                     is_active,
                     created_at
                   FROM auth_user
                   WHERE username = ?" (getf options :username))))

       (destructuring-bind (username email is-active created_at) (first item)
         (format t "~11a ~a~%" "username:" username)
         (format t "~11a ~a~%" "email:" email)
         (format t "~11a ~a~%" "is-active:" is-active)
         (format t "~11a ~a~%" "created_at:" created_at))))))
