(defun read-env-file (file)
  (with-temp-buffer
    (insert-file-contents file)
    (let ((env-vars (split-string (buffer-string) "\n" t)))
      ;;(mapcar (lambda (env-var)
                ;;(split-string env-var "=" t))
              ;;env-vars)
      (mapcar (lambda (env-var)
                (cons (car (split-string env-var "=" t))
                      (cadr (split-string env-var "=" t))))
              env-vars)
      

      )))

(read-env-file "~/source_code/centrellis-de-master-patient-index-service/.env")
