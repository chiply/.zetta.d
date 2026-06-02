;;; consult.el --- Configure consult -*- lexical-binding: t; -*-

;; NOTE tried implementing a function that lifts the preview keys to
;; temporarily get on the fly previews, but doesn't work as it doesn't
;; apply the completion

(use-package consult
  ;;:ensure (consult :type git :host github :repo "minad/consult" :tag "1.9")
  :after (savehist xref)
  :config

  (recentf-mode t)

  (setq recentf-max-saved-items 500)
  (setq recentf-max-menu-items 50)

  ;; NOTE without this, we don't have a completing read or vomec style
  ;; interface to finding references.  while xref,
  ;; consult-find-references, and consult-ui-peek-references provide
  ;; something like this.  Note this overrides the default of having
  ;; xrefs appear in a serpate buffer, but that's fine since we can
  ;; export references using embark.  in practice, I'll alternate
  ;; between using the consult approach most of the time and lsp-ui
  ;; find references for something more transient (although it doesn't
  ;; really provide additional features, the ui peak just looks cool)
  (setq xref-show-xrefs-function #'consult-xref)

  ;;(setq recentf-save-file (expand-file-name ".data/recentf/recentf" user-emacs-directory))
  (setq consult-preview-key 'any)
  (setq consult-project-root-function #'(project-root (project-current nil default-directory))
        ;; IMPORTANT!  otherwise completion-at-point doesn't use vertico!
        completion-in-region-function 'consult-completion-in-region)

  (setq
   consult-ripgrep-args
   "rg --hidden --glob \"!.git\" --null --line-buffered --color=never --max-columns=1000 --path-separator / --smart-case --no-heading --line-number")

  ;; NOTE because this uses this-command to figure out what to do, it
  ;; doesn't work when calling one of these from
  ;; project-switch-commands or project-prefix-map
  ;; Also doesn't seem to work when calling one consult via another
  (consult-customize
   consult-ripgrep
   consult-buffer
   consult-bookmark
   consult-project-buffer
   consult-theme
   :preview-key "C-=")

  (setq consult-async-split-style 'comma)
  ;; NOTE consult-omni--get-split-style-character fix moved to consult-omni.el
  ;; (must be defined after consult-omni loads or it gets overwritten)

  (defvar consult--yank-pop-history nil)
  (consult-customize consult-yank-pop :history 'consult--yank-pop-history)

  ;;;; WIKI
  ;; NOTE doesn't work
  ;;(defvar-local consult-toggle-preview-orig nil)

  ;;(defun consult-toggle-preview ()
  ;;"Command to enable/disable preview."
  ;;(interactive)
  ;;(if consult-toggle-preview-orig
  ;;(setq consult--preview-function consult-toggle-preview-orig
  ;;consult-toggle-preview-orig nil)
  ;;(setq consult-toggle-preview-orig consult--preview-function
  ;;consult--preview-function #'ignore)))

  ;;(define-key vertico-map (kbd "C-+") #'consult-toggle-preview)

  ;; project.el
  ;; TODO don't like how verbose and multi-step this is.
  (keymap-substitute project-prefix-map #'project-find-regexp #'consult-ripgrep)
  (cl-nsubstitute-if
   '(consult-ripgrep "Find regexp")
   (pcase-lambda (`(,cmd _)) (eq cmd #'project-find-regexp))
   project-switch-commands)

  ;; you press this, then a key to narrow to a section, but i prefer
  ;; to type the narrow key in and hit space as its easier
  (setq consult-narrow-key "<")

  (general-define-key
   :keymaps 'launch-map
   "b" 'consult-buffer
   "B" 'consult-buffer
   "f" 'consult-project-extra-find)

  (with-eval-after-load 'vertico
    (general-define-key :keymaps 'vertico-map "C-d" 'consult-dir))

  (general-define-key :keymaps 'minibuffer-local-map
    "C-r" 'consult-history)

  :general
  (
   :keymaps 'override
   "M-y" 'consult-yank-pop
   )
  (
   :keymaps 'menu-window-map
   "s" (** consult-ripgrep)
   "S" (** consult-line)
   )
  (
   :keymaps 'launch-map
   "v" 'consult-yank-from-kill-ring
   "s" 'consult-ripgrep
   "S" 'consult-line
   )
  )

(use-package consult-project-extra
  :after consult
  :config
  ;; TODO no sorting by recency in files?
  ;; suddenly started working though...
  (consult-customize
   consult-project-extra-find
   :preview-key "C-="))

(use-package consult-dir)
;;; consult.el ends here
