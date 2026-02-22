;;; jmespath.el --- Configure JMESPath support -*- lexical-binding: t; -*-

(define-derived-mode jmespath-mode
  python-ts-mode "JMESPath"
  "Major mode for hypertext.")


(add-to-list 'auto-mode-alist '("\\.jp\\'" . jmespath-mode))


(defun jmespath-query ()
  (interactive)
  (let ((bufnm (format "*jmespath-query-%s*" (nth 0 (split-string (buffer-name) "\\.")))))
   (if (zetta-soda-buffer-displayed-p bufnm)
       (select-window (get-buffer-window bufnm))
     (progn
       (split-window-vertically 10)
       (switch-to-buffer bufnm)
       )
     )
   (erase-buffer)
   (progn
     (jmespath-mode)
     )
   )
  )
;;; jmespath.el ends here
