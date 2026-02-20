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
      (unless (and (boundp 'lsp-mode) lsp-mode)
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
            (evil-goto-definition-1) 
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
            "C-d" 'consult-dir
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


