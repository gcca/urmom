#!/usr/bin/env sbcl --script

(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))

(defun usage ()
  (format t "Usage: ./run.lisp <cmd.lisp> [args...]~%")
  (sb-ext:quit :unix-status 1))

(unless (>= (length sb-ext:*posix-argv*) 2)
  (usage))

(let* ((script-name (nth 1 sb-ext:*posix-argv*))
       (args (nthcdr 2 sb-ext:*posix-argv*)))

  (unless (probe-file script-name)
    (format t "Error: No se encuentra el archivo ~a~%" script-name)
    (sb-ext:quit :unix-status 1))

  (load script-name)

  (let ((sb-ext:*posix-argv* (cons script-name args)))
    (main)))
