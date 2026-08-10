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
  :after (hyperbole)
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

  ;; Show the target TYPE (and any shadowed target types) in the minibuffer,
  ;; the same as in a regular buffer.  `embark--format-targets' deliberately
  ;; collapses to a bare "Act" when acting from a non-prompter minibuffer
  ;; (hiding the type and the other cyclable types); neutralise just the one
  ;; `minibufferp' check inside it so the minibuffer gets the full
  ;; "Act on TYPE ‘TARGET’(other-types…)" indicator -- and so the extra types
  ;; `embark-cycle' can reach become visible there too.
  (defun zetta-embark--full-minibuffer-target (orig &rest args)
    "Run ORIG `embark--format-targets' as if not in a minibuffer (full indicator)."
    (cl-letf (((symbol-function 'minibufferp) #'ignore))
      (apply orig args)))
  (advice-add 'embark--format-targets :around
              #'zetta-embark--full-minibuffer-target)

  ;; In a file-completion minibuffer, also offer the candidate FILENAME's
  ;; subwords as cyclable `identifier' targets, so `embark-act' can step
  ;; file -> "config" -> "utils" -> ... like the at-point types you get in a
  ;; regular buffer (dired etc.).  `embark-act' uses only the FIRST finder that
  ;; returns in a minibuffer, so a new finder can't add targets; instead append
  ;; to the one that wins (the vertico candidate finder) via `:filter-return',
  ;; reusing embark's already-correct (directory-aware) file target as the
  ;; first/default entry.
  (defcustom zetta-embark-file-subword-targets t
    "When non-nil, `embark-act' in a file minibuffer also offers the candidate's
filename subwords as cyclable `identifier' targets."
    :type 'boolean :group 'zetta)

  (defun zetta-embark--append-file-subwords (target)
    "Append filename-subword `identifier' targets to a file candidate TARGET.
In a file-completion minibuffer return a LIST -- TARGET first (so the file
stays the default), then one `identifier' target per >=2-char filename subword
-- else TARGET unchanged."
    (if (and zetta-embark-file-subword-targets
             (consp target)
             (minibufferp) minibuffer-completing-file-name)
        (let* ((tb (cdr target))
               (path (if (consp tb) (car tb) tb))
               (base (and (stringp path)
                          (file-name-nondirectory (directory-file-name path))))
               (subs (and base
                          (seq-uniq (seq-filter (lambda (s) (>= (length s) 2))
                                                (split-string base "[^[:alnum:]]+" t))))))
          (if subs
              (cons target (mapcar (lambda (s) (cons 'identifier s)) subs))
            target))
      target))

  (with-eval-after-load 'vertico
    (advice-add 'embark--vertico-selected :filter-return
                #'zetta-embark--append-file-subwords))

  (defun embark-hide-which-key-indicator (fn &rest args)
    "Hide the which-key indicator immediately when using the
completing-read prompter."
    (which-key--hide-popup-ignore-command)
    (let ((embark-indicators
           (remq #'embark-which-key-indicator embark-indicators)))
      (apply fn args)))

  (advice-add #'embark-completing-read-prompter
              :around #'embark-hide-which-key-indicator)

  ;; docs for the identifier at point (mode-dispatched: helpful for
  ;; lisps, lsp hover elsewhere; defined in modules/tools/lsp.el).
  ;; Shadows `display-local-help', which keeps its global home on
  ;; `C-h .' — and matches `h' in the treesit-tap embark maps.
  (keymap-set embark-identifier-map "h" #'zetta-doc-at-point)

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
  ;;
  ;; Noise lines are skipped: every C-g logs "Quit" (so bailing out of
  ;; one attempt would make "Quit" the next attempt's target), and
  ;; embark's own minimal indicator logs its "Act on ..." prompt.
  (defvar zetta-embark-last-message-noise
    (rx bos (or "" "Quit" "Mark set" "Mark saved" "Mark activated"
                "Mark deactivated"
                (seq "Act on " (* nonl)))
        eos)
    "Regexp for *Messages* lines `embark-on-last-message' skips over.")

  (defun embark-on-last-message (arg)
    "Act on the last substantive message displayed in the echo area.
Trailing lines matching `zetta-embark-last-message-noise' are skipped."
    (interactive "P")
    (with-current-buffer "*Messages*"
      (goto-char (point-max))
      (skip-chars-backward "\n")
      (while (string-match-p
              zetta-embark-last-message-noise
              (buffer-substring-no-properties
               (line-beginning-position) (line-end-position)))
        (when (<= (line-beginning-position) (point-min))
          (user-error "No substantive message to act on"))
        (forward-line -1))
      (end-of-line)
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

;; Registered only once repeatable is actually loaded.  The package
;; requires Emacs 30.1, and bootstrap-repeatable's unavailable-fallback
;; (CI cold cache, older Emacsen) shims only `repeatable-wrap' -- so a
;; bare top-level reference here crashed init with void-variable on
;; every cold-cache 29.4 run, which also stopped the elpaca cache from
;; ever being saved, keeping those runs cold forever.
(with-eval-after-load 'repeatable
  (add-to-list 'repeatable-help-backends
               '(?\C-\S-h "C-S-h" "embark" zetta-embark-help-handler)
               t))

;;; embark.el ends here
