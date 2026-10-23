;;; project.el --- Configure project -*- lexical-binding: t; -*-

(use-package project
  :ensure nil ;; builtin
  :after consult
  :demand t
  :config

  ;; Non-VC project roots (e.g. ~/kb, whose .git lives only on the sync
  ;; hub): a .project marker file makes project-try-vc treat the dir as
  ;; a root, and the marker syncs to every device with the folder.
  (setq project-vc-extra-root-markers '(".project"))

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

;; `global-ede-mode' was enabled here "but not used yet" (its words).  It
;; put `ede-turn-on-hook' on `find-file-hook' -- a walk up the directory
;; tree looking for Project.ede, Makefile.am, CMakeLists.txt and the rest,
;; once per file opened and once per consult preview candidate -- and it
;; replaced `project-try-vc' in `project-find-functions', which this file
;; then had to add back.  Removed 2026-10-23 (OPTIMIZATIONS.org, round 2).
;;; project.el ends here
