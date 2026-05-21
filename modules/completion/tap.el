;;; tap.el --- Configure tap -*- lexical-binding: t; -*-

;; All the things
(setq zetta-tap--things '("brick" "symbol" "list" "sexp"
                          "defun" "filename" "url"
                          "email" "uuid" "word"
                          "sentence" "whitespace" "line"
                          "page" "orgtree" "paragraph" "button"))

(defvar-local zetta-tap-current-thing 'defun
  "Buffer-local thing-at-point symbol used by zetta-tap navigation.
Set via `zetta-tap-set-local'. Consumed by s-j/s-k (next/prev),
s-h/s-l (start/end), `zetta-tap-pulse', `zetta-tap-select', `zetta-tap-comment',
and `zetta-narrow-or-widen'.")

(defun zetta-tap-forward-thing (n)
  "Move N things of `zetta-tap-current-thing' forward (negative for back).
Dispatches to `treesit-navigate-thing' when the thing is defined in
the buffer's `treesit-thing-settings', otherwise to `forward-thing'.
Lands at the start of the destination thing's bounds so subsequent
`bounds-of-thing-at-point' lookups (e.g. in `zetta-narrow-or-widen')
succeed. Does not move when there is no destination thing -- treesit
returns nil cleanly; legacy `forward-thing's limit-jump behaviour is
avoided by going through `treesit-navigate-thing' directly."
  (interactive "p")
  (let* ((thing zetta-tap-current-thing)
         (treesit-defined
          (and (fboundp 'treesit-parser-list)
               (treesit-parser-list)
               (treesit-thing-defined-p
                thing (treesit-language-at (point))))))
    (if treesit-defined
        ;; SIDE 'beg with positive N lands at the START of the next
        ;; instance directly; with negative N, at the START of the
        ;; previous. This is the right thing for both nested things
        ;; (where 'end returned the end of the *current* not the next)
        ;; and top-level things (where 'end+snap happened to work).
        (when-let* ((dest (treesit-navigate-thing (point) n 'beg thing)))
          (goto-char dest))
      ;; Legacy forward-thing path.
      (let ((start-pos (point)))
        ;; Step 1: try `forward-thing'. `ignore-errors' swallows
        ;; `scan-error' at buffer boundaries / inside partial forms.
        (ignore-errors (forward-thing thing n))
        ;; Step 2: ESCAPE -- if step 1 didn't move (forward-sexp
        ;; errored from inside a closing-paren position, say), jump
        ;; past the current enclosing bounds in the requested
        ;; direction so the next nav has somewhere to go.
        (when (= (point) start-pos)
          (when-let* ((bnds (bounds-of-thing-at-point thing)))
            (goto-char (if (> n 0)
                           (min (point-max) (1+ (cdr bnds)))
                         (max (point-min) (1- (car bnds)))))))
        ;; Step 3: skip inter-thing gap so we land inside the
        ;; destination thing rather than on it.
        ;;
        ;; For `line': skip blank lines in the direction of motion --
        ;; symmetric, and stops at the previous/next content line
        ;; without over-crossing into the line beyond. Plain
        ;; `skip-chars-backward " \t\n"' would walk past the entire
        ;; previous content line's leading whitespace too.
        ;;
        ;; For everything else: skip whitespace forward (matches the
        ;; original behaviour). Backward is not skipped because
        ;; `forward-thing' typically lands at the start of the
        ;; destination already.
        (cond
         ((eq thing 'line)
          (let ((step (if (> n 0) 1 -1)))
            (while (and (save-excursion
                          (beginning-of-line)
                          (looking-at-p "^[ \t]*$"))
                        (if (> n 0)
                            (< (point) (point-max))
                          (> (point) (point-min))))
              (forward-line step))))
         ((> n 0)
          (skip-chars-forward " \t\n")))
        ;; Step 4: snap to bounds.start of the thing at the new
        ;; point. Anti-loop: only snap if it actually progresses in
        ;; the requested direction -- otherwise an *enclosing* form's
        ;; bounds (common for sexp / sentence / etc.) would pull
        ;; point backward and the next call would re-enter the same
        ;; form forever.
        (when-let* ((bnds (bounds-of-thing-at-point thing))
                    (snap-pos (car bnds)))
          (when (or (and (> n 0) (> snap-pos start-pos))
                    (and (< n 0) (< snap-pos start-pos)))
            (goto-char snap-pos)))))))

(defun zetta-intern-maybe (thing)
  (if (symbolp thing) thing (intern thing)))

(defun zetta-tap-set-local (&optional thing)
  "Set the local current thing-at-point thing for zetta-tap navigation.
Also mirrors to `focus-current-thing' so `focus-mode' (when active)
dims around the same thing. THING may be a symbol or a string;
interactively, prompts from `zetta-tap--things'."
  (interactive)
  (let ((sym (zetta-intern-maybe
              (or thing (completing-read "What thing? " zetta-tap--things)))))
    (setq-local zetta-tap-current-thing sym)
    (when (boundp 'focus-current-thing)
      (setq-local focus-current-thing sym))))

(defun zetta-locate-thing (&optional thing)
  (interactive)
  (let* ((bnds (bounds-of-thing-at-point
                (zetta-intern-maybe (or thing zetta-tap-current-thing))))
         (beg (if (string= thing "buf") (point-min) (car bnds)))
         (end (if (string= thing "buf") (point-max) (- (cdr bnds) 1))))
    (cons beg `(,end))))

(defun zetta-locate-thing-beg (&optional thing)
  (interactive)
  (let ((bnds (zetta-locate-thing thing))) (car bnds)))

(defun zetta-locate-thing-end (&optional thing)
  (interactive)
  (let ((bnds (zetta-locate-thing thing))) (cadr bnds)))

(defun zetta-get-thing (&optional thing)
  (interactive)
  (if (use-region-p)
      (buffer-substring-no-properties (region-beginning) (region-end))
    (buffer-substring-no-properties (zetta-locate-thing-beg thing) (zetta-locate-thing-end thing))))

(defun zetta-tap-pulse (&optional thing)
  (interactive)
  ;; available things: generic + mode
  (let* ((bnds (zetta-locate-thing thing)))
    (pulse-momentary-highlight-region
     (car bnds) (cadr bnds)
     '(:background "black" :foreground "gray"))))

(defun zetta-tap-select (&optional thing)
  (interactive)
  (let ((bnds (zetta-locate-thing thing)))
    (set-mark (car bnds))
    (goto-char (cadr bnds))))

(defun zetta-tap-comment (&optional thing)
  (interactive)
  (save-excursion
    (zetta-tap-select)
    (call-interactively 'comment-or-uncomment-region)
    )
  )

(defun zetta-tap-next ()
  (interactive)
  (if (buffer-narrowed-p)
      (progn (call-interactively 'zetta-narrow-or-widen)
             (zetta-tap-forward-thing 1)
             (call-interactively 'zetta-narrow-or-widen))
    (zetta-tap-forward-thing 1)))

(defun zetta-tap-prev ()
  (interactive)
  (if (buffer-narrowed-p)
      (progn (call-interactively 'zetta-narrow-or-widen)
             (zetta-tap-forward-thing -1)
             (call-interactively 'zetta-narrow-or-widen))
    (zetta-tap-forward-thing -1)))


(defun zetta-tap-beg ()
  (interactive)
  (beginning-of-thing zetta-tap-current-thing))

(defun zetta-tap-end ()
  (interactive)
  (end-of-thing zetta-tap-current-thing)
  ;; to take care of skipping whitespace, not sure why this
  ;; happens
  (re-search-backward "[^[:space:]\n]")
  (evil-end-of-line)
  )

(general-define-key
 :keymaps '(
            sql-mode-map lisp-mode-map lisp-interaction-mode-map
            emacs-lisp-mode-map elisp python-ts-mode-map
            yaml-mode-map sh-mode-map shell-command-mode-map
            lark-mode-map org-mode-map)
 "s-j" 'zetta-tap-next
 "s-k" 'zetta-tap-prev
 "s-h" 'zetta-tap-beg
 "s-l" 'zetta-tap-end
 "s-x v" 'zetta-tap-pulse
 "s-x V" 'zetta-tap-select
 "s-x t" 'zetta-tap-set-local
 "s-x j" 'zetta-embark-jump-to-type
 "s-x a" 'zetta-embark-avy-jump-to-type
 "s-/" 'zetta-tap-comment
 )

(use-package expand-region
  :general
  (
   :states '(normal visual)
   :keymaps '(
              ;; Explicit mode list; some overlap with prog-mode but needed for non-prog modes
              org-mode-map org-agenda-mode-map sql-mode-map
              python-ts-mode-map lisp-interaction-mode-map
              emacs-lisp-mode-map lisp-mode-map dired-mode-map
              snippet-mode-map shell-command-mode-map vterm-mode-map
              embark-collect-mode-map wgrep-mode-map csv-mode-map
              help-mode-map helpful-mode-map text-mode-map
              pubmed-show-mode-map json-mode-map eww-mode-map
              jmespath-mode-map jsonian-mode-map js2-mode-map
              compilation-mode-map lark-mode-map css-mode-map
              fundamental-mode-map lisp-data-mode-map prog-mode-map
              )
   "C-e"   'zetta-embark-expand-region
   "C-M-e" 'er/expand-region
   "C-S-e" 'zetta-embark-contract-region))

(defun zetta-tap-at-bobp ()
  (interactive)
  (eq 1 (save-excursion
          (beginning-of-thing zetta-tap-current-thing)
          (point))))

(defun zetta-tap-at-eobp ()
  (interactive)
  (save-excursion
    (end-of-thing zetta-tap-current-thing)
    (eobp)))

;; Brick
(defun brick-next-brick ()
  (interactive)
  (let ((delim "^ *$"))
    (re-search-forward delim)
    (forward-to-word 1)
    (evil-first-non-blank)
    )
  )

(defun brick-backward-brick (&optional skip)
  (interactive)
  (let* (
         (delim "^ *$")
         (bol (move-beginning-of-line 1))
         (blank-line-pt (re-search-backward delim nil t))
         )
    (cond (
           ;; no blank line prior to point
           (not blank-line-pt)
           (progn
             (beginning-of-buffer)
             ;; need point here bc beginning of buffer returns nil
             (point)))
          ;; already at beginning of brick or in whitespace above brick
          ((and
            (or
             (= 1 (- bol blank-line-pt))
             (= 0 (- bol blank-line-pt)))
            skip
            )
           (progn
             (backward-to-word 1)
             (if (re-search-backward delim nil t)
                 (evil-forward-word-begin)
               (progn (beginning-of-buffer) (point))
               )
             )
           )
          (t (progn
               (re-search-backward delim nil t)
               (evil-forward-word-begin)
               ))
          )
    )
  )

(defun brick-forward-brick (&optional arg)
  (interactive "p")
  (setq arg (or arg 1))
  (while (and (> arg 0)
              (not (eobp))
              (brick-next-brick))
    (setq arg (1- arg)))
  (while (and (< arg 0)
              (not (bobp))
              (brick-backward-brick t))
    (setq arg (1+ arg)))
  )

(put 'brick 'forward-op 'brick-forward-brick)

(defun current-line-empty-p ()
  (interactive)
  (save-excursion
    (beginning-of-line)
    (looking-at-p "[[:space:]]*$")))

(defun brick-bounds-of-brick-at-point ()
  (interactive)
  (save-excursion
    (if (not (current-line-empty-p))
        (let* (
               (beg (if (not (bobp))
                        (progn
                          (brick-backward-brick) (point))
                      (point)))
               (end (if (not (eobp))
                        (progn (end-of-thing 'paragraph) (+ 1 (point)))
                      (point)))
               )
          (cons beg end)
          )
      nil
      ))
  )

(put 'brick 'bounds-of-thing-at-point 'brick-bounds-of-brick-at-point)

(defun zetta-contiguous-chars-at-point ()
  (save-excursion
    (let* ((beg (progn (evil-backward-WORD-begin) (point)))
           (end (1+ (progn (evil-forward-WORD-end) (point))))
           (str (buffer-substring beg end))
           )
      (buffer-substring beg end)
      )
    )
  )

;;;; Bridge A: treesit <-> thing-at-point
;; Teach the thing-at-point machinery to consult tree-sitter for both
;; bounds (`bounds-of-thing-at-point') and navigation (`forward-thing',
;; and by extension `beginning-of-thing' / `end-of-thing'). Downstream
;; consumers -- this file's navigation, embark target finders, lsp
;; helpers, expand-region, etc. -- then get AST-accurate behavior in
;; treesit-backed buffers with no further wiring.

(defun zetta-treesit-bounds (thing)
  "Return (BEG . END) of THING at point via tree-sitter, or nil.
Returns nil when the buffer has no treesit parser or when THING is
not defined in `treesit-thing-settings' for the current language."
  (when (and (fboundp 'treesit-parser-list)
             (treesit-parser-list)
             (treesit-thing-defined-p thing (treesit-language-at (point))))
    (when-let* ((node (treesit-thing-at-point thing 'nested)))
      (cons (treesit-node-start node) (treesit-node-end node)))))

(defcustom zetta-treesit-bridged-things
  '(defun sexp list sentence text comment paragraph
          function class method
          loop conditional decorator call
          parameter parameter_list argument_list
          str-lit statement)
  "Symbols bridged between thing-at-point and tree-sitter.
For each symbol: a bounds provider is registered globally; a forward
provider is registered buffer-locally (in treesit buffers) only when
the symbol is defined in the buffer's `treesit-thing-settings'.

Defaults cover python's stock settings (defun / sexp / list / sentence
/ text), plus common cross-language constructs that user queries or
language hooks can populate (function / class / method / loop /
conditional / decorator / call / parameter / argument_list / str-lit /
statement). Pushing to this list is free -- the symbol becomes
navigable only once some language's `treesit-thing-settings' defines
it. To extend per-language, augment `treesit-thing-settings' in that
mode's hook -- see `zetta-python-ts-extend-things' in
`modules/lang/treesit.el' for the pattern.

Note: thing symbols MUST NOT collide with the name of a built-in
function. `treesit-node-match-p' (a C function) tries to call a
symbol as a predicate before consulting `treesit-thing-settings',
so e.g. `string' as a thing symbol crashes -- hence `str-lit'."
  :type '(repeat symbol)
  :group 'zetta)

;; Bounds providers can be registered globally: `bounds-of-thing-at-point'
;; treats a nil-returning provider as a miss and falls through to other
;; providers / legacy mechanisms.
(when (fboundp 'treesit-thing-defined-p)
  (dolist (thing zetta-treesit-bridged-things)
    (setf (alist-get thing bounds-of-thing-at-point-provider-alist)
          (let ((th thing))
            (lambda () (zetta-treesit-bounds th))))))

;; Forward-thing providers are intentionally NOT registered.
;;
;; `forward-thing's contract is: "if any provider is registered for THING,
;; never fall back to legacy; if no provider moves point, jump to
;; (point-min) / (point-max) and terminate." A provider registered for a
;; defined thing that simply has no destination in the buffer (e.g.
;; `forward-thing 'function' in a buffer with no functions) sends point
;; flying to buffer-end. There is no provider-side workaround. So
;; navigation is funnelled through `zetta-tap-forward-thing' below, which
;; calls `treesit-navigate-thing' directly -- that returns nil cleanly
;; when no destination exists and we simply do not move.

;;; tap.el ends here
