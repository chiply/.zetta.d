;;; all-the-icons.el --- Configure all-the-icons -*- lexical-binding: t; -*-

;; all-the-icons uses (setf (image-property ...)) without requiring
;; 'image.  An Emacs whose build doesn't preload image.el (headless CI
;; runners byte-compiling the prebuilt store) compiles that into a call
;; to the named setter function (setf image-property), which no
;; released Emacs defines -- every icon render then fails with
;; void-function, prebuilt stores shipped that bytecode to every
;; platform (measured 2026-07-25: 30.2- and 31.0.90-built stores
;; alike), and the vertico UI surfaced it as "Vertico detected an
;; error".  Define the setter so such bytecode works no matter which
;; Emacs compiled it.  Harmless when unneeded; skipped if some future
;; Emacs defines it natively.
(unless (fboundp (intern "(setf image-property)"))
  (defalias (intern "(setf image-property)")
    (lambda (value image property)
      (require 'image)
      (image--set-property image property value))
    "Named setter for `image-property', for bytecode compiled without image.el."))

(use-package all-the-icons
  :ensure (all-the-icons
           :host github
           :repo "domtronn/all-the-icons.el"
           :branch "svg"
           :files (:defaults "svg"))
  :if (display-graphic-p)
  :config
  ;;(use-package octicons)
  (setq all-the-icons-color-icons t)

  ;; fixing themes
  ;; TODO mayybe more efficient way to just add a face to this
  ;; Somehow this gets around the size problem
  (setq all-the-icons-mode-icon-alist
        (-remove
         (lambda (x)
           (or (eq (car x) 'vterm-mode)
               (eq (car x) 'copilot-mode)
               (eq (car x) 'lsp-mode)
               (eq (car x) 'evil-state)
               (eq (car x) 'meow-state)
               (eq (car x) 'emacs-state)
               (eq (car x) 'insert-state)
               (eq (car x) 'non-insert-state)))
         all-the-icons-mode-icon-alist))
  (add-to-list 'all-the-icons-mode-icon-alist '(nov-mode octicons "book"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(md4rd-mode fontawesome-4 "reddit-alien"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(wombag-search-mode material-icons "article"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(wombag-show-mode material-icons "article"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(vterm-mode octicons "terminal"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(copilot-mode octicons "copilot"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(lsp-mode fileicon "vscode"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(evil-state devopicons "vim"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(meow-state fluentui-system-icons "animal_cat"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(emacs-state fileicon "emacs"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(insert-state fluentui-system-icons "pen"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))
  (add-to-list 'all-the-icons-mode-icon-alist '(non-insert-state fluentui-system-icons "pen_off"
                                                         ;;:face all-the-icons-dired-dir-face
                                                         ))

  )
;;; all-the-icons.el ends here
