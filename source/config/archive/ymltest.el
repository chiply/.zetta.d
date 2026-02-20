(defun read-file (file)
 (when (file-exists-p file)
   (with-temp-buffer
     (insert-file-contents file)
     (buffer-string))))


(yaml-parse-string
 (read-file "./foreman_conf.yml")
 )




