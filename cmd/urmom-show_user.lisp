(ql:quickload :sqlite :silent t)

(require :uiop)

(defun usage ()
  (format t "Usage: urmom-show_user <username>~%"))

(defun main ()
  (let ((args (uiop:command-line-arguments)))

    (when (not (= (length args) 1))
      (usage)
      (uiop:quit 1))

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
                   WHERE username = ?" (first args))))

        (destructuring-bind (username email is-active created_at) (first item)
          (format t "~11a ~a~%" "username:" username)
          (format t "~11a ~a~%" "email:" email)
          (format t "~11a ~a~%" "is-active:" is-active)
          (format t "~11a ~a~%" "created_at:" created_at))))))
