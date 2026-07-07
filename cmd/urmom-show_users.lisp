(ql:quickload :sqlite :silent t)

(defun main ()
  (sqlite:with-open-database (conn "data/urmom.db")
    (let ((rows (sqlite:execute-to-list
                 conn
                 "SELECT
                    u.username,
                    u.email,
                    u.is_active,
                    u.created_at,
                    GROUP_CONCAT(d.appname, ', ') AS apps
                  FROM auth_user u
                  LEFT JOIN dash_binding d ON d.username = u.username
                  GROUP BY u.username, u.email, u.is_active, u.created_at
                  LIMIT 171")))

      (dolist (row rows)
        (destructuring-bind (username email is-active created-at apps) row
          (format t "~11a ~a~%" "username:" username)
          (format t "~11a ~a~%" "email:" email)
          (format t "~11a ~a~%" "is_active:" is-active)
          (format t "~11a ~a~%" "created_at:" created-at)
          (format t "~11a ~a~%" "apps:" (or apps "—"))
          (format t "~%"))))))
