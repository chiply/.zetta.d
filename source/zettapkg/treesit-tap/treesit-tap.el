;;; treesit-tap.el --- Tree-sitter bridge to thing-at-point + current-thing nav -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; URL: https://github.com/<TBD>/treesit-tap
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.1"))
;; Keywords: convenience, tools, languages

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Two related features for working with `thing-at-point' on top of
;; built-in tree-sitter (Emacs 30+):
;;
;; 1. **Bridge** -- a `bounds-of-thing-at-point' provider for any
;;    `treesit-thing-settings' entry.  Mode authors register thing
;;    predicates per language (function, class, call, loop, ...) and
;;    everything that calls `bounds-of-thing-at-point' transparently
;;    gets AST-accurate bounds in treesit buffers.  Per-language
;;    extension table `treesit-tap-language-extras' carries minimal
;;    defaults for python / typescript / tsx; downstream code extends.
;;
;; 2. **Current-thing nav** -- a per-buffer `treesit-tap-current-thing'
;;    variable and a family of commands (`treesit-tap-next' /
;;    `treesit-tap-prev' / `treesit-tap-beg' / `treesit-tap-end' /
;;    `treesit-tap-pulse' / `treesit-tap-select' / `treesit-tap-comment')
;;    that operate on that thing.  `treesit-tap-set-local' switches
;;    the current thing with an optional `consult--read' preview that
;;    highlights an instance of each candidate in the buffer.
;;
;; Standalone: no required deps beyond Emacs 30.1.  Transparently
;; integrates with `consult' (preview UI) and `focus.el' (mirrors
;; `treesit-tap-current-thing' to `focus-current-thing') when loaded.
;;
;; For embark integration (tree-sitter AST nodes as embark targets),
;; require the companion file `treesit-tap-embark'.
;;
;; Quick start:
;;
;;   (treesit-tap-setup)            ; installs bridge + language extras hook
;;   (require 'treesit-tap-embark)  ; optional: embark target finder
;;
;; Then in any treesit buffer:
;;
;;   M-x treesit-tap-set-local      ; pick current-thing (with preview)
;;   M-x treesit-tap-next           ; nav forward by current-thing
;;
;;; Code:

(require 'cl-lib)
(require 'thingatpt)
(require 'treesit)

;; Forward declaration for optional consult preview.
(declare-function consult--read "consult" (table &rest options))

(defgroup treesit-tap nil
  "Tree-sitter bridge to thing-at-point + current-thing nav."
  :group 'convenience
  :prefix "treesit-tap-")


;;;; Bridge: treesit -> thing-at-point bounds
;; ----------------------------------------------------------------

(defcustom treesit-tap-bridged-things
  '(defun sexp list sentence text comment paragraph
          function class method
          loop conditional decorator call
          parameter parameter_list argument_list
          str-lit statement)
  "Symbols bridged between thing-at-point and tree-sitter.

For each symbol a bounds provider is installed globally by
`treesit-tap-mode'; the symbol becomes navigable via
`bounds-of-thing-at-point' (and by extension `beginning-of-thing' /
`end-of-thing') in any buffer whose tree-sitter parser defines it in
`treesit-thing-settings'.

Pushing to this list is free -- the symbol takes effect only once
some language's `treesit-thing-settings' defines it.

Caveat: thing symbols MUST NOT collide with the name of a built-in
function.  `treesit-node-match-p' (a C function) tries to call a
symbol as a predicate before consulting `treesit-thing-settings',
so e.g. `string' as a thing symbol crashes -- hence `str-lit'."
  :type '(repeat symbol)
  :group 'treesit-tap)

(defun treesit-tap-bounds (thing)
  "Return (BEG . END) of THING at point via tree-sitter, or nil.

Returns nil when the buffer has no treesit parser or when THING is
not defined in `treesit-thing-settings' for the current language.
Suitable for use as a `bounds-of-thing-at-point' provider."
  (when (and (fboundp 'treesit-parser-list)
             (treesit-parser-list)
             (treesit-thing-defined-p thing (treesit-language-at (point))))
    (when-let* ((node (treesit-thing-at-point thing 'nested)))
      (cons (treesit-node-start node) (treesit-node-end node)))))

(defun treesit-tap--install-bridge ()
  "Install bounds providers for each `treesit-tap-bridged-things' entry."
  (dolist (thing treesit-tap-bridged-things)
    (setf (alist-get thing bounds-of-thing-at-point-provider-alist)
          (let ((th thing))
            (lambda () (treesit-tap-bounds th))))))

(defun treesit-tap--uninstall-bridge ()
  "Remove the bounds providers `treesit-tap--install-bridge' installed."
  (dolist (thing treesit-tap-bridged-things)
    (setf bounds-of-thing-at-point-provider-alist
          (assq-delete-all thing
                           bounds-of-thing-at-point-provider-alist))))


;;;; Per-language extras
;; ----------------------------------------------------------------

(defcustom treesit-tap-language-extras
  (let ((typescript-extras
         '((function "\\`\\(function_declaration\\|function_expression\\|arrow_function\\|method_definition\\|generator_function_declaration\\)\\'")
           (class "\\`class_declaration\\'")
           (method "\\`method_definition\\'")
           (interface "\\`interface_declaration\\'")
           (loop "\\`\\(for_statement\\|while_statement\\|for_in_statement\\|do_statement\\)\\'")
           (conditional "\\`\\(if_statement\\|ternary_expression\\)\\'")
           (decorator "\\`decorator\\'")
           (call "\\`\\(call_expression\\|new_expression\\)\\'")
           (parameter "\\`\\(required_parameter\\|optional_parameter\\)\\'")
           (argument_list "\\`arguments\\'")
           (str-lit "\\`\\(string\\|template_string\\)\\'")
           (statement "_\\(statement\\|declaration\\)\\'"))))
    `((python
       (function "\\`function_definition\\'")
       (class "\\`class_definition\\'")
       (method "\\`function_definition\\'")
       (loop "\\`\\(for_statement\\|while_statement\\)\\'")
       (conditional "\\`if_statement\\'")
       (decorator "\\`\\(decorator\\|decorated_definition\\)\\'")
       (call "\\`call\\'")
       (parameter "\\`\\(parameters\\|default_parameter\\|lambda_parameters\\|list_splat_pattern\\|dictionary_splat_pattern\\)\\'")
       (argument_list "\\`argument_list\\'")
       (str-lit "\\`string\\'")
       (statement "_\\(statement\\|definition\\)\\'"))
      (typescript ,@typescript-extras)
      (tsx ,@typescript-extras)))
  "Alist of (LANG . EXTRAS) augmenting `treesit-thing-settings'.

Each EXTRAS is a list of (THING PREDICATE) entries in the same shape
`treesit-thing-settings' accepts.  Applied by
`treesit-tap--apply-language-extras' on `after-change-major-mode-hook'
for every language with a parser in the current buffer.

Add languages by pushing entries; the wiring is automatic.  Example:

  (push \\='(rust
           (function \"\\\\`function_item\\\\'\")
           (class \"\\\\`impl_item\\\\'\")
           ...)
         treesit-tap-language-extras)

Caveats baked into the regexes:
- All anchored with `\\\\=' so e.g. `string' matches only the `string'
  node, not `string_content' / `string_start' / `string_end'.
- Thing symbols must not collide with built-in function names --
  `treesit-node-match-p' (C) tries `funcall' before consulting
  settings.  Hence `str-lit', not `string'."
  :type '(alist :key-type symbol
                :value-type (repeat (list symbol string)))
  :group 'treesit-tap)

(defun treesit-tap-extend-language (lang extras)
  "Append EXTRAS to LANG's section of `treesit-thing-settings'.
Buffer-local.  Idempotent: existing thing definitions are preserved."
  (let ((existing (cdr (assq lang treesit-thing-settings))))
    (dolist (extra extras)
      (unless (assq (car extra) existing)
        (setq existing (append existing (list extra)))))
    (setq-local treesit-thing-settings
                (cons (cons lang existing)
                      (assq-delete-all
                       lang
                       (copy-sequence treesit-thing-settings))))))

(defun treesit-tap--apply-language-extras ()
  "Apply `treesit-tap-language-extras' to every parser language in
the current buffer.  Safe in non-treesit buffers (no-op)."
  (when (and (boundp 'treesit-thing-settings)
             (fboundp 'treesit-parser-list)
             (treesit-parser-list))
    (dolist (parser (treesit-parser-list))
      (when-let* ((lang (treesit-parser-language parser))
                  (extras (alist-get lang treesit-tap-language-extras)))
        (treesit-tap-extend-language lang extras)))))


;;;; Mode
;; ----------------------------------------------------------------

;;;###autoload
(define-minor-mode treesit-tap-mode
  "Bridge tree-sitter to thing-at-point.

When enabled, installs a `bounds-of-thing-at-point' provider for every
symbol in `treesit-tap-bridged-things', and registers an
`after-change-major-mode-hook' that applies
`treesit-tap-language-extras' to every treesit parser in the buffer.

Global mode -- toggling once is enough.  Cheap when off: no providers
installed, no hook registered."
  :global t
  :group 'treesit-tap
  (if treesit-tap-mode
      (progn
        (treesit-tap--install-bridge)
        (add-hook 'after-change-major-mode-hook
                  #'treesit-tap--apply-language-extras))
    (treesit-tap--uninstall-bridge)
    (remove-hook 'after-change-major-mode-hook
                 #'treesit-tap--apply-language-extras)))


;;;; Current-thing state + commands
;; ----------------------------------------------------------------

(defcustom treesit-tap-things
  '("symbol" "list" "sexp" "defun" "filename" "url"
    "email" "uuid" "word" "sentence" "whitespace" "line"
    "page" "paragraph" "button")
  "List of `thing-at-point' thing names offered by `treesit-tap-set-local'.
Strings (interactive prompt) -- interned to symbols on selection.
Extend with any custom thing the user has registered."
  :type '(repeat string)
  :group 'treesit-tap)

(defcustom treesit-tap-default-thing 'defun
  "Default value for `treesit-tap-current-thing' in buffers that
have not been explicitly set via `treesit-tap-set-local'."
  :type 'symbol
  :group 'treesit-tap)

(defvar-local treesit-tap-current-thing nil
  "Buffer-local `thing-at-point' symbol used by treesit-tap nav.

Set via `treesit-tap-set-local'.  Consumed by `treesit-tap-next' /
`-prev' / `-beg' / `-end' / `-pulse' / `-select' / `-comment' and
any caller of `treesit-tap-locate-thing'.

Defaults to `treesit-tap-default-thing' on first read.")

(defun treesit-tap--current-thing ()
  "Return the effective current thing (fallback to default)."
  (or treesit-tap-current-thing treesit-tap-default-thing))

(defun treesit-tap--intern-maybe (thing)
  "Coerce THING to a symbol -- pass through symbols, intern strings."
  (if (symbolp thing) thing (intern thing)))


;;;; Set-local with consult preview

(defvar-local treesit-tap--preview-overlay nil
  "Overlay used by `treesit-tap-set-local' consult preview.")

(defun treesit-tap--clear-preview ()
  "Delete `treesit-tap--preview-overlay' if any."
  (when (overlayp treesit-tap--preview-overlay)
    (delete-overlay treesit-tap--preview-overlay))
  (setq treesit-tap--preview-overlay nil))

(defun treesit-tap--first-bounds-for (thing)
  "Return bounds for an instance of THING in the current buffer.

At point first (cheap; covers defun / sexp / line / sentence almost
always).  Otherwise scans forward from `window-start' for the first
visible instance (covers url / email in buffers where the cursor is
not on one)."
  (or (ignore-errors (bounds-of-thing-at-point thing))
      (let ((win-beg (window-start))
            (win-end (window-end nil t))
            found)
        (save-excursion
          (goto-char win-beg)
          (while (and (< (point) win-end) (not found))
            (let ((b (ignore-errors (bounds-of-thing-at-point thing))))
              (if b
                  (setq found b)
                (forward-char 1)))))
        found)))

(defun treesit-tap--show-preview (sym)
  "Paint preview overlay for thing SYM, if an instance is locatable."
  (when-let* ((b (treesit-tap--first-bounds-for sym)))
    (let ((ov (make-overlay (car b) (cdr b))))
      (overlay-put ov 'face 'highlight)
      (overlay-put ov 'priority 100)
      (setq treesit-tap--preview-overlay ov))))

;;;###autoload
(defun treesit-tap-set-local (&optional thing)
  "Set the local current thing for treesit-tap navigation.

THING may be a symbol or a string; interactively, prompts from
`treesit-tap-things' with `consult--read' preview (when consult is
loaded) -- as you narrow through candidates, an instance of each
thing is highlighted in the buffer.  Falls back to plain
`completing-read' without preview when consult is absent.

Also mirrors to `focus-current-thing' so `focus-mode' (when active)
dims around the same thing."
  (interactive)
  (let* ((picked
          (or thing
              (cond
               ((fboundp 'consult--read)
                (unwind-protect
                    (consult--read
                     treesit-tap-things
                     :prompt "What thing? "
                     :require-match t
                     :sort nil
                     :state
                     (lambda (action cand)
                       (pcase action
                         ('preview
                          (treesit-tap--clear-preview)
                          (when (and cand (stringp cand))
                            (treesit-tap--show-preview
                             (treesit-tap--intern-maybe cand))))
                         ((or 'exit 'return)
                          (treesit-tap--clear-preview)))))
                  (treesit-tap--clear-preview)))
               (t
                (completing-read "What thing? " treesit-tap-things)))))
         (sym (treesit-tap--intern-maybe picked)))
    (setq-local treesit-tap-current-thing sym)
    (when (boundp 'focus-current-thing)
      (setq-local focus-current-thing sym))))


;;;; Nav + locate + select / pulse / comment

;;;###autoload
(defun treesit-tap-forward-thing (n)
  "Move N things of `treesit-tap-current-thing' forward (negative for back).

Dispatches to `treesit-navigate-thing' when the thing is defined in
the buffer's `treesit-thing-settings', otherwise to `forward-thing'.
Lands at the start of the destination thing's bounds so subsequent
`bounds-of-thing-at-point' lookups succeed.  Does not move when
there is no destination thing."
  (interactive "p")
  (let* ((thing (treesit-tap--current-thing))
         (treesit-defined
          (and (fboundp 'treesit-parser-list)
               (treesit-parser-list)
               (treesit-thing-defined-p
                thing (treesit-language-at (point))))))
    (if treesit-defined
        (when-let* ((dest (treesit-navigate-thing (point) n 'beg thing)))
          (goto-char dest))
      (let ((start-pos (point)))
        (ignore-errors (forward-thing thing n))
        (when (= (point) start-pos)
          (when-let* ((bnds (bounds-of-thing-at-point thing)))
            (goto-char (if (> n 0)
                           (min (point-max) (1+ (cdr bnds)))
                         (max (point-min) (1- (car bnds)))))))
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
        (when-let* ((bnds (bounds-of-thing-at-point thing))
                    (snap-pos (car bnds)))
          (when (or (and (> n 0) (> snap-pos start-pos))
                    (and (< n 0) (< snap-pos start-pos)))
            (goto-char snap-pos)))))))

(defun treesit-tap-locate-thing (&optional thing)
  "Return (BEG . END) of THING (or current thing) at point, or nil.

END is exclusive (the position immediately after the last char),
matching the Emacs `bounds-of-thing-at-point' convention."
  (interactive)
  (let ((thing-sym (treesit-tap--intern-maybe
                    (or thing (treesit-tap--current-thing)))))
    (bounds-of-thing-at-point thing-sym)))

(defun treesit-tap-locate-thing-beg (&optional thing)
  "Return BEG of THING (or current thing) at point."
  (interactive)
  (when-let* ((b (treesit-tap-locate-thing thing))) (car b)))

(defun treesit-tap-locate-thing-end (&optional thing)
  "Return END of THING (or current thing) at point (exclusive)."
  (interactive)
  (when-let* ((b (treesit-tap-locate-thing thing))) (cdr b)))

(defun treesit-tap-get-thing (&optional thing)
  "Return the text of THING (or current thing) at point.
If a region is active, returns the region's text instead."
  (interactive)
  (if (use-region-p)
      (buffer-substring-no-properties (region-beginning) (region-end))
    (when-let* ((b (treesit-tap-locate-thing thing)))
      (buffer-substring-no-properties (car b) (cdr b)))))

;;;###autoload
(defun treesit-tap-pulse (&optional thing)
  "Briefly highlight the bounds of THING (or current thing)."
  (interactive)
  (when-let* ((b (treesit-tap-locate-thing thing)))
    (pulse-momentary-highlight-region
     (car b) (cdr b)
     '(:background "black" :foreground "gray"))))

;;;###autoload
(defun treesit-tap-select (&optional thing)
  "Set mark and point to span THING (or current thing) at point."
  (interactive)
  (when-let* ((b (treesit-tap-locate-thing thing)))
    (set-mark (car b))
    (goto-char (cdr b))))

;;;###autoload
(defun treesit-tap-comment (&optional thing)
  "Comment / uncomment THING (or current thing) at point."
  (interactive)
  (save-excursion
    (treesit-tap-select thing)
    (call-interactively 'comment-or-uncomment-region)))

;;;###autoload
(defun treesit-tap-next ()
  "Move forward by one instance of `treesit-tap-current-thing'."
  (interactive)
  (treesit-tap-forward-thing 1))

;;;###autoload
(defun treesit-tap-prev ()
  "Move backward by one instance of `treesit-tap-current-thing'."
  (interactive)
  (treesit-tap-forward-thing -1))

;;;###autoload
(defun treesit-tap-beg ()
  "Move to the beginning of `treesit-tap-current-thing' at point."
  (interactive)
  (beginning-of-thing (treesit-tap--current-thing)))

;;;###autoload
(defun treesit-tap-end ()
  "Move to the end of `treesit-tap-current-thing' at point."
  (interactive)
  (end-of-thing (treesit-tap--current-thing))
  ;; Skip trailing whitespace that some thing providers include.
  (ignore-errors (re-search-backward "[^[:space:]\n]" nil t)
                 (forward-char 1)))

(defun treesit-tap-at-bobp ()
  "Non-nil if at beginning of `treesit-tap-current-thing' at point."
  (interactive)
  (eq 1 (save-excursion
          (beginning-of-thing (treesit-tap--current-thing))
          (point))))

(defun treesit-tap-at-eobp ()
  "Non-nil if at end of `treesit-tap-current-thing' at point."
  (interactive)
  (save-excursion
    (end-of-thing (treesit-tap--current-thing))
    (eobp)))


;;;; Setup convenience
;; ----------------------------------------------------------------

;;;###autoload
(defun treesit-tap-setup ()
  "Enable `treesit-tap-mode' (bridge + language extras hook).

Convenience entry point for users who want the default behavior
with one call.  Equivalent to `(treesit-tap-mode 1)'."
  (interactive)
  (treesit-tap-mode 1))


(provide 'treesit-tap)
;;; treesit-tap.el ends here
