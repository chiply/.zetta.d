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
   ;; nil: fixed-height minibuffer, no movement while typing.  The
   ;; static whitespace below sparse vertical candidates is fine; the
   ;; shrink-snap it used to suffer is fixed by freezing core's
   ;; auto-resize (see vertico--resize-window@zetta-freeze-height).
   vertico-resize nil
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

  ;; IS for intellisense — candidate docs (C-S-h) and definition
  ;; (C-S-f) WITHOUT leaving the completion session: the highlighted
  ;; candidate is materialized over the completion region in the
  ;; completing buffer just long enough to run the position-based
  ;; lookup, then the text is restored — the minibuffer never exits.
  ;; (Replaces the old vertico-exit + vertico-repeat resurrection
  ;; hack, which closed and reopened the session for every peek.)

  (defvar zetta-IS--region nil
    "Cons of (BEG-MARKER . END-MARKER) for the live in-region session.")

  (defun zetta-IS--capture-region (start end &rest _)
    "Record the completion-in-region span so IS peeks can find it."
    (setq zetta-IS--region (cons (copy-marker start) (copy-marker end t)))
    (add-hook 'minibuffer-exit-hook #'zetta-IS--clear-region))

  (defun zetta-IS--clear-region ()
    (remove-hook 'minibuffer-exit-hook #'zetta-IS--clear-region)
    (setq zetta-IS--region nil))

  (advice-add 'consult-completion-in-region :before #'zetta-IS--capture-region)

  ;; with vertico-resize nil the minibuffer should hold a FIXED
  ;; height, but core redisplay shrink-fits a NON-SELECTED minibuffer
  ;; to its content (ignoring Lisp-level resize-mini-windows
  ;; settings) — so peeks (which select the code window internally)
  ;; and plain window switching kept snapping it.  Solution from the
  ;; content side: pad the candidate lines to vertico-count so the
  ;; content always fills the window — fit-to-content then has
  ;; nothing to shrink.  Skipped for flat/unobtrusive displays.
  (define-advice vertico--arrange-candidates (:filter-return (lines) zetta-pad-height)
    (if (and (not vertico-resize)
             (not (bound-and-true-p vertico-flat-mode))
             (not (bound-and-true-p vertico-unobtrusive-mode)))
        (append lines (make-list (max 0 (- vertico-count (length lines))) "\n"))
      lines))

  ;; window persistence is likewise a session property, decided here
  ;; at the common entrance: peek windows outlive the session no
  ;; matter how it was entered (C-SPC, TAB, corfu's M-m).  Entrances
  ;; opt INTO transient sweep-on-exit by binding this flag (C-u C-SPC
  ;; does).
  (defvar zetta-IS--transient nil
    "Non-nil when the current in-region session wants transient windows.")

  (define-advice consult-completion-in-region
      (:around (fn &rest args) zetta-persist-windows)
    (let ((read-minibuffer-restore-windows
           (and zetta-IS--transient read-minibuffer-restore-windows)))
      (apply fn args)))

  ;; every route into a consult in-region session (C-SPC, TAB, corfu's
  ;; M-m) collides with lingering copilot ghost text the same way:
  ;; the ghost straggles behind the candidate preview.  Clear it at
  ;; the common entrance instead of per-command.
  (defun zetta-IS--clear-copilot (&rest _)
    (when (and (fboundp 'copilot-clear-overlay)
               (bound-and-true-p copilot-mode))
      (copilot-clear-overlay)))
  (advice-add 'consult-completion-in-region :before #'zetta-IS--clear-copilot)

  ;; consult delegates 0/1-candidate completions to the default
  ;; completion-in-region machinery (sensible: no picker needed) — but
  ;; under orderless `completion-try-completion' never extends the
  ;; input, so the default handler can neither insert the sole
  ;; candidate nor confirm it, and every press just repeats "Next char
  ;; not unique".  Handle the trivial cases ourselves; delegate the
  ;; real sessions to consult untouched.
  (define-advice consult-completion-in-region
      (:around (fn start end table &optional pred) zetta-trivial-cases)
    (let* ((initial (buffer-substring-no-properties start end))
           (md (completion-metadata initial table pred))
           (all (completion-all-completions
                 initial table pred (max 0 (- (point) start)) md)))
      (when-let* ((last (last all))) (setcdr last nil))
      (cond
       ((null all)
        (message "No match")
        nil)
       ((null (cdr all))
        ;; sole candidate: insert it directly, respecting completion
        ;; boundaries (file tables complete only the last segment) and
        ;; the capf exit-function (lsp applies its insert-text there)
        (let* ((cand (car all))
               (bounds (completion-boundaries initial table pred ""))
               (field-beg (+ start (car bounds)))
               (exit (plist-get completion-extra-properties :exit-function)))
          (goto-char end)
          (delete-region field-beg end)
          (insert cand)
          (when exit (funcall exit cand 'finished))
          t))
       (t (funcall fn start end table pred)))))

  (defun zetta-vertico-IS--peek (action)
    "Run ACTION in the completing buffer with the current candidate
materialized over the completion region, then restore the text.
The minibuffer session stays alive throughout."
    (let ((cand (and (bound-and-true-p vertico--candidates)
                     (if (>= vertico--index 0)
                         (vertico--candidate)
                       (car vertico--candidates))))
          (win (minibuffer-selected-window)))
      (if (not (and cand win zetta-IS--region
                    (eq (marker-buffer (car zetta-IS--region))
                        (window-buffer win))))
          (message "No candidate to inspect here")
        (with-selected-window win
          (let* ((beg (marker-position (car zetta-IS--region)))
                 (end (marker-position (cdr zetta-IS--region)))
                 (orig (buffer-substring beg end))
                 ;; LSP labels may carry the full signature
                 ;; ("foo(a, b)"); materialize only the name so the
                 ;; lookup position lands on a real symbol
                 (cand (car (split-string (substring-no-properties cand)
                                          "("))))
            (goto-char beg)
            (delete-region beg end)
            (insert cand)
            (unwind-protect
                (funcall action)
              (delete-region beg (+ beg (length cand)))
              (goto-char beg)
              (insert orig)))))))

  (defun zetta-vertico-IS-help ()
    "Show docs for the highlighted candidate; the session stays open."
    (interactive)
    (zetta-vertico-IS--peek
     (lambda ()
       ;; lisp-data-mode is the ancestor of all the lisp modes
       (if (derived-mode-p 'lisp-data-mode)
           (zetta-helpful-at-point)
         (lsp-describe-thing-at-point-1)))))

  (defun zetta-vertico-IS-find ()
    "Show the highlighted candidate's definition; the session stays open."
    (interactive)
    (zetta-vertico-IS--peek
     (lambda ()
       (if (derived-mode-p 'lisp-data-mode)
           (if (fboundp 'evil-goto-definition-1)
               (evil-goto-definition-1)
             (xref-find-definitions (thing-at-point 'symbol t)))
         (lsp-find-definition-1)))))

  (defun zetta-vertico-IS (&optional transient)
    "LSP-flavored completion-at-point in the minibuffer.
Doc/definition peek windows opened during the session persist after
it ends, matching the corfu variants.  With prefix arg TRANSIENT,
the session instead cleans its windows up on exit (the stock
`read-minibuffer-restore-windows' behavior)."
    (interactive "P")
    ;; consult-completion-in-region silently falls back to the default
    ;; completion UI ("Next char not unique") unless vertico-mode is
    ;; already on — and vertico loads lazily at first minibuffer use,
    ;; so force it in case IS is the session's first completion
    (require 'vertico)
    (unless (derived-mode-p 'lisp-data-mode)
      (when (and (fboundp 'lsp) (not (and (boundp 'lsp-mode) lsp-mode)))
        (lsp)))
    (let ((completion-in-region-function 'consult-completion-in-region)
          ;; persistence itself is handled at the consult entrance
          ;; (consult-completion-in-region@zetta-persist-windows);
          ;; the prefix arg opts this session into transient cleanup
          (zetta-IS--transient transient)
          ;; sorting adds nothing when completing at point
          (vertico-sort-function nil))
      (if (and (boundp 'corfu--candidates) corfu--candidates)
          (corfu-quit))
      ;; copilot ghost clearing happens in zetta-IS--clear-copilot,
      ;; advised onto consult-completion-in-region for all entrances
      (completion-at-point)))

  ;; bind the IS entry point per modal system.  This must run from
  ;; elpaca-after-init-hook: editor/evil.el does (setcdr
  ;; evil-insert-state-map nil) in evil's :config, wiping any earlier
  ;; binding — which is exactly how the original binding through
  ;; zetta-modal-states-insert kept vanishing.
  (defun zetta-vertico-IS--bind-keys ()
    (when (boundp 'evil-insert-state-map)
      (general-define-key :keymaps 'evil-insert-state-map
                          "C-SPC" #'zetta-vertico-IS))
    (when (boundp 'meow-insert-state-keymap)
      (general-define-key :keymaps 'meow-insert-state-keymap
                          "C-SPC" #'zetta-vertico-IS)))
  (if (bound-and-true-p elpaca-after-init-time)
      (zetta-vertico-IS--bind-keys)
    (add-hook 'elpaca-after-init-hook #'zetta-vertico-IS--bind-keys 90))

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

            ;; intellisesne — f for "find"; C-S-d belongs to windmove
            ;; in general-override-mode-map, which outranks vertico-map
            "C-S-h" 'zetta-vertico-IS-help
            "C-S-f" 'zetta-vertico-IS-find
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

  ;; vertico-IS entry bindings live in :config, each guarded by its
  ;; modal system's feature — see the with-eval-after-load forms there.

  :hook (
         ;; needed for vertico repeatt (and therefore the intellisense)
         (minibuffer-setup . vertico-repeat-save)
         )
  )
;;; vertico.el ends here
