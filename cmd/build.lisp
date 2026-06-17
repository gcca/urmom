#!/usr/bin/env sbcl --script

(defparameter *build-dir*
  (make-pathname :name nil :type nil
                  :defaults (merge-pathnames "../build/" *load-pathname*)))
(defparameter *excluded-files* (list (file-namestring *load-pathname*) "run.lisp"))

(defun buildable-files ()
  (remove-if (lambda (path) (member (file-namestring path) *excluded-files* :test #'string=))
             (directory (merge-pathnames "*.lisp" *load-pathname*))))

(defun build-one (source-file)
  (let ((output-file (make-pathname :name (pathname-name source-file)
                                     :type nil
                                     :defaults *build-dir*)))

    (load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))

    (with-open-file (stream source-file)
      (loop for form = (read stream nil :eof)
            until (eq form :eof)
            unless (equal form '(main))
              do (eval form)))

    (ensure-directories-exist output-file)

    (sb-ext:save-lisp-and-die output-file
                               :executable t
                               :toplevel #'main
                               :save-runtime-options t)))

(defun build-all ()
  (let ((files (buildable-files))
        (failures nil))

    (when (null files)
      (format t "No hay comandos para compilar en ~a~%" (directory-namestring *load-pathname*))
      (sb-ext:quit :unix-status 0))

    (dolist (source-file files)
      (format t "Building ~a...~%" (file-namestring source-file))
      (let ((process (sb-ext:run-program (first sb-ext:*posix-argv*)
                                          (list "--script" (namestring *load-pathname*)
                                                (namestring source-file))
                                          :search t
                                          :output t
                                          :error t)))
        (unless (zerop (sb-ext:process-exit-code process))
          (push source-file failures))))

    (if failures
        (progn
          (format t "Failed to build: ~{~a~^, ~}~%" (mapcar #'file-namestring failures))
          (sb-ext:quit :unix-status 1))
        (format t "All binaries built in ~a~%" (directory-namestring (truename *build-dir*))))))

(let ((source-file (second sb-ext:*posix-argv*)))
  (if source-file
      (if (probe-file source-file)
          (build-one source-file)
          (progn
            (format t "Error: No se encuentra el archivo ~a~%" source-file)
            (sb-ext:quit :unix-status 1)))
      (build-all)))
