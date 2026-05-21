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

  ;; Backward cycle for embark-act: `C-,' inside the prompter is a
  ;; single-key step-back through the (size-sorted) target list.
  ;;
  ;; The earlier approach of binding `C-,' directly to `negative-argument'
  ;; broke because that command TOGGLES: nil -> `-, `- -> nil, etc.
  ;; Without prefix-arg being reset between cycles, repeated C-, presses
  ;; alternated direction (-1, +1, -1, +1) instead of stepping back.
  ;;
  ;; Instead, bind to a marker symbol that an :around advice on
  ;; `embark-keymap-prompter' intercepts: when seen, force prefix-arg
  ;; to -1 and substitute `embark-cycle' as the returned command.
  (defun zetta-embark-back-cycle ()
    "Marker for single-key backward cycle inside `embark-keymap-prompter'.
The actual back-rotation is performed by the :around advice that
substitutes `embark-cycle' with `prefix-arg' forced to -1."
    (interactive)
    (user-error
     "`zetta-embark-back-cycle' is meant for the embark prompter only"))

  (define-advice embark-keymap-prompter
      (:around (orig keymap update) zetta-back-cycle)
    "Translate `zetta-embark-back-cycle' returns into a backward
`embark-cycle' invocation by forcing `prefix-arg' to -1."
    (let ((cmd (funcall orig keymap update)))
      (if (eq cmd 'zetta-embark-back-cycle)
          (progn (setq prefix-arg -1) 'embark-cycle)
        cmd)))

  ;; Reset `prefix-arg' after each cycle rotation so direction is
  ;; per-press rather than sticky. Without this, pressing C-, once
  ;; would leave `prefix-arg' at -1 for the rest of the cycle session,
  ;; so subsequent C-. presses would also go backward.
  (define-advice embark--rotate (:after (&rest _) zetta-reset-prefix-arg)
    "Reset `prefix-arg' after rotation -- one-shot prefix semantics
inside the embark-act cycle loop."
    (setq prefix-arg nil))

  (define-key embark-general-map (kbd "C-,") #'zetta-embark-back-cycle)

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
             ;; `ignore-errors' around the bounds lookup: some
             ;; user-defined providers call functions that signal
             ;; rather than return nil when there is no thing here.
             ;; For instance `brick-bounds-of-brick-at-point' calls
             ;; `end-of-thing 'paragraph' which errors in org-mode
             ;; on a heading or inside a property drawer. Treat any
             ;; signal as "no target" so embark-act doesn't crash.
             (when-let* ((bnds (ignore-errors
                                 (bounds-of-thing-at-point ',thing-sym)))
                         ;; Clamp to buffer boundaries: some user-defined
                         ;; bounds functions (e.g. `brick' here) compute
                         ;; (+ 1 point-max), which would later crash
                         ;; `buffer-substring-no-properties'.
                         (beg (max (point-min) (car bnds)))
                         (end (min (point-max) (cdr bnds)))
                         ((< beg end)))
               ;; Embark's bounded-target shape is the dotted list
               ;; (TYPE TARGET START . END) -- NOT (TYPE TARGET START END).
               (cons ',type-sym
                     (cons (buffer-substring-no-properties beg end)
                           (cons beg end))))))
         (add-to-list 'embark-target-finders #',name))))

  ;; Register a finder for the user-defined `brick' thing from
  ;; `tap.el' (blank-line-delimited paragraph; uses `put ...
  ;; bounds-of-thing-at-point'). Embark's built-in finders don't
  ;; surface custom things via the symbol-property mechanism.
  (zetta-embark-deftap-finder brick)

  ;; Register text-shaped scopes too. Embark's built-in `sentence',
  ;; `paragraph', and `defun' finders are hardcoded to text / help /
  ;; Info / man modes, so they never fire in eww-mode, org-mode,
  ;; prog-mode, etc. Our deftap-finder has no such restriction, and
  ;; the size-sort + ignore-errors + clamp make it safe to register
  ;; globally. In modes where the things are also surfaced by a
  ;; built-in finder, dedupe in `embark--targets' collapses the
  ;; overlap to a single target.
  (zetta-embark-deftap-finder line)
  (zetta-embark-deftap-finder sentence)
  (zetta-embark-deftap-finder paragraph)

  ;; `orgtree' is defined in `modules/org/org.el' as a thing whose
  ;; `forward-op' calls `org-next-visible-heading'. Registering it
  ;; as an embark target lets `C-.' / `*' / `C-j' / `C-k' work on
  ;; whole subtrees in org buffers. Bounds default to the
  ;; `forward-op'-derived span (heading + body until the next
  ;; heading at the same or higher level).
  (zetta-embark-deftap-finder orgtree)

  ;; Extend `embark-org--types' with element types that the upstream
  ;; embark-org explicitly leaves out (see comments at
  ;; embark-org.el:42). Each becomes an `org-<type>' target via
  ;; `embark-org-target-element-context'. Bind a keymap in
  ;; `embark-keymap-alist' if you want type-specific actions; the
  ;; default falls back to `embark-general-map'.
  (with-eval-after-load 'embark-org
    (dolist (type '(drawer property-drawer quote-block example-block
                    comment-block verse-block keyword planning
                    latex-environment latex-fragment))
      (cl-pushnew type embark-org--types)))

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
    "Embark target finder: every recognised tree-sitter ancestor at point.
Walks up from `treesit-node-at' and returns one bounded target per
ancestor whose type is in `zetta-embark-treesit-types', innermost
first. Returning all ancestors (not just the innermost) lets
`embark-act' cycle through structural scopes the way
`er/expand-region' does, with the size sort on `embark--targets'
arranging them smallest -> largest."
    (when (and (fboundp 'treesit-parser-list) (treesit-parser-list))
      (let ((node (treesit-node-at (point)))
            targets)
        (while node
          (when (member (treesit-node-type node)
                        zetta-embark-treesit-types)
            (let ((start (treesit-node-start node))
                  (end (treesit-node-end node)))
              (push (cons (intern (concat "ts-" (treesit-node-type node)))
                          (cons (buffer-substring-no-properties start end)
                                (cons start end)))
                    targets)))
          (setq node (treesit-node-parent node)))
        (nreverse targets))))
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
    "Return list of (BEG . END) for every bounded target embark sees.
Walks `embark-target-finders'. Bridge C now returns every recognised
AST ancestor as a separate target, so structural scopes are already
covered without an explicit treesit walk here."
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

  ;; Make `embark-act' cycling follow expand-region's innermost-outward
  ;; order: smallest-bounds target is the default; repeated `embark-act'
  ;; walks to the next-larger scope. Targets without bounds (minibuffer
  ;; candidates etc.) keep their relative order at the end of the list.
  (defcustom zetta-embark-sort-targets-by-bounds t
    "When non-nil, sort embark's target cycle by bounds size (ascending).
Repeated `embark-act' then walks innermost -> outermost the way
`er/expand-region' does. Disable to restore embark's finder-order
default."
    :type 'boolean
    :group 'embark)

  (defvar zetta-embark--sort-targets-reverse nil
    "Dynamically bound: when non-nil, sort embark targets largest-first.
Set by `zetta-embark-act-contract' to flip the cycle direction.")

  (defun zetta-embark--sort-targets-by-bounds (targets)
    "Sort embark TARGETS list by bounds size.
Smallest first by default (expand-region forward order). When
`zetta-embark--sort-targets-reverse' is non-nil, largest first
(contract order). Plists without `:bounds' keep their relative
order at the end."
    (if (not zetta-embark-sort-targets-by-bounds)
        targets
      (let* ((bounded   (cl-remove-if-not
                         (lambda (tgt) (plist-get tgt :bounds)) targets))
             (unbounded (cl-remove-if
                         (lambda (tgt) (plist-get tgt :bounds)) targets))
             (sorted (sort bounded
                           (lambda (a b)
                             (let* ((ba (plist-get a :bounds))
                                    (bb (plist-get b :bounds))
                                    (sa (- (cdr ba) (car ba)))
                                    (sb (- (cdr bb) (car bb))))
                               (< sa sb))))))
        (append (if zetta-embark--sort-targets-reverse
                    (reverse sorted)
                  sorted)
                unbounded))))

  (advice-add 'embark--targets :filter-return
              #'zetta-embark--sort-targets-by-bounds)

  (defun zetta-embark-act-contract ()
    "Like `embark-act' but cycle through targets largest -> smallest.
Mirrors `er/contract-region' the way `embark-act' mirrors
`er/expand-region': the default action is the outermost scope, and
repeated `embark-cycle' walks inward. Use this when you want to act
on an enclosing scope without cycling past it via `embark-act'.

To step backward from within the standard `embark-act' prompter
(forward order), prefix the cycle key with `C-u -1' -- the
universal-argument family is already handled there."
    (interactive)
    (let ((zetta-embark--sort-targets-reverse t))
      (call-interactively #'embark-act)))

  ;; Bridge E: per-target-type navigation inside embark prompts.
  ;; C-j / C-k bound in `embark-general-map' move to the next /
  ;; previous instance of whatever type the current target has --
  ;; e.g. on a `ts-call' target, C-j jumps to the next call; on a
  ;; `defun', C-j jumps to the next defun.
  (defcustom zetta-embark-nav-type-map
    '((general . word)
      (identifier . symbol)
      (expression . sexp)
      (defun . defun)
      (paragraph . paragraph)
      (sentence . sentence)
      (ts-string . str-lit)
      (ts-string_literal . str-lit)
      (ts-call . call)
      (ts-call_expression . call)
      (ts-function_definition . function)
      (ts-function_declaration . function)
      (ts-method_definition . method)
      (ts-method_declaration . method)
      (ts-class_definition . class)
      (ts-class_declaration . class)
      (ts-argument_list . argument_list)
      (ts-parameter_list . parameter_list)
      (ts-for_statement . loop)
      (ts-while_statement . loop)
      (ts-if_statement . conditional)
      (ts-decorator . decorator)
      (brick . brick))
    "Map embark target types to thing-at-point things for navigation.
Missing entries fall through to the type itself, in case the type
*is* already a thing. Navigation no-ops if the resolved thing has
neither a `forward-op' property nor a treesit definition for the
buffer's language."
    :type '(alist :key-type symbol :value-type symbol)
    :group 'embark)

  (defvar zetta-embark--current-target-type nil
    "Type of the most recent embark target. Set by the :always
pre-action hook; read by `zetta-embark-nav-next' / `nav-prev'.")

  (defvar zetta-embark--current-target-bounds nil
    "Bounds of the most recent embark target, or nil if unbounded.")

  (defun zetta-embark--capture-target (&rest plist)
    "Pre-action hook: capture target type and bounds for nav commands."
    (setq zetta-embark--current-target-type (plist-get plist :type)
          zetta-embark--current-target-bounds (plist-get plist :bounds)))

  (setf (alist-get :always embark-pre-action-hooks)
        (cons #'zetta-embark--capture-target
              (alist-get :always embark-pre-action-hooks)))

  (defun zetta-embark--nav (n)
    "Move N instances forward (negative = back) of current target's type."
    (let* ((type zetta-embark--current-target-type)
           (bounds zetta-embark--current-target-bounds)
           (thing (alist-get type zetta-embark-nav-type-map type)))
      (cond
       ((null type)
        (message "No embark target captured yet"))
       ((null bounds)
        (message "Embark type `%s' has no bounds; nav not applicable" type))
       ((not (symbolp thing))
        (message "No nav thing mapped for embark type `%s'" type))
       (t
        (let ((zetta-tap-current-thing thing))
          (zetta-tap-forward-thing n))))))

  (defun zetta-embark-nav-next ()
    "Move to next instance of current embark target's type."
    (interactive)
    (zetta-embark--nav 1))

  (defun zetta-embark-nav-prev ()
    "Move to previous instance of current embark target's type."
    (interactive)
    (zetta-embark--nav -1))

  (defun zetta-embark-nav-beg ()
    "Move point to the start of the current embark target's bounds."
    (interactive)
    (if zetta-embark--current-target-bounds
        (goto-char (car zetta-embark--current-target-bounds))
      (message "No embark target bounds captured")))

  (defun zetta-embark-nav-end ()
    "Move point to the end of the current embark target's bounds.
Lands at the last position INSIDE the bounds (one before
`(cdr bounds)') so embark's repeat re-prompts on the same target,
not the thing that starts at the boundary. Concretely matters for
`line': bounds end is the start of the *next* line, so landing
there would re-target the next line instead of staying on the
current one."
    (interactive)
    (if zetta-embark--current-target-bounds
        (let ((beg (car zetta-embark--current-target-bounds))
              (end (cdr zetta-embark--current-target-bounds)))
          (goto-char (max beg (1- end))))
      (message "No embark target bounds captured")))

  ;; `embark-expression' thing: thing-at-point lookup whose bounds
  ;; come from embark's smart `embark-target-expression-at-point'
  ;; logic (syntax-ppss + scan-sexps; walks back to the enclosing
  ;; opening delim). Plain `bounds-of-thing-at-point 'sexp' SHRINKS
  ;; into sub-sexps as point moves within the expression -- using
  ;; the smart finder keeps the bounds stable on the enclosing form.
  ;; `zetta-embark-nav-type-map' maps the `expression' embark target
  ;; type to this thing so focus-mode tracks expressions properly.
  (defun zetta-embark--expression-bounds ()
    "Bounds of the smart expression at point per embark's finder."
    (when-let* ((result (ignore-errors
                          (embark-target-expression-at-point)))
                ((consp result))
                (start (and (numberp (caddr result)) (caddr result)))
                (end (and (numberp (cdddr result)) (cdddr result))))
      (cons start end)))

  (put 'embark-expression 'bounds-of-thing-at-point
       'zetta-embark--expression-bounds)

  ;; `embark-expression' has bounds but intentionally NO `forward-op'.
  ;; Use it only as a *focus* thing -- its smart bounds give stable
  ;; "enclosing form" dimming as point moves around inside. For
  ;; *navigation*, `zetta-embark-focus-on-type' sets
  ;; `zetta-tap-current-thing' to plain `sexp' (via the nav-type-map),
  ;; whose `forward-sexp' navigation is well-behaved.

  (defun zetta-embark-focus-on-type ()
    "Activate `focus-mode' on the current embark target's type.
Resolves the embark type via `zetta-embark-nav-type-map' to a
thing-at-point thing (e.g. expression -> `embark-expression',
ts-call -> call), syncs `zetta-tap-current-thing' and
`focus-current-thing', snaps point to the captured bounds' start,
and enables `focus-mode'. Focus tracks point dynamically from
there -- when you move into a different instance of the same type,
focus follows."
    (interactive)
    (let* ((type zetta-embark--current-target-type)
           (bounds zetta-embark--current-target-bounds)
           (thing (alist-get type zetta-embark-nav-type-map type)))
      (cond
       ((null type)
        (message "No embark target captured"))
       ((not (symbolp thing))
        (message "No nav thing for embark type `%s'" type))
       (t
        (setq-local zetta-tap-current-thing thing)
        (when (boundp 'focus-current-thing)
          ;; For `expression' targets, focus uses `embark-expression'
          ;; (smart enclosing-form bounds) even though nav uses plain
          ;; `sexp'. This keeps focus stable as point moves inside an
          ;; expression while letting nav rely on `forward-sexp'.
          (setq-local focus-current-thing
                      (if (eq type 'expression) 'embark-expression thing)))
        (when bounds (goto-char (car bounds)))
        (when (fboundp 'focus-mode) (focus-mode 1))
        (message "Focus on `%s'%s"
                 thing
                 (if (eq type thing) ""
                   (format " (via embark `%s')" type)))))))

  (defun zetta-embark-set-current-thing ()
    "Set `zetta-tap-current-thing' to the active embark target's type.
Resolves the type via `zetta-embark-nav-type-map' (same mapping the
nav and focus actions use), syncs `focus-current-thing' too so
focus-mode tracks the new thing if active. Lets you `C-.' on a
sentence / call / paragraph / function and then drive s-j / s-k by
that thing without going through M-x zetta-tap-set-local."
    (interactive)
    (let* ((type zetta-embark--current-target-type)
           (thing (alist-get type zetta-embark-nav-type-map type)))
      (cond
       ((null type)
        (message "No embark target captured"))
       ((not (symbolp thing))
        (message "No nav thing for embark type `%s'" type))
       (t
        (setq-local zetta-tap-current-thing thing)
        (when (boundp 'focus-current-thing)
          (setq-local focus-current-thing thing))
        (message "zetta-tap-current-thing = `%s'%s"
                 thing
                 (if (eq type thing) ""
                   (format " (via embark `%s')" type)))))))

  ;; Highlight all OTHER instances of the active target's type in the
  ;; buffer. Toggles a buffer-local flag so subsequent embark-act
  ;; cycles auto-refresh against the new type (via the :always
  ;; pre-action hook below).
  (defface zetta-embark-other-instance-face
    '((((background dark))  :background "#3a2a00" :extend nil)
      (((background light)) :background "#fff3b0" :extend nil))
    "Face for other instances of the current embark target's type."
    :group 'embark)

  (defvar-local zetta-embark--instance-overlays nil
    "Overlays painted by `zetta-embark-highlight-other-instances'.")

  (defvar-local zetta-embark--highlights-enabled nil
    "When non-nil, refresh highlights on every embark action.")

  (defun zetta-embark--clear-instance-overlays ()
    (mapc #'delete-overlay zetta-embark--instance-overlays)
    (setq zetta-embark--instance-overlays nil))

  (defun zetta-embark--collect-instances-of-thing (thing)
    "Walk buffer and return all (BEG . END) bounds of THING."
    (let (bounds-list)
      (save-excursion
        (goto-char (point-min))
        (let ((last-end -1)
              (last-point -1))
          (while (and (< (point) (point-max))
                      (/= (point) last-point))
            (setq last-point (point))
            (when-let* ((b (ignore-errors
                             (bounds-of-thing-at-point thing))))
              (when (and (>= (car b) last-end)
                         (> (cdr b) (car b))) ; non-empty
                (push b bounds-list)
                (setq last-end (cdr b))))
            (ignore-errors (forward-thing thing 1)))))
      (nreverse bounds-list)))

  (defun zetta-embark-highlight-other-instances ()
    "Highlight all OTHER instances of the active embark target's type.
Toggles `zetta-embark--highlights-enabled' so the :always
pre-action hook re-runs this after each cycle, keeping highlights
in sync with the currently active target type. Press again with
no captured target (or invoke `zetta-embark-clear-highlights') to
turn off."
    (interactive)
    (zetta-embark--clear-instance-overlays)
    (let* ((type zetta-embark--current-target-type)
           (cur-bounds zetta-embark--current-target-bounds)
           (thing (alist-get type zetta-embark-nav-type-map type)))
      (cond
       ((null type)
        (setq zetta-embark--highlights-enabled nil)
        (message "Highlights cleared"))
       ((not (symbolp thing))
        (message "No nav thing for embark type `%s'" type))
       (t
        (setq zetta-embark--highlights-enabled t)
        (let ((instances (zetta-embark--collect-instances-of-thing thing)))
          (dolist (b instances)
            ;; Skip overlay if it overlaps the current embark target.
            ;; The walker's bounds may differ by 1 char from the
            ;; captured ones (trailing whitespace etc.), so use
            ;; "overlap" rather than "exact match".
            (unless (and cur-bounds
                         (< (car b) (cdr cur-bounds))
                         (> (cdr b) (car cur-bounds)))
              (let ((ov (make-overlay (car b) (cdr b))))
                (overlay-put ov 'face 'zetta-embark-other-instance-face)
                (overlay-put ov 'zetta-embark-highlight t)
                (push ov zetta-embark--instance-overlays))))
          (message "Highlighted %d other `%s' instance(s)"
                   (length zetta-embark--instance-overlays) thing))))))

  (defun zetta-embark-clear-highlights ()
    "Turn off `zetta-embark-highlight-other-instances'."
    (interactive)
    (setq zetta-embark--highlights-enabled nil)
    (zetta-embark--clear-instance-overlays)
    (message "Embark highlights cleared"))

  (defun zetta-embark--refresh-highlights-hook (&rest _plist)
    "Pre-action hook: refresh highlights when the active target type
changes. Runs only when `zetta-embark--highlights-enabled' is non-nil."
    (when zetta-embark--highlights-enabled
      (zetta-embark-highlight-other-instances)))

  ;; Add to :always AFTER the capture hook so we see the new type
  ;; on each cycle.
  (setf (alist-get :always embark-pre-action-hooks)
        (append (alist-get :always embark-pre-action-hooks)
                (list #'zetta-embark--refresh-highlights-hook)))

  ;; Refresh highlights when the user cycles (C-. / C-,). embark
  ;; handles `embark-cycle' inline in its act loop -- it does NOT
  ;; route through `embark--act', so pre/post-action hooks never
  ;; fire on a cycle. Instead, attach to `embark--rotate' (the
  ;; function the cycle dispatches to): when it runs, the new head
  ;; of the rotated targets list IS the new current target -- copy
  ;; its :type / :bounds into the captured vars and re-paint.
  (define-advice embark--rotate
      (:filter-return (rotated-targets) zetta-refresh-highlights)
    (when (and zetta-embark--highlights-enabled rotated-targets)
      (when-let* ((new-head (car rotated-targets)))
        (setq zetta-embark--current-target-type
              (plist-get new-head :type)
              zetta-embark--current-target-bounds
              (plist-get new-head :bounds))
        (zetta-embark-highlight-other-instances)))
    rotated-targets)

  ;; Clear highlights when `embark-act' exits its prompt. Doing this
  ;; via `:around' on `embark-act' itself catches every exit path --
  ;; the user picking any action (repeatable or not), C-g cancellation,
  ;; or completion. Post-action hooks are unreliable here because many
  ;; built-in actions (forward-sentence, transpose-paragraphs, etc.)
  ;; are themselves in `embark-repeat-actions'.
  (define-advice embark-act
      (:around (orig &rest args) zetta-clear-highlights-on-exit)
    (unwind-protect (apply orig args)
      (when zetta-embark--highlights-enabled
        (zetta-embark--clear-instance-overlays)
        (setq zetta-embark--highlights-enabled nil))))

  (define-key embark-general-map (kbd "C-j") #'zetta-embark-nav-next)
  (define-key embark-general-map (kbd "C-k") #'zetta-embark-nav-prev)
  (define-key embark-general-map (kbd "C-a") #'zetta-embark-nav-beg)
  (define-key embark-general-map (kbd "C-e") #'zetta-embark-nav-end)
  (define-key embark-general-map (kbd "C-t") #'zetta-embark-set-current-thing)
  (define-key embark-general-map (kbd "*")   #'zetta-embark-highlight-other-instances)

  (defun zetta-embark-select-as-region ()
    "Activate region over the current embark target's bounds.
Mark goes at end, point at start, and the region is made active.
Embark exits after (not added to `embark-repeat-actions') so the
selection is immediately usable for any region-based command."
    (interactive)
    (if-let* ((bounds zetta-embark--current-target-bounds))
        (let ((beg (car bounds))
              (end (cdr bounds)))
          (push-mark end nil t)
          (goto-char beg)
          (activate-mark))
      (message "No embark target bounds captured")))

  (define-key embark-general-map (kbd "C-v") #'zetta-embark-select-as-region)

  (defun zetta-embark-pick-target-type ()
    "Pick a target type from the ones at point, then re-enter embark.
Skips the cycling step when many types are stacked at the same
point: shows a `completing-read' with every bounded target,
filters embark-target-finders to just the picked one, then calls
`embark-act' which dispatches directly to that type's action map."
    (interactive)
    (let* ((targets (embark--targets))
           (candidates
            (cl-loop for tgt in targets
                     when (plist-get tgt :bounds)
                     collect
                     (cons
                      (format "%-30s %s"
                              (plist-get tgt :type)
                              (truncate-string-to-width
                               (or (plist-get tgt :target) "") 60 nil nil "…"))
                      tgt))))
      (if (null candidates)
          (message "No bounded targets at point")
        (let* ((choice (completing-read "Pick target type: "
                                        (mapcar #'car candidates) nil t))
               (picked (cdr (assoc choice candidates))))
          (when picked
            (let* ((sym (plist-get picked :type))
                   (text (plist-get picked :target))
                   (b (plist-get picked :bounds))
                   (beg (car b))
                   (end (cdr b))
                   (embark-target-finders
                    (list (lambda ()
                            (cons sym (cons text (cons beg end)))))))
              (call-interactively #'embark-act)))))))

  (define-key embark-general-map (kbd "C-l") #'zetta-embark-pick-target-type)

  (defun zetta-embark-pick-instance ()
    "List every instance of the active target's type; pick one and act.
Inside an embark prompt, opens a `consult--read' over every
instance of the current target's resolved nav-thing in the
buffer (formatted as `L<line>: <snippet>'). Preview jumps point
to each instance as you navigate. On commit, jumps to the picked
instance and re-enters `embark-act' filtered to that target. On
cancel (C-g), restores point."
    (interactive)
    (let* ((type zetta-embark--current-target-type)
           (thing (and type (alist-get type zetta-embark-nav-type-map type))))
      (cond
       ((null type) (message "No embark target captured"))
       ((not (symbolp thing))
        (message "No nav thing for embark type `%s'" type))
       (t
        (let* ((start (point))
               (cancelled t)
               (instances (zetta-embark--collect-instances-of-thing thing))
               (candidates
                (mapcar
                 (lambda (b)
                   (let* ((line (line-number-at-pos (car b)))
                          (snippet (replace-regexp-in-string
                                    "\n+" " "
                                    (buffer-substring-no-properties
                                     (car b)
                                     (min (cdr b) (+ (car b) 80)))))
                          (snippet (truncate-string-to-width
                                    snippet 80 nil nil "…")))
                     (cons (format "L%-5d %s" line snippet) b)))
                 instances))
               (preview-state
                (lambda (action cand)
                  (pcase action
                    ('preview
                     (when (and cand (stringp cand))
                       (when-let* ((b (cdr (assoc cand candidates))))
                         (goto-char (car b))))))))) ; close lambda, pcase, let* binding
          (cond
           ((null candidates)
            (message "No instances of type `%s' (thing `%s') in buffer"
                     type thing))
           (t
            (unwind-protect
                (let* ((choice
                        ;; embark's pre-action `inject' prefills our
                        ;; minibuffer with the target string, which
                        ;; hides candidates. Add a one-shot hook that
                        ;; clears the minibuffer right after embark's
                        ;; inject runs.
                        (minibuffer-with-setup-hook
                            (lambda () (delete-minibuffer-contents))
                          (consult--read (mapcar #'car candidates)
                                         :prompt (format "Pick %s: " type)
                                         :require-match t
                                         :state preview-state)))
                       (picked (cdr (assoc choice candidates))))
                  (when picked
                    (let* ((beg (car picked))
                           (end (cdr picked))
                           (text (buffer-substring-no-properties beg end))
                           (embark-target-finders
                            (list (lambda ()
                                    (cons type (cons text (cons beg end)))))))
                      (goto-char beg)
                      (setq cancelled nil)
                      (call-interactively #'embark-act))))
              (when cancelled (goto-char start))))))))))

  (define-key embark-general-map (kbd "C-o") #'zetta-embark-pick-instance)

  ;; Top-level command (not an embark action): prompt for a type,
  ;; jump to the closest instance, kick off `embark-act' there.
  ;; Uses `consult--read' so we get live preview: highlighting every
  ;; instance of the previewed type and moving point to the closest
  ;; one. On C-g (cancel) the original point is restored and the
  ;; preview overlays are torn down.
  (defun zetta-embark--jump-to-type-closest (instances anchor)
    "Return the (BEG . END) in INSTANCES nearest to ANCHOR position."
    (car (sort (copy-sequence instances)
               (lambda (a b)
                 (< (abs (- (car a) anchor))
                    (abs (- (car b) anchor)))))))

  (defun zetta-embark--jump-to-type-paint (instances)
    "Paint INSTANCES with `zetta-embark-other-instance-face' overlays.
Reuses `zetta-embark--instance-overlays' so the existing clear path
applies."
    (dolist (b instances)
      (let ((ov (make-overlay (car b) (cdr b))))
        (overlay-put ov 'face 'zetta-embark-other-instance-face)
        (overlay-put ov 'zetta-embark-highlight t)
        (push ov zetta-embark--instance-overlays))))

  (defun zetta-embark--jump-type-applicable-p (sym)
    "Return non-nil if SYM is plausibly relevant in the current buffer.
Filters obvious mismatches by name prefix: `org-*' types and
`orgtree' only in `org-mode'; `ts-*' types only when a tree-sitter
parser is active. Falls through to t for generic things."
    (let ((name (symbol-name sym)))
      (cond
       ((or (string-prefix-p "org-" name)
            (eq sym 'orgtree))
        (derived-mode-p 'org-mode))
       ((string-prefix-p "ts-" name)
        (and (fboundp 'treesit-parser-list) (treesit-parser-list)))
       (t t))))

  (defun zetta-embark-jump-to-type ()
    "Prompt for a type with `consult--read'; preview highlights every
instance of the type and moves point to the closest. On commit,
jumps and runs `embark-act' filtered to that type. On cancel
(C-g), restores point and clears preview overlays."
    (interactive)
    (let* ((start (point))
           (cancelled t)
           (candidates
            (delete-dups
             (mapcar #'symbol-name
                     (cl-remove-if-not
                      #'zetta-embark--jump-type-applicable-p
                      (delq nil
                            (append
                             (mapcar #'car zetta-embark-nav-type-map)
                             (mapcar #'cdr zetta-embark-nav-type-map)
                             (when (boundp 'zetta-tap--things)
                               (mapcar (lambda (s)
                                         (and s (intern-soft s)))
                                       zetta-tap--things))))))))
           (preview-state
            (lambda (action cand)
              (pcase action
                ('preview
                 (zetta-embark--clear-instance-overlays)
                 (when (and cand (stringp cand) (> (length cand) 0))
                   (let* ((sym (intern cand))
                          (thing (alist-get sym zetta-embark-nav-type-map sym))
                          (instances (ignore-errors
                                       (zetta-embark--collect-instances-of-thing thing))))
                     (when instances
                       (zetta-embark--jump-to-type-paint instances)
                       (when-let* ((closest (zetta-embark--jump-to-type-closest
                                             instances start)))
                         (goto-char (car closest)))))))
                ('exit
                 (zetta-embark--clear-instance-overlays))))))
      (unwind-protect
          (let* ((choice (consult--read candidates
                                        :prompt "Jump to type: "
                                        :require-match t
                                        :state preview-state))
                 (sym (intern choice))
                 (thing (alist-get sym zetta-embark-nav-type-map sym))
                 (instances (zetta-embark--collect-instances-of-thing thing)))
            (cond
             ((null instances)
              (message "No instances of `%s' in buffer" thing))
             (t
              (let* ((closest (zetta-embark--jump-to-type-closest instances start))
                     (beg (car closest))
                     (end (cdr closest))
                     (text (buffer-substring-no-properties beg end))
                     (embark-target-finders
                      (list (lambda ()
                              (cons sym (cons text (cons beg end)))))))
                (goto-char beg)
                (setq cancelled nil)
                (call-interactively #'embark-act)))))
        (when cancelled (goto-char start)))))
  ;; `C-f' for focus-mode activation:
  ;; - `F' is bound in five embark built-in maps
  ;;   (prose / sentence / paragraph / region / file / encode),
  ;;   shadowing any `embark-general-map' fallback.
  ;; - `M-f' (alt-f) collides with aerospace's fullscreen on macOS.
  ;; - `C-f' is unbound in every embark built-in map AND aerospace
  ;;   only takes alt-/cmd- combos, so it is free at both layers.
  ;; Mnemonic: ctrl-Focus.
  (define-key embark-general-map (kbd "C-f") #'zetta-embark-focus-on-type)

  ;; Mark the nav commands as repeatable so embark re-fetches targets
  ;; at the new point and re-prompts with the same type preferred.
  ;; Result: `C-.' once enters the prompt, then `C-j' / `C-k' step
  ;; through instances of that type and `C-a' / `C-e' jump to the
  ;; current target's start / end -- with the prompt continuing on
  ;; each new target. Pick an action key when you find the right one.
  (dolist (cmd '(zetta-embark-nav-next zetta-embark-nav-prev
                 zetta-embark-nav-beg zetta-embark-nav-end
                 zetta-embark-set-current-thing
                 zetta-embark-highlight-other-instances))
    (add-to-list 'embark-repeat-actions cmd))

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
