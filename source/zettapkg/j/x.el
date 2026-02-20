;;; x.el --- x -*- lexical-binding: t -*-


;; notes

;; step 1: get hello world template to render
;; step 2: define config and fill tamplate w 1 config value as default
;; step 3: define hydra to allow modification of the value
;; step 4:

(require use-package)


(use-package multi-compile
  :config
  (defun zetta-multi-compile ()
    default-directory
    )
  (setq multi-compile-default-directory-function 'zetta-multi-compile)

  )

(setq
 multi-compile-alist
 '(
   (python-ts-mode . (
                   ("goodbye" "echo bye" default-directory)
                   ))
   ))






(provide 'x)
;;; x.el ends here
