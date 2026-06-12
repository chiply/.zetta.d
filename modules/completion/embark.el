;;; embark.el --- Configure embark -*- lexical-binding: t; -*-

;; The bulk of the zetta-flavored embark extensions -- type-aware
;; nav/pick/act, cycle sort, collectors, capture-mode, the
;; deftap-finder macro, the word target finder -- now live in the
;; `embark-scope' package (under `source/zettapkg/').  This file
;; wraps embark itself, keeps the project-map and a few small zetta
;; utilities, and configures the keybindings.  See
;; `modules/completion/embark-scope.el' for the package wrapper.

(use-package embark
  :ensure (:wait t)
  :defer t
  :config
  ;; Don't quit on `embark-act' so it can be repeated.
  (defun embark-act-noquit ()
    "Run action but don't quit the minibuffer afterwards."
    (interactive)
    (let ((embark-quit-after-action nil))
      (embark-act)))

  (setq embark-help-key "C-h")

  (defun embark-which-key-indicator ()
    "An embark indicator that displays keymaps using which-key.
The which-key help message will show the type and value of the
current target followed by an ellipsis if there are further
targets."
    (lambda (&optional keymap targets prefix)
      (if (null keymap)
          (which-key--hide-popup-ignore-command)
        (which-key--show-keymap
         (if (eq (plist-get (car targets) :type) 'embark-become)
             "Become"
           (format "Act on %s '%s'%s"
                   (plist-get (car targets) :type)
                   (embark--truncate-target (plist-get (car targets) :target))
                   (if (cdr targets) "…" "")))
         (if prefix
             (pcase (lookup-key keymap prefix 'accept-default)
               ((and (pred keymapp) km) km)
               (_ (key-binding prefix 'accept-default)))
           keymap)
         nil nil t (lambda (binding)
                     (not (string-suffix-p "-argument" (cdr binding))))))))

  ;; Minimal echo-area indicator instead of the which-key popup --
  ;; eliminates the popup redraw that causes visible jitter when
  ;; cycling embark-act through multiple targets.  `embark-bindings'
  ;; (`C-h B') is the discoverability path.  `embark-which-key-indicator'
  ;; is defined above and can be swapped in here when you want the
  ;; popup explicitly.
  (setq embark-indicators
        '(embark-minimal-indicator
          embark-highlight-indicator
          embark-isearch-highlight-indicator))

  (defun embark-hide-which-key-indicator (fn &rest args)
    "Hide the which-key indicator immediately when using the
completing-read prompter."
    (which-key--hide-popup-ignore-command)
    (let ((embark-indicators
           (remq #'embark-which-key-indicator embark-indicators)))
      (apply fn args)))

  (advice-add #'embark-completing-read-prompter
              :around #'embark-hide-which-key-indicator)

  ;; Extend `embark-org--types' with element types that the upstream
  ;; embark-org explicitly leaves out.  Each becomes an `org-<type>'
  ;; target via `embark-org-target-element-context'.  Bind a keymap
  ;; in `embark-keymap-alist' for type-specific actions; the default
  ;; falls back to `embark-general-map'.
  (with-eval-after-load 'embark-org
    (dolist (type '(drawer property-drawer quote-block example-block
                    comment-block verse-block keyword planning
                    latex-environment latex-fragment))
      (cl-pushnew type embark-org--types)))

  ;; Act on the last echo-area message (from oantolin's config): jump to
  ;; the end of *Messages* and act on whatever target is there -- the
  ;; file/URL/symbol a command just mentioned.  `embark--end-of-target'
  ;; (a default pre-action hook) is neutralised so the action does not
  ;; move point inside *Messages*.
  (defun embark-on-last-message (arg)
    "Act on the last message displayed in the echo area."
    (interactive "P")
    (with-current-buffer "*Messages*"
      (goto-char (1- (point-max)))
      (cl-letf (((symbol-function #'embark--end-of-target) #'ignore))
        (embark-act arg))))

  ;; project
  (defvar-keymap embark-project-map :parent embark-general-map)
  (add-to-list 'embark-keymap-alist '(project embark-project-map))

  ;; find file
  (defvar zetta-embark-project-find-dir nil
    "Project directory last acted on with `embark-consult-project-find-in-dir'.")

  (defun zetta-embark-project-find ()
    "Run `consult-project-extra-find' in `zetta-embark-project-find-dir'.
A real command (not just a `this-command' alias) so the minibuffer
session is recorded by `vertico-repeat' under a name that, when
resumed, restores the project directory it was acting on."
    (interactive)
    (let ((default-directory (or zetta-embark-project-find-dir
                                 default-directory)))
      (call-interactively 'consult-project-extra-find)))

  ;; Same on-demand preview as consult-project-extra-find (consult looks
  ;; up customizations by `this-command', which is this symbol here).
  (with-eval-after-load 'consult
    (consult-customize zetta-embark-project-find :preview-key "C-="))

  (defun embark-consult-project-find-in-dir (dir)
    (setq zetta-embark-project-find-dir dir)
    ;; `call-interactively' does not set `this-command'; bind it so both
    ;; consult's preview lookup and `vertico-repeat-save' see the
    ;; resumable command rather than `embark-act'.
    (let ((this-command 'zetta-embark-project-find))
      (call-interactively 'zetta-embark-project-find)))

  ;; vc dir
  (defun embark-vc-dir (dir)
    (let ((default-directory dir))
      (if (fboundp 'magit)
          (call-interactively #'magit)
        (call-interactively #'project-vc-dir))))

  ;; dired
  (defun embark-dired (dir)
    (dired dir))

  ;; regex
  (defun embark-project-ripgrep (dir)
    (let ((default-directory dir)
          (this-command 'consult-ripgrep))  ;; to disable preview
      (if (fboundp 'consult-ripgrep)
          (call-interactively #'consult-ripgrep)
        (call-interactively #'grep))))

  ;; vterm
  (defun embark-project-vterm (dir)
    (let ((default-directory dir))
      (if (fboundp 'vterm)
          (call-interactively #'vterm)
        (call-interactively #'shell))))

  (general-define-key
   :keymaps 'embark-project-map
   "<return>" 'embark-vc-dir
   "f" 'embark-consult-project-find-in-dir
   "d" 'embark-dired
   "r" 'embark-project-ripgrep
   "v" 'embark-project-vterm
   "m" 'embark-vc-dir)

  :general
  (
   ;; override alone doesn't work here for some reason
   :keymaps (append zetta-modal-states-non-insert '(override))
   "C-." 'embark-act
   "C-h B" 'embark-bindings
   "C-h E" 'embark-on-last-message
   "C-;" 'embark-dwim
   "C->" 'embark-act-all)
  (
   :keymaps '(vertico-map)
   "C-." 'embark-act
   "C-;" 'embark-dwim
   "C->" 'embark-act-all)
  (
   :keymaps '(embark-collect-mode-map)
   "s-j" 'outline-forward-same-level
   "s-k" 'outline-backward-same-level)
  :config
  ;; embark loads before evil, so the :general block above misses evil's
  ;; state maps (they're added to zetta-modal-states-non-insert only after
  ;; evil loads).  Re-bind explicitly so evil's own C-. -> evil-repeat-pop
  ;; doesn't shadow embark-act in normal/visual state.
  (with-eval-after-load 'evil
    (general-define-key
     :keymaps '(evil-normal-state-map
                evil-visual-state-map)
     "C-."   'embark-act
     "C-h B" 'embark-bindings
     "C-h E" 'embark-on-last-message
     "C-;"   'embark-dwim
     "C->"   'embark-act-all)))


;;;; Repeatable-lite help handler (zetta-flavored help integration)

(defun zetta-embark-help-handler (km prefix)
  "Show embark bindings for KM via completing-read.
PREFIX is saved so repeatable can continue the loop."
  (setq repeatable-current-prefix prefix)
  (minibuffer-with-setup-hook
      (lambda ()
        (repeatable-setup-minibuffer-switches #'zetta-embark-help-handler))
    (let ((command (consult--read
                    (car (embark--formatted-bindings km))
                    :prompt "Act: "
                    :category 'embark-keybinding)))
      (call-interactively (intern (car (last (string-split command))))))))

(add-to-list 'repeatable-help-backends
             '(?\C-\S-h "C-S-h" "embark" zetta-embark-help-handler)
             t)

;;; embark.el ends here
