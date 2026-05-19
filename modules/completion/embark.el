;;; embark.el --- Configure embark -*- lexical-binding: t; -*-

(use-package embark
  :ensure (:wait t)
  :commands (embark-act embark-dwim embark-bindings embark-act-all)
  :config
  ;;(setq embark-prefix-help-command #'embark-prefix-help-command)
  (defun embark-act-noquit ()
    "Run action but don't quit the minibuffer afterwards."
    (interactive)
    (let ((embark-quit-after-action nil))
      (embark-act)))

  (setq embark-indicators
        '(
          embark-verbose-indicator
          embark-highlight-indicator
          embark-minimal-indicator
          ))
  (setq embark-confirm-act-all nil)

  (define-key embark-general-map (kbd "C-b") 'zetta-bookmark-create)
  (define-key embark-general-map (kbd "!") 'symbol-overlay-put)
  (define-key embark-general-map (kbd "C-!") 'symbol-overlay-remove-all)

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
  ;; cycling embark-act through multiple targets. `embark-bindings'
  ;; (`C-h B') is the discoverability path now.
  (setq embark-indicators
        '(
          embark-minimal-indicator
          embark-highlight-indicator
          embark-isearch-highlight-indicator))

  ;; Bridge B: thing-at-point -> embark target finder factory.
  ;; `zetta-embark-deftap-finder' interns a named target-finder defun
  ;; for any THING that `bounds-of-thing-at-point' understands, and
  ;; registers it with embark. Named (not anonymous) so re-loading
  ;; this file is idempotent under `add-to-list'. Combined with
  ;; Bridge A in `tap.el', tree-sitter bounds flow through to embark
  ;; in treesit buffers with no further wiring.
  (defmacro zetta-embark-deftap-finder (thing &optional type)
    "Define and register an embark target finder for thing-at-point THING.
TYPE is the embark target type reported; defaults to THING."
    (let* ((thing-sym (if (and (consp thing) (eq (car thing) 'quote))
                          (cadr thing) thing))
           (type-sym (or (and (consp type) (eq (car type) 'quote) (cadr type))
                         type thing-sym))
           (name (intern (format "zetta-embark-target-%s-at-point" thing-sym))))
      `(progn
         (defun ,name ()
           ,(format "Embark target finder for thing-at-point `%s'." thing-sym)
           ;; Skip completion UIs: minibuffer / collect / completions
           ;; buffers should be classified by embark's own minibuffer
           ;; finders, not by our bounds-of-thing-at-point overlays.
           ;; Without this guard, e.g. `bounds-of-thing-at-point 'brick'
           ;; happily computes bounds against the candidate text and
           ;; steals the default target.
           (unless (or (minibufferp)
                       (derived-mode-p 'completion-list-mode
                                       'embark-collect-mode))
             (when-let* ((bnds (bounds-of-thing-at-point ',thing-sym)))
               ;; Embark's bounded-target shape is the dotted list
               ;; (TYPE TARGET START . END) -- NOT (TYPE TARGET START END).
               (cons ',type-sym
                     (cons (buffer-substring-no-properties (car bnds) (cdr bnds))
                           (cons (car bnds) (cdr bnds)))))))
         (add-to-list 'embark-target-finders #',name))))

  ;; Register finders for the user-defined things in `tap.el' that
  ;; embark would not otherwise see (block/brick come from tap-block.el
  ;; and tap.el via `put ... bounds-of-thing-at-point').
  (zetta-embark-deftap-finder block)
  (zetta-embark-deftap-finder brick)

  ;; A defun keymap so embark has somewhere to dispatch when its
  ;; built-in `embark-target-defun-at-point' fires (it ships no
  ;; defun-specific map by default; the keymap also covers the
  ;; treesit-bridged `defun' bounds from Bridge A).
  (defvar-keymap embark-defun-map
    :parent embark-general-map
    "e" #'eval-defun
    "n" #'narrow-to-defun
    "m" #'mark-defun)
  (setf (alist-get 'defun embark-keymap-alist) 'embark-defun-map)

  ;; Bridge C: tree-sitter AST node -> embark target.
  ;; Walks up from `treesit-node-at' until the node type is in
  ;; `zetta-embark-treesit-types', then reports it as embark type
  ;; `ts-<node-type>'. Action menus respond to the *exact* AST node
  ;; under point (string literal, call expression, argument list, ...)
  ;; rather than thing-at-point's coarser categories.
  (defcustom zetta-embark-treesit-types
    '("function_definition" "function_declaration"
      "class_definition" "class_declaration"
      "method_definition" "method_declaration"
      "call" "call_expression"
      "string" "string_literal"
      "comment"
      "decorator"
      "argument_list" "parameter_list" "parameters"
      "if_statement" "for_statement" "while_statement"
      "import_statement" "import_from_statement")
    "Tree-sitter node-type names Bridge C surfaces to embark.
Each entry becomes a target of type `ts-<NAME>'; bind actions in
`embark-keymap-alist' under that symbol. Node-type names vary by
language (e.g. python `call' vs javascript `call_expression');
include both spellings of any construct you want to target."
    :type '(repeat string)
    :group 'embark)

  (defun zetta-embark-target-treesit-node-at-point ()
    "Embark target finder: smallest interesting tree-sitter node at point.
Walks up from `treesit-node-at' until the node type is a member of
`zetta-embark-treesit-types'. Returns nil if the buffer has no
treesit parser or no matching ancestor exists."
    (when (and (fboundp 'treesit-parser-list) (treesit-parser-list))
      (let ((node (treesit-node-at (point))))
        (while (and node
                    (not (member (treesit-node-type node)
                                 zetta-embark-treesit-types)))
          (setq node (treesit-node-parent node)))
        (when node
          (let ((start (treesit-node-start node))
                (end (treesit-node-end node)))
            (cons (intern (concat "ts-" (treesit-node-type node)))
                  (cons (buffer-substring-no-properties start end)
                        (cons start end))))))))
  (add-to-list 'embark-target-finders
               #'zetta-embark-target-treesit-node-at-point)

  ;; Alias function/method/class AST types to `embark-defun-map' so the
  ;; existing eval/narrow/mark actions apply -- those commands are
  ;; point-based and pick up the right region via Bridge A's bounds.
  (dolist (sym '(ts-function_definition ts-function_declaration
                 ts-method_definition ts-method_declaration
                 ts-class_definition ts-class_declaration))
    (setf (alist-get sym embark-keymap-alist) 'embark-defun-map))

  ;; String literal: treat the node text as URL / path / kill-ring entry.
  (defvar-keymap embark-ts-string-map
    :parent embark-general-map
    "u" #'browse-url
    "f" #'find-file
    "w" #'kill-new)
  (dolist (sym '(ts-string ts-string_literal))
    (setf (alist-get sym embark-keymap-alist) 'embark-ts-string-map))

  ;; Call expression: jump-to-definition uses point (the call site),
  ;; so xref / lsp / eglot variants all just work.
  (defvar-keymap embark-ts-call-map
    :parent embark-general-map
    "d" #'xref-find-definitions
    "r" #'xref-find-references
    "w" #'kill-new)
  (dolist (sym '(ts-call ts-call_expression))
    (setf (alist-get sym embark-keymap-alist) 'embark-ts-call-map))

  ;; Bridge D: expand-region driven by embark target bounds.
  ;; Same idea as `er/expand-region' but the "what units exist at
  ;; point" question is answered by `embark-target-finders'. Grows
  ;; uniformly over every Bridge A/B/C target and any other embark
  ;; finder wired in. Tie-break favours the bounds whose start is
  ;; closest to current start (minimises visible jump on cycle).
  (defvar-local zetta-embark-expand-history nil
    "Stack of (BEG . END) pairs for `zetta-embark-contract-region'.
Cleared on buffer modification.")

  (defun zetta-embark--clear-expand-history (&rest _)
    (setq zetta-embark-expand-history nil))

  (defun zetta-embark--bounded-targets-at-point ()
    "Return list of (BEG . END) for every bounded target at point.
Sources: all `embark-target-finders' return values that include
bounds, plus every treesit ancestor whose node-type is in
`zetta-embark-treesit-types' (Bridge C's finder only surfaces the
innermost match -- this walk recovers the intermediate scopes so
`zetta-embark-expand-region' can step through them)."
    (let (bounds)
      (dolist (finder embark-target-finders)
        (let ((result (ignore-errors (funcall finder))))
          (when result
            (let ((targets (if (and (consp result) (symbolp (car result)))
                               (list result)
                             result)))
              (dolist (tgt targets)
                (when (and (consp tgt)
                           (consp (cdr tgt))
                           (consp (cddr tgt))
                           (numberp (caddr tgt))
                           (numberp (cdddr tgt)))
                  (push (cons (caddr tgt) (cdddr tgt)) bounds)))))))
      (when (and (fboundp 'treesit-parser-list) (treesit-parser-list))
        (let ((node (treesit-node-at (point))))
          (while node
            (when (member (treesit-node-type node)
                          zetta-embark-treesit-types)
              (push (cons (treesit-node-start node)
                          (treesit-node-end node))
                    bounds))
            (setq node (treesit-node-parent node)))))
      (cl-delete-duplicates bounds :test #'equal)))

  (defun zetta-embark-expand-region ()
    "Expand the active region to the next-smallest embark target bounds
that strictly contains the current region (or point if no region).
Subsequent calls keep growing the selection; `zetta-embark-contract-region'
walks back through the history."
    (interactive)
    (let* ((cur-beg (if (use-region-p) (region-beginning) (point)))
           (cur-end (if (use-region-p) (region-end) (point)))
           (cur-size (- cur-end cur-beg))
           (candidates
            (cl-remove-if-not
             (lambda (b)
               (and (<= (car b) cur-beg)
                    (>= (cdr b) cur-end)
                    (> (- (cdr b) (car b)) cur-size)))
             (zetta-embark--bounded-targets-at-point))))
      (cond
       ((null candidates)
        (message "zetta-embark-expand-region: no further expansion"))
       (t
        (let* ((sorted
                (sort candidates
                      (lambda (a b)
                        (let ((sa (- (cdr a) (car a)))
                              (sb (- (cdr b) (car b))))
                          (if (= sa sb)
                              (< (- cur-beg (car a))
                                 (- cur-beg (car b)))
                            (< sa sb))))))
               (next (car sorted)))
          (when (null zetta-embark-expand-history)
            (add-hook 'after-change-functions
                      #'zetta-embark--clear-expand-history nil t))
          (push (cons cur-beg cur-end) zetta-embark-expand-history)
          (push-mark (car next) t t)
          (goto-char (cdr next)))))))

  (defun zetta-embark-contract-region ()
    "Undo the last `zetta-embark-expand-region' step."
    (interactive)
    (if (null zetta-embark-expand-history)
        (message "zetta-embark-contract-region: no history")
      (let ((prev (pop zetta-embark-expand-history)))
        (if (= (car prev) (cdr prev))
            (progn (deactivate-mark) (goto-char (car prev)))
          (push-mark (car prev) t t)
          (goto-char (cdr prev))))))

  ;; project
  (defvar-keymap embark-project-map :parent embark-general-map)
  (add-to-list 'embark-keymap-alist '(project embark-project-map))

  ;; find file
  (defun embark-consult-project-find-in-dir (dir)
    (let ((default-directory dir)
          ;; to disable preview -- this is bc consult uses 'this
          ;; command' to determine what the active preview function is
          (this-command 'consult-project-extra-find))
      (call-interactively 'consult-project-extra-find)))

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

  ;; TODO seems to be some hijacking of C-g going on.
  (general-define-key
   :keymaps 'embark-project-map
   "<return>" 'embark-vc-dir
   "f" 'embark-consult-project-find-in-dir
   "d" 'embark-dired
   "r" 'embark-project-ripgrep
   "v" 'embark-project-vterm
   "m" 'embark-vc-dir
   )

  :general
  (
   ;; override alone doesn't work here for some reason
   :keymaps (append zetta-modal-states-non-insert '(override))
   "C-." 'embark-act
   "C-h B" 'embark-bindings
   "C-;" 'embark-dwim
   "C->" 'embark-act-all
   )
  (
   :keymaps '(vertico-map)
   "C-." 'embark-act
   "C-;" 'embark-dwim
   "C->" 'embark-act-all
   )
  (
   :keymaps '(embark-collect-mode-map)
   "s-j" 'outline-forward-same-level
   "s-k" 'outline-backward-same-level
   )
  :config
  ;; embark loads before evil, so the :general block above misses evil's
  ;; state maps (they're added to zetta-modal-states-non-insert only after
  ;; evil loads). Re-bind explicitly so evil's own C-. → evil-repeat-pop
  ;; doesn't shadow embark-act in normal/visual state.
  (with-eval-after-load 'evil
    (general-define-key
     :keymaps '(evil-normal-state-map
                evil-visual-state-map)
     "C-."   'embark-act
     "C-h B" 'embark-bindings
     "C-;"   'embark-dwim
     "C->"   'embark-act-all)))

(defun zetta-embark-help-handler (km prefix)
  "Show embark bindings for KM via completing-read.
PREFIX is saved so repeatable-lite can continue the loop."
  (setq repeatable-lite-current-prefix prefix)
  (minibuffer-with-setup-hook
      (lambda ()
        (repeatable-lite-setup-minibuffer-switches #'zetta-embark-help-handler))
    (let ((command (consult--read
                    (car (embark--formatted-bindings km))
                    :prompt "Act: "
                    :category 'embark-keybinding)))
      (call-interactively (intern (car (last (string-split command))))))))

(add-to-list 'repeatable-lite-help-backends
             '(?\C-\S-h "C-S-h" "embark" zetta-embark-help-handler)
             t)
;;; embark.el ends here
