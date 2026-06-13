;;; vertico.el --- Configure vertico -*- lexical-binding: t; -*-

(use-package vertico-posframe
  :config
  ;;(vertico-posframe-mode 1)
  (setq vertico-posframe-parameters
        '((left-fringe . 0)
          (right-fringe . 0)))
  ;; TODO compute this dynamically
  (setq vertico-posframe-width nil)
  (setq vertico-posframe-height nil))

(use-package vertico
  ;;:straight (:files (:defaults "extensions/*"))

  :init
  (vertico-mode 1)
  (vertico-mouse-mode 1)
  (vertico-flat-mode 1)
  (vertico-multiform-mode 1)

  ;; NOTE experimenting with this for now.
  (setq vertico-multiform-commands
        '((zetta-magit-project
           posframe
           ;; NEED to do both here
           (vertico-flat-mode . -1)
           (vertico-vertical-mode . 1))
          ;;(t flat)
          ))

  ;; TODO add embark prompt for keybinding to present candidates in
  ;; GRID -- bc of how I bring these up (with veratile C-h), I'm
  ;; having trouble
  (add-to-list 'vertico-multiform-categories '(variable grid))

  (setq
   vertico-buffer-hide-prompt nil
   vertico-cycle t
   vertico-resize nil ;; avoid moving prompt while typing
   vertico-grid-max-columns 10
   vertico-buffer-display-action '(display-buffer-in-side-window
                                   (side . right)
                                   (window-width . 0.25)))

  ;;;; vertico-repeat hygiene
  ;; Embark's completing-read action prompter runs inside `embark-act',
  ;; so its minibuffer session is recorded under `embark-act' -- and
  ;; repeating that re-runs embark-act with no target ("No target
  ;; found") instead of anything useful.  Keep those sessions out of
  ;; the history entirely.
  (with-eval-after-load 'vertico-repeat
    (dolist (cmd '(embark-act embark-act-noquit embark-act-all
                   embark-dwim embark-become))
      (cl-pushnew cmd vertico-repeat-filter))

    ;; A `repeatable-wrap-FOO' wrapper leaves `this-command' as the
    ;; wrapper when FOO's minibuffer is set up, so the session would
    ;; repeat the wrapper -- re-entering the repeat loop.  Record it
    ;; as plain FOO so `vertico-repeat' resumes the command itself.
    (defun zetta-vertico-repeat-unwrap-repeatable (session)
      "Record a `repeatable-wrap-FOO' SESSION as plain FOO."
      (when session
        (let ((name (symbol-name (car session))))
          (when (string-prefix-p "repeatable-wrap-" name)
            (setcar session
                    (intern (substring name (length "repeatable-wrap-")))))))
      session)
    (add-to-list 'vertico-repeat-transformers
                 #'zetta-vertico-repeat-unwrap-repeatable t)

    ;; `vertico-repeat--filter-empty' drops sessions with no input, so a
    ;; C-g straight out of a minibuffer leaves nothing to resume.  For
    ;; context-carrying commands the context IS the point of resuming --
    ;; `zetta-embark-project-find' remembers which project it was acting
    ;; on -- so spare those from the empty filter.
    (defvar zetta-vertico-repeat-keep-empty '(zetta-embark-project-find)
      "Commands whose vertico-repeat sessions are saved even with empty input.")

    (defun zetta-vertico-repeat--filter-empty (session)
      "Like `vertico-repeat--filter-empty', sparing context-carrying commands.
SESSION is kept regardless of input if its command is listed in
`zetta-vertico-repeat-keep-empty'."
      (if (memq (car session) zetta-vertico-repeat-keep-empty)
          session
        (vertico-repeat--filter-empty session)))

    (setq vertico-repeat-transformers
          (mapcar (lambda (f)
                    (if (eq f #'vertico-repeat--filter-empty)
                        #'zetta-vertico-repeat--filter-empty
                      f))
                  vertico-repeat-transformers)))

  ;; this is super super hacky and bizarre... but it's the only way I
  ;; can get this to work

  ;; only works when called from zetta-vertico-IS
  ;; IS for intellisense
  (setq zetta-vertico-IS-help-flag nil)
  (setq zetta-vertico-IS-find-flag nil)

  (defun zetta-vertico-IS-help ()
    (interactive)
    (setq zetta-vertico-IS-help-flag t)
    (vertico-exit)
    (zetta-soda-create-and-display-term))

  (defun zetta-vertico-IS-find ()
    (interactive)
    (setq zetta-vertico-IS-find-flag t)
    (vertico-exit))

  (defun zetta-vertico-IS ()
    (interactive)
    (when (not (or
                (string= major-mode "emacs-lisp-mode")
                (string= major-mode "lisp-interaction-mode")
                (string= major-mode "lisp-mode")
                (string= major-mode "lisp-data-mode")))
      (when (and (fboundp 'lsp) (not (and (boundp 'lsp-mode) lsp-mode)))
        (lsp)))
    (let* ((completion-in-region-function 'consult-completion-in-region)
           ;; this prevents sorting, which can cause vertico repeat to
           ;; yield a different state!  We actually don't /care about/
           ;; sortiing when usinig completion at poiint
           (vertico-sort-function nil)
           (pt (point))
           (linetxt (buffer-substring
                     (line-beginning-position) (line-end-position))))
      (if (and (boundp 'corfu--candidates) corfu--candidates)
          (corfu-quit))
      (completion-at-point)
      (when zetta-vertico-IS-help-flag
        (if (or
             (string= major-mode "emacs-lisp-mode")
             (string= major-mode "lisp-interaction-mode")
             (string= major-mode "lisp-mode")
             (string= major-mode "lisp-data-mode"))
            (zetta-helpful-at-point)
          (lsp-describe-thing-at-point-1))
        (progn (beginning-of-line) (kill-line))
        (progn (insert linetxt) (goto-char pt))
        (setq zetta-vertico-IS-help-flag nil)
        (call-interactively 'vertico-repeat))
      (when zetta-vertico-IS-find-flag
        (if (or
             (string= major-mode "emacs-lisp-mode")
             (string= major-mode "lisp-interaction-mode")
             (string= major-mode "lisp-mode")
             (string= major-mode "lisp-data-mode"))
            ;; LEFT OFF -- need to refine these functions
            ;; what if definition is in the same buffer... maybe the
            ;; way we use let will inform this
            (if (fboundp 'evil-goto-definition-1)
                (evil-goto-definition-1)
              (xref-find-definitions (thing-at-point 'symbol t)))
          (lsp-find-definition-1))
        (zetta-vertico-IS-find)
        (progn (beginning-of-line) (kill-line))
        (progn (insert linetxt) (goto-char pt))
        (setq zetta-vertico-IS-find-flag nil)
        (call-interactively 'vertico-repeat))))

  (defun my/vertico-quick-embark (&optional arg)
    "Embark on candidate using quick keys."
    (interactive)
    (when (vertico-quick-jump)
      (embark-act arg)))

  :general
  (:keymaps 'override
            "s-V" 'vertico-repeat)

  (:keymaps 'vertico-map
            ;; embark-select
            "C-SPC" 'embark-select

            ;; intellisesne
            "C-S-h" 'zetta-vertico-IS-help
            "C-S-d" 'zetta-vertico-IS-find
            ;; navigation
            "C-j" 'vertico-next
            "C-k" 'vertico-previous
            "C-S-j" 'vertico-scroll-down
            "C-S-k" 'vertico-scroll-up
            "s-j" 'vertico-next-group
            "s-k" 'vertico-previous-group
            ;; yanking
            "C-y" 'yank
            "<C-return>" 'vertico-exit-input
            ;; avy-like quick selection
            "C-'" 'vertico-quick-exit
            "C-\"" 'my/vertico-quick-embark
            ;; editing prompt
            "C-S-k" 'kill-line
            ;; switching states
            "M-V" 'vertico-multiform-vertical
            "M-R" 'vertico-multiform-reverse
            "M-G" 'vertico-multiform-grid
            "M-F" 'vertico-multiform-flat
            "M-U" 'vertico-multiform-unobtrusive
            ;; save and suspend
            ;;"M-C" 'vertico-save
            "M-S" 'vertico-suspend
            )

  (
   :keymaps 'override
   "M-S" 'vertico-suspend
   )

  ;; remapping for reverse
  (
   :keymaps 'vertico-reverse-map
   "C-k" 'vertico-next
   "C-j" 'vertico-previous
   "C-S-j" 'vertico-scroll-down
   "C-S-k" 'vertico-scroll-up
   "s-k" 'vertico-next-group
   "s-j" 'vertico-previous-group
   )

  ;; remapping for flat
  (
   :keymaps 'vertico-flat-map
   "C-j" 'vertico-next
   "C-k" 'vertico-previous
   "C-S-j" 'vertico-scroll-down
   "C-S-k" 'vertico-scroll-up
   "s-j" 'vertico-next-group
   "s-k" 'vertico-previous-group
   )

  ;; vertico-IS
  (
   :keymaps zetta-modal-states-insert
   "<C-SPC>" 'zetta-vertico-IS
   )

  :hook (
         ;; needed for vertico repeatt (and therefore the intellisense)
         (minibuffer-setup . vertico-repeat-save)
         )
  )
;;; vertico.el ends here
