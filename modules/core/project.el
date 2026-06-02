;;; project.el --- Configure project -*- lexical-binding: t; -*-

(use-package project
  :ensure nil ;; builtin
  :after consult
  :demand t
  :config

  ;; Fallback for directories not recognized by project-find-functions.
  ;; Must use with-eval-after-load since nested use-package :config
  ;; may not reliably run with elpaca.
  (with-eval-after-load 'consult-project-extra
    (defun consult-project-extra--project-with-root (root)
      "Return the project for a given project ROOT."
      (or (project--find-in-directory root)
          (cons 'transient root))))

  (defun consult-project-switch-project ()
    (interactive)
    (let ((default-directory (consult--read
                              (project-known-project-roots)
                              :prompt "Project: "
                              :category 'project)))
      (if (fboundp 'magit)
          (call-interactively 'magit)
        (project-vc-dir))))

  (general-define-key
   :keymaps 'menu-project-map
   ;; TODO see if this works
   "w" 'menu-window-map
   "a" (** consult-ripgrep)
   "p" (** consult-project-switch-project)
   "d" (** project-find-dir)
   "f" (** consult-project-extra-find)
   "r" (** project-remember-project)
   )

  (general-define-key
   :keymaps 'menu-window-map
   "p" (** menu-project))
  )

;; TODO seems like this is under active development, just enabling,
;; but not using it yet
(use-package ede
  :ensure nil ;; builtin
  :demand t
  :config
  (global-ede-mode)
  ;; global-ede-mode replaces project-try-vc with project-try-ede in
  ;; project-find-functions, breaking git project detection. Add it back.
  (add-hook 'project-find-functions #'project-try-vc))
;;; project.el ends here
