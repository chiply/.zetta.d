;;; embark-scope.el --- Type-aware embark navigation + picker UX -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; URL: https://github.com/<TBD>/embark-scope
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (embark "1.0") (treesit-tap "0.1"))
;; Keywords: convenience, completion, tools

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

;; Type-aware structural navigation, instance pickers, and per-type
;; actions on top of embark.
;;
;; Three command families:
;;
;;   `embark-scope-nav-*'   move by current target's type (next /
;;                            prev / beg / end)
;;   `embark-scope-pick-*'  pick a type (consult + preview, or
;;                            single-key transient) or a visible
;;                            instance of one (consult or avy)
;;   `embark-scope-act-*'   act on the captured target -- focus,
;;                            highlight other instances, select as
;;                            region, narrow
;;
;; Plus:
;;   - `embark-scope-sort-by-bounds-mode' -- innermost-first cycle
;;     order on `embark--targets'.
;;   - `embark-scope-back-cycle-mode' -- C-, in the embark menu
;;     prompter cycles backward.
;;   - `embark-scope-deftap-finder' macro -- wrap any
;;     `thing-at-point' thing as an embark target finder.
;;   - Fast collectors: regex sweep for URL / email / uuid /
;;     integer; per-position thing-scan as fallback; specialized
;;     bracketed-org-link scanner for embark-org link types.
;;   - `embark-scope-jump-to-type' / `-avy-jump-to-type' -- pick
;;     a type at the top level (no embark-act required) and jump.
;;
;; The nav / act commands depend on a captured "last embark target"
;; state -- set by `embark-scope-capture-mode' via a pre-action
;; hook AND a rotate advice (capture must survive cycling).  All
;; nav / act commands fail loudly with `user-error' when
;; capture-mode is off.
;;
;; One-call setup:
;;
;;   (embark-scope-setup)            ; capture + sort + bindings
;;
;; Standalone: hard depends on embark and treesit-tap (the nav
;; family lex-binds `treesit-tap-current-thing').  Soft-uses
;; `avy', `consult', `marginalia', `embark-org', `focus' when
;; loaded.

;;; Code:

(require 'cl-lib)
(require 'thingatpt)
(require 'embark)
(require 'treesit-tap)

;; Forward declarations for optional deps.
(defvar avy-action)
(defvar avy-pre-action)
(defvar avy-style)
(declare-function avy-process "avy" (candidates &optional overlay-fn cleanup-fn))
(declare-function consult--read "consult" (table &rest options))
(declare-function focus-mode "focus" (&optional arg))
(declare-function focus-current-thing "focus" ())

(defgroup embark-scope nil
  "Type-aware embark navigation + picker UX."
  :group 'convenience
  :prefix "embark-scope-")


;;;; Sub-keymaps
;; ----------------------------------------------------------------
;; A defun keymap so embark has somewhere to dispatch when its
;; built-in `embark-target-defun-at-point' fires (it ships no
;; defun-specific map by default; the keymap also covers the
;; treesit-bridged `defun' bounds from treesit-tap's Bridge A).

(defvar-keymap embark-scope-defun-map
  :doc "Embark actions for `defun' targets."
  :parent embark-general-map
  "e" #'eval-defun
  "n" #'narrow-to-defun
  "m" #'mark-defun)


;;;; Bridge B: TAP-thing -> embark target finder
;; ----------------------------------------------------------------

(defmacro embark-scope-deftap-finder (thing &optional type)
  "Define an embark target finder for `thing-at-point' THING.

Generates a finder named `embark-scope-target-<thing>-at-point' that
returns a TYPE-tagged embark target (defaults to THING) covering the
bounds-of-thing-at-point.  Gated against minibuffer + completion-list
+ embark-collect modes so it doesn't fire in pop-up UI buffers.
Bounds are clamped to (point-min)..(point-max).

Adds the finder to `embark-target-finders'."
  (let* ((thing-sym (if (consp thing) (eval thing) thing))
         (type-sym (or type thing-sym))
         (name (intern (format "embark-scope-target-%s-at-point" thing-sym))))
    `(progn
       (defun ,name ()
         ,(format "Embark target finder for `%s'." thing-sym)
         (when (and (not (minibufferp))
                    (not (derived-mode-p 'completion-list-mode
                                         'embark-collect-mode)))
           (when-let* ((b (ignore-errors (bounds-of-thing-at-point ',thing-sym)))
                       (beg (max (point-min) (car b)))
                       (end (min (point-max) (cdr b)))
                       ((< beg end)))
             (cons ',type-sym
                   (cons (buffer-substring-no-properties beg end)
                         (cons beg end))))))
       (add-to-list 'embark-target-finders #',name))))


;;;; Hand-written finders
;; ----------------------------------------------------------------

(defcustom embark-scope-word-finder-modes
  '(text-mode org-mode emacs-lisp-mode)
  "Major modes (and derivatives) where `embark-scope-target-word-at-point' fires.

Default covers prose modes plus elisp -- in elisp `-' is symbol-
constituent, so word and symbol have meaningfully different bounds
(inside `some-function-here', word=function vs symbol=some-function-here)
and surfacing both as separate embark targets is useful.  In most
other prog-modes the distinction is less useful.

Plus, `eww-mode' / `help-mode' / `Info-mode' / `Man-mode' are
unconditionally included regardless of this list."
  :type '(repeat symbol)
  :group 'embark-scope)

(defcustom embark-scope-word-finder-extra-modes
  '(eww-mode help-mode Info-mode Man-mode)
  "Extra modes (exact match, not derived) where the word finder fires."
  :type '(repeat symbol)
  :group 'embark-scope)

(defun embark-scope-target-word-at-point ()
  "Embark target finder for `word'.

Active in prose buffers (text/org/eww/help/Info/Man) AND elisp,
per `embark-scope-word-finder-modes' +
`embark-scope-word-finder-extra-modes'."
  (when (and (not (or (minibufferp)
                      (derived-mode-p 'completion-list-mode
                                      'embark-collect-mode)))
             (or (apply #'derived-mode-p embark-scope-word-finder-modes)
                 (memq major-mode embark-scope-word-finder-extra-modes)))
    (when-let* ((b (ignore-errors (bounds-of-thing-at-point 'word)))
                (beg (max (point-min) (car b)))
                (end (min (point-max) (cdr b)))
                ((< beg end)))
      (cons 'word
            (cons (buffer-substring-no-properties beg end)
                  (cons beg end))))))


;;;; Cycle sort
;; ----------------------------------------------------------------

(defcustom embark-scope-sort-by-bounds-p t
  "When non-nil, `embark-scope-sort-by-bounds-mode' sorts embark's
target cycle by bounds size (ascending)."
  :type 'boolean
  :group 'embark-scope)

(defvar embark-scope--sort-reverse nil
  "Dynamic flip controlling sort direction.  Bound by
`embark-scope-act-contract'.")

(defun embark-scope--sort-targets-by-bounds (targets)
  "Sort TARGETS by bounds size ascending (innermost first).
Targets without bounds keep their relative order at the end of the
list.  When `embark-scope--sort-reverse' is non-nil, the cycle
order flips (outermost first)."
  (if embark-scope-sort-by-bounds-p
      (let* ((with-bounds (cl-remove-if-not
                           (lambda (tgt) (plist-get tgt :bounds))
                           targets))
             (without-bounds (cl-remove-if
                              (lambda (tgt) (plist-get tgt :bounds))
                              targets))
             (sorted (sort with-bounds
                           (lambda (a b)
                             (let* ((a-bounds (plist-get a :bounds))
                                    (b-bounds (plist-get b :bounds))
                                    (a-size (- (cdr a-bounds) (car a-bounds)))
                                    (b-size (- (cdr b-bounds) (car b-bounds))))
                               (if embark-scope--sort-reverse
                                   (> a-size b-size)
                                 (< a-size b-size)))))))
        (append sorted without-bounds))
    targets))

;;;###autoload
(define-minor-mode embark-scope-sort-by-bounds-mode
  "Sort embark's target cycle by bounds size (innermost first).
Installs a `:filter-return' advice on `embark--targets' that
post-sorts the target list per `embark-scope-sort-by-bounds-p'."
  :global t
  :group 'embark-scope
  (if embark-scope-sort-by-bounds-mode
      (advice-add 'embark--targets :filter-return
                  #'embark-scope--sort-targets-by-bounds)
    (advice-remove 'embark--targets
                   #'embark-scope--sort-targets-by-bounds)))

;;;###autoload
(defun embark-scope-act-contract ()
  "Like `embark-act' but cycle from outermost target inward.
The default `embark-act' picks the innermost (smallest bounds)
target as the default.  This command flips the sort direction so
the OUTERMOST target is the default; useful when you know the
enclosing scope is what you want and the inner sub-targets are
noise (e.g. acting on the whole defun rather than the call inside)."
  (interactive)
  (let ((embark-scope--sort-reverse t))
    (call-interactively #'embark-act)))


;;;; Back-cycle (C-, in the embark prompter)
;; ----------------------------------------------------------------

(defun embark-scope-back-cycle ()
  "Marker for single-key backward cycle inside `embark-keymap-prompter'.
The actual back-rotation is performed by the :around advice that
substitutes `embark-cycle' with `prefix-arg' forced to -1.

Calling this directly is an error -- it only has meaning inside the
embark prompter UI."
  (interactive)
  (user-error
   "`embark-scope-back-cycle' is meant for the embark prompter only"))

(defun embark-scope--keymap-prompter-back-cycle (orig keymap update)
  "Translate `embark-scope-back-cycle' returns into backward
`embark-cycle' by forcing `prefix-arg' to -1."
  (let ((cmd (funcall orig keymap update)))
    (if (eq cmd 'embark-scope-back-cycle)
        (progn (setq prefix-arg -1) 'embark-cycle)
      cmd)))

(defun embark-scope--reset-prefix-arg-after-rotate (&rest _)
  "Reset `prefix-arg' after rotation -- one-shot prefix semantics
inside the embark-act cycle loop."
  (setq prefix-arg nil))

;;;###autoload
(define-minor-mode embark-scope-back-cycle-mode
  "Add `C-,' to `embark-general-map' for backward cycling.
Pairs with `C-.' (`embark-cycle' forward).  Resets `prefix-arg'
after each rotation so the direction is per-press, not sticky."
  :global t
  :group 'embark-scope
  (if embark-scope-back-cycle-mode
      (progn
        (define-key embark-general-map (kbd "C-,")
                    #'embark-scope-back-cycle)
        (advice-add 'embark-keymap-prompter :around
                    #'embark-scope--keymap-prompter-back-cycle)
        (advice-add 'embark--rotate :after
                    #'embark-scope--reset-prefix-arg-after-rotate))
    (define-key embark-general-map (kbd "C-,") nil)
    (advice-remove 'embark-keymap-prompter
                   #'embark-scope--keymap-prompter-back-cycle)
    (advice-remove 'embark--rotate
                   #'embark-scope--reset-prefix-arg-after-rotate)))


;;;; Nav-type-map + capture state
;; ----------------------------------------------------------------

(defcustom embark-scope-nav-type-map
  '((general . word)
    (identifier . symbol)
    (expression . sexp)
    (defun . defun)
    (paragraph . paragraph)
    (sentence . sentence))
  "Map embark target types to `thing-at-point' things for navigation.

Missing entries fall through to the type itself, in case the type is
already a thing.  Navigation no-ops if the resolved thing has neither
a `forward-op' property nor a treesit definition for the buffer's
language.

Example -- map `org-src-block' to itself (the `org' module sets
`forward-op' on it):

  (setf (alist-get \\='org-src-block embark-scope-nav-type-map)
        \\='org-src-block)"
  :type '(alist :key-type symbol :value-type symbol)
  :group 'embark-scope)

(defvar embark-scope-last-target-type nil
  "Type of the most recent embark target.
Maintained by `embark-scope-capture-mode'.  Read by `nav-*' / `act-*'
commands.  The `last-' prefix signals: \"set by hook, not by user\".")

(defvar embark-scope-last-target-bounds nil
  "Bounds of the most recent embark target, or nil if unbounded.
Maintained by `embark-scope-capture-mode'.")

(defun embark-scope--capture-target (&rest plist)
  "Pre-action hook: capture target type and bounds for nav/act commands."
  (setq embark-scope-last-target-type (plist-get plist :type)
        embark-scope-last-target-bounds (plist-get plist :bounds)))

(defun embark-scope--capture-on-rotate (rotated-targets)
  "`:filter-return' on `embark--rotate'.
Catches type changes during cycling that the pre-action hook misses
(rotation doesn't fire a pre-action hook).  Returns ROTATED-TARGETS
unchanged."
  (when rotated-targets
    (let ((target (car rotated-targets)))
      (setq embark-scope-last-target-type (plist-get target :type)
            embark-scope-last-target-bounds (plist-get target :bounds))))
  rotated-targets)

;;;###autoload
(define-minor-mode embark-scope-capture-mode
  "Capture the active embark target's type + bounds for nav/act commands.

Installs TWO writers:
1. A `:always' pre-action hook -- fires when the user picks an
   action from the embark menu.
2. A `:filter-return' advice on `embark--rotate' -- fires when the
   user cycles targets with `C-.' / `C-,', which does NOT trigger
   pre-action hooks.

Both must be installed; otherwise the captured state goes stale
during cycling.  Required by every `embark-scope-nav-*' and
`embark-scope-act-*' command -- those guard with `user-error'."
  :global t
  :group 'embark-scope
  (if embark-scope-capture-mode
      (progn
        ;; (1) Pre-action hook -- idempotent install.
        (let ((hooks (alist-get :always embark-pre-action-hooks)))
          (unless (memq #'embark-scope--capture-target hooks)
            (setf (alist-get :always embark-pre-action-hooks)
                  (cons #'embark-scope--capture-target hooks))))
        ;; (2) Rotate advice.
        (advice-add 'embark--rotate :filter-return
                    #'embark-scope--capture-on-rotate))
    ;; Clean toggle off -- both writers removed.
    (setf (alist-get :always embark-pre-action-hooks)
          (delq #'embark-scope--capture-target
                (alist-get :always embark-pre-action-hooks)))
    (advice-remove 'embark--rotate
                   #'embark-scope--capture-on-rotate)))

(defun embark-scope--require-capture-mode ()
  "Signal a `user-error' if `embark-scope-capture-mode' is off."
  (unless embark-scope-capture-mode
    (user-error
     "Enable `embark-scope-capture-mode' first (the nav/act family needs it)")))


;;;; Nav commands
;; ----------------------------------------------------------------

(defun embark-scope--nav (n)
  "Move N instances forward (negative = back) of current target's type."
  (let* ((type embark-scope-last-target-type)
         (bounds embark-scope-last-target-bounds)
         (thing (alist-get type embark-scope-nav-type-map type)))
    (cond
     ((null type)
      (message "No embark target captured yet"))
     ((null bounds)
      (message "Embark type `%s' has no bounds; nav not applicable" type))
     ((not (symbolp thing))
      (message "No nav thing mapped for embark type `%s'" type))
     (t
      (let ((treesit-tap-current-thing thing))
        (treesit-tap-forward-thing n))))))

;;;###autoload
(defun embark-scope-nav-next ()
  "Move to next instance of current embark target's type."
  (interactive)
  (embark-scope--require-capture-mode)
  (embark-scope--nav 1))

;;;###autoload
(defun embark-scope-nav-prev ()
  "Move to previous instance of current embark target's type."
  (interactive)
  (embark-scope--require-capture-mode)
  (embark-scope--nav -1))

;;;###autoload
(defun embark-scope-nav-beg ()
  "Move point to the start of the current embark target's bounds."
  (interactive)
  (embark-scope--require-capture-mode)
  (if embark-scope-last-target-bounds
      (goto-char (car embark-scope-last-target-bounds))
    (message "No embark target bounds captured")))

;;;###autoload
(defun embark-scope-nav-end ()
  "Move point to the end of the current embark target's bounds.
Lands at the last position INSIDE the bounds so embark's repeat
re-prompts on the same target, not the thing that starts at the
boundary."
  (interactive)
  (embark-scope--require-capture-mode)
  (if embark-scope-last-target-bounds
      (let ((beg (car embark-scope-last-target-bounds))
            (end (cdr embark-scope-last-target-bounds)))
        (goto-char (max beg (1- end))))
    (message "No embark target bounds captured")))


;;;; Expression bounds helper
;; ----------------------------------------------------------------

(defun embark-scope--expression-bounds ()
  "Bounds of the smart expression at point per embark's finder."
  (when-let* ((result (ignore-errors
                        (embark-target-expression-at-point))))
    (when (and (consp result) (consp (cdr result)))
      (let ((beg (caddr result))
            (end (cdddr result)))
        (when (and (integerp beg) (integerp end))
          (cons beg end))))))


;;;; Act: focus
;; ----------------------------------------------------------------

;;;###autoload
(defun embark-scope-act-focus ()
  "Activate `focus-mode' on the captured embark target's type."
  (interactive)
  (embark-scope--require-capture-mode)
  (cond
   ((not (fboundp 'focus-mode))
    (user-error "focus.el not loaded"))
   ((null embark-scope-last-target-type)
    (message "No embark target captured yet"))
   (t
    (let* ((type embark-scope-last-target-type)
           (thing (alist-get type embark-scope-nav-type-map type)))
      (when (boundp 'focus-current-thing)
        (setq-local focus-current-thing thing))
      (focus-mode 1)))))


;;;; Act: set current treesit-tap thing
;; ----------------------------------------------------------------

;;;###autoload
(defun embark-scope-act-set-current-thing ()
  "Set `treesit-tap-current-thing' to the captured target's type.

Useful when you've embark-acted on a target and now want s-j / s-k
nav to follow that thing without going through M-x
`treesit-tap-set-local'."
  (interactive)
  (embark-scope--require-capture-mode)
  (cond
   ((null embark-scope-last-target-type)
    (message "No embark target captured yet"))
   (t
    (let* ((type embark-scope-last-target-type)
           (thing (alist-get type embark-scope-nav-type-map type)))
      (setq-local treesit-tap-current-thing thing)
      (when (boundp 'focus-current-thing)
        (setq-local focus-current-thing thing))
      (message "treesit-tap-current-thing = `%s'%s" thing
               (if (eq thing type) ""
                 (format " (via nav-type-map from `%s')" type)))))))


;;;; Act: highlight other instances
;; ----------------------------------------------------------------

(defface embark-scope-other-instance-face
  '((t :inherit lazy-highlight))
  "Face for highlighted other-instances of the captured target's type."
  :group 'embark-scope)

(defvar-local embark-scope--instance-overlays nil
  "Overlays painted by `embark-scope-act-highlight-instances'.")

(defvar-local embark-scope--highlights-enabled nil
  "Non-nil after `act-highlight-instances' fires; consumed by the
refresh-on-rotate advice.")

(defun embark-scope--clear-instance-overlays ()
  "Remove all `embark-scope-act-highlight-instances' overlays in
the current buffer."
  (mapc #'delete-overlay embark-scope--instance-overlays)
  (setq embark-scope--instance-overlays nil))

(defun embark-scope--collect-instances-of-thing (thing)
  "Collect (BEG . END) bounds of every instance of THING in the buffer.
Treesit-aware: when the buffer has a parser and THING is defined in
`treesit-thing-settings', uses `treesit-navigate-thing'; otherwise
falls back to a forward-thing walker.  Used by
`embark-scope-act-highlight-instances'."
  (let ((results nil)
        (treesit-defined
         (and (fboundp 'treesit-parser-list)
              (treesit-parser-list)
              (treesit-thing-defined-p
               thing (treesit-language-at (point))))))
    (save-excursion
      (goto-char (point-min))
      (if treesit-defined
          (let ((seen (make-hash-table :test 'equal))
                (pos (point-min)))
            (while (when-let* ((next (treesit-navigate-thing
                                      pos 1 'beg thing))
                               ((/= next pos)))
                     (goto-char next)
                     (setq pos next)
                     t)
              (when-let* ((node (treesit-thing-at-point thing 'nested))
                          (b (cons (treesit-node-start node)
                                   (treesit-node-end node))))
                (unless (gethash b seen)
                  (puthash b t seen)
                  (push b results)))))
        ;; Legacy walker
        (while (let ((start-pos (point)))
                 (ignore-errors (forward-thing thing 1))
                 (when (and (/= (point) start-pos)
                            (< (point) (point-max)))
                   (when-let* ((b (bounds-of-thing-at-point thing)))
                     (push b results))
                   t)))))
    (nreverse results)))

;;;###autoload
(defun embark-scope-act-highlight-instances ()
  "Highlight every other instance of the captured target's type.

Uses `embark-scope-other-instance-face'.  Highlights persist
until point moves significantly or `act-clear-highlights' fires.
Refreshes on cycle when capture-mode is on, so highlights track
type changes."
  (interactive)
  (embark-scope--require-capture-mode)
  (cond
   ((null embark-scope-last-target-type)
    (message "No embark target captured yet"))
   (t
    (let* ((type embark-scope-last-target-type)
           (thing (alist-get type embark-scope-nav-type-map type))
           (own-bounds embark-scope-last-target-bounds))
      (embark-scope--clear-instance-overlays)
      (dolist (b (embark-scope--collect-instances-of-thing thing))
        (unless (and own-bounds
                     (= (car b) (car own-bounds))
                     (= (cdr b) (cdr own-bounds)))
          (let ((ov (make-overlay (car b) (cdr b))))
            (overlay-put ov 'face 'embark-scope-other-instance-face)
            (overlay-put ov 'embark-scope-highlight t)
            (push ov embark-scope--instance-overlays))))
      (setq embark-scope--highlights-enabled t)))))

;;;###autoload
(defun embark-scope-act-clear-highlights ()
  "Remove `embark-scope-act-highlight-instances' overlays."
  (interactive)
  (embark-scope--clear-instance-overlays)
  (setq embark-scope--highlights-enabled nil))

(defun embark-scope--refresh-highlights-on-rotate (rotated-targets)
  "Re-paint instance highlights when embark cycles to a new type.
Runs only when `embark-scope--highlights-enabled' is on; otherwise
no-op.  Returns ROTATED-TARGETS unchanged."
  (when (and embark-scope--highlights-enabled rotated-targets)
    (let* ((target (car rotated-targets))
           (type (plist-get target :type))
           (bounds (plist-get target :bounds))
           (thing (alist-get type embark-scope-nav-type-map type)))
      (embark-scope--clear-instance-overlays)
      (dolist (b (embark-scope--collect-instances-of-thing thing))
        (unless (and bounds
                     (= (car b) (car bounds))
                     (= (cdr b) (cdr bounds)))
          (let ((ov (make-overlay (car b) (cdr b))))
            (overlay-put ov 'face 'embark-scope-other-instance-face)
            (overlay-put ov 'embark-scope-highlight t)
            (push ov embark-scope--instance-overlays))))
      (setq embark-scope--highlights-enabled t)))
  rotated-targets)

;; Refresh advice installed with capture-mode (cycling re-paint).
;; Hooked in capture-mode's enable/disable below.


;;;; Act: select / narrow
;; ----------------------------------------------------------------

;;;###autoload
(defun embark-scope-act-select-as-region ()
  "Set mark and point to span the captured target's bounds."
  (interactive)
  (embark-scope--require-capture-mode)
  (if embark-scope-last-target-bounds
      (let ((b embark-scope-last-target-bounds))
        (goto-char (car b))
        (set-mark (cdr b))
        (activate-mark))
    (message "No embark target bounds captured")))

;;;###autoload
(defun embark-scope-act-narrow ()
  "Narrow the buffer to the captured target's bounds."
  (interactive)
  (embark-scope--require-capture-mode)
  (if embark-scope-last-target-bounds
      (let ((b embark-scope-last-target-bounds))
        (narrow-to-region (car b) (cdr b)))
    (message "No embark target bounds captured")))


;;;; Pick: preview overlay primitives
;; ----------------------------------------------------------------

(defvar-local embark-scope--pick-preview-overlay nil
  "One-shot preview overlay for the consult-based pickers.")

(defun embark-scope--pick-clear-preview ()
  "Delete `embark-scope--pick-preview-overlay' if any."
  (when (overlayp embark-scope--pick-preview-overlay)
    (delete-overlay embark-scope--pick-preview-overlay))
  (setq embark-scope--pick-preview-overlay nil))


;;;; Pick: target type (consult)
;; ----------------------------------------------------------------

(defun embark-scope--pick-target-type-do (candidates)
  "Open `consult--read' to pick from CANDIDATES, re-enter
`embark-act' on the chosen target.  Preview paints the focused
candidate's bounds with `embark-scope-other-instance-face'."
  (unwind-protect
      (let* ((choice
              (consult--read
               (mapcar #'car candidates)
               :prompt "Pick target type: "
               :require-match t
               :state
               (lambda (action cand)
                 (pcase action
                   ('preview
                    (embark-scope--pick-clear-preview)
                    (when (and cand (stringp cand))
                      (when-let* ((tgt (cdr (assoc cand candidates)))
                                  (b (plist-get tgt :bounds)))
                        (let ((ov (make-overlay (car b) (cdr b))))
                          (overlay-put ov 'face 'embark-scope-other-instance-face)
                          (overlay-put ov 'priority 100)
                          (setq embark-scope--pick-preview-overlay ov)
                          (goto-char (car b))))))))))
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
            (call-interactively #'embark-act))))
    (embark-scope--pick-clear-preview)))

;;;###autoload
(defun embark-scope-pick-target-type ()
  "Pick a target type from those at point, then re-enter embark-act.
Uses `consult--read' with preview.  Defers via `run-at-time' so the
consult UI opens cleanly after embark-act's prompt exits."
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
      (run-at-time 0 nil
                   #'embark-scope--pick-target-type-do candidates))))


;;;; Pick: target type (single-key transient)
;; ----------------------------------------------------------------

(defun embark-scope--assign-type-keys (types)
  "Assign unique single-char keys to TYPES (list of symbols).

For each TYPE, try each char of its symbol-name in order; pick the
first alphanumeric char not already taken.  When all chars of a name
are taken, fall back to the next free char from a-z.  Returns an
alist of (CHAR . TYPE) preserving TYPES order."
  (let ((used (make-hash-table))
        result)
    (dolist (type types)
      (let* ((name (symbol-name type))
             (key (or (cl-some
                       (lambda (c)
                         (and (or (and (>= c ?a) (<= c ?z))
                                  (and (>= c ?0) (<= c ?9)))
                              (not (gethash c used))
                              c))
                       (string-to-list name))
                      (cl-some
                       (lambda (c)
                         (unless (gethash c used) c))
                       (number-sequence ?a ?z)))))
        (when key
          (puthash key t used)
          (push (cons key type) result))))
    (nreverse result)))

(defun embark-scope--pick-target-type-key-do (choices key->type targets)
  "Read a single key and re-enter `embark-act' on the picked target.
Runs after the outer `embark-act' exits so `read-multiple-choice'
has a clean minibuffer/echo-area context."
  (let* ((picked (read-multiple-choice "Pick: " choices))
         (key (car picked))
         (type (alist-get key key->type))
         (tgt (cl-find type targets
                       :key (lambda (tgt) (plist-get tgt :type)))))
    (when tgt
      (let* ((sym (plist-get tgt :type))
             (text (plist-get tgt :target))
             (b (plist-get tgt :bounds))
             (beg (car b))
             (end (cdr b))
             (embark-target-finders
              (list (lambda ()
                      (cons sym (cons text (cons beg end)))))))
        (call-interactively #'embark-act)))))

;;;###autoload
(defun embark-scope-pick-target-type-key ()
  "Pick a target type at point via a single-key transient menu.

Like `embark-scope-pick-target-type' but uses
`read-multiple-choice' to read a single key instead of opening
`consult--read'.  Fast when you know the type you want.

Keys are inferred dynamically: for each type, the first free char of
its symbol-name wins (`url' -> `u', `org-url-link' -> `o', `line' ->
`l').  Deferred via `run-at-time' so the menu opens cleanly after
embark-act's prompt exits."
  (interactive)
  (let* ((targets (cl-remove-if-not
                   (lambda (tgt) (plist-get tgt :bounds))
                   (embark--targets)))
         (types (mapcar (lambda (tgt) (plist-get tgt :type)) targets))
         (key->type (embark-scope--assign-type-keys types))
         (choices (mapcar
                   (lambda (entry)
                     (let* ((c (car entry))
                            (type (cdr entry))
                            (tgt (cl-find type targets
                                          :key (lambda (tgt)
                                                 (plist-get tgt :type))))
                            (text (truncate-string-to-width
                                   (or (plist-get tgt :target) "")
                                   30 nil nil "…")))
                       (list c (format "%s %s" type text))))
                   key->type)))
    (cond
     ((null targets)
      (message "No bounded targets at point"))
     ((null choices)
      (message "No key could be assigned to any target type"))
     (t
      (run-at-time 0 nil
                   #'embark-scope--pick-target-type-key-do
                   choices key->type targets)))))


;;;; Symbol target types (helpers for collectors)
;; ----------------------------------------------------------------

(defcustom embark-scope-symbol-target-types
  '(function command variable face symbol identifier library package
             macro defvar)
  "Embark types treated as symbol-like (one-per-position, no nesting).

These bypass the per-position scan walker (which nests bounds for
sexp-shaped things) and use `embark-scope--collect-symbols-of-embark-type'
which walks symbols and classifies them by embark target type."
  :type '(repeat symbol)
  :group 'embark-scope)

(defun embark-scope--cheap-identifier-types (name)
  "Return embark types applicable to symbol NAME -- skips slow
library detection."
  (let* ((sym (intern-soft name))
         (types nil))
    (when (and sym (fboundp sym))
      (push 'function types)
      (when (commandp sym) (push 'command types)))
    (when (and sym (boundp sym))
      (push 'variable types))
    (when (and sym (facep sym)) (push 'face types))
    (push 'symbol types)
    (push 'identifier types)
    types))

(defun embark-scope--collect-symbols-of-embark-type (target-type)
  "Walk every symbol in the buffer, return bounds of those whose
types include TARGET-TYPE per `embark-scope--cheap-identifier-types'."
  (let (results last-end)
    (save-excursion
      (goto-char (point-min))
      (while (< (point) (point-max))
        (let ((bounds (ignore-errors (bounds-of-thing-at-point 'symbol))))
          (cond
           ((and bounds (> (cdr bounds) (or last-end 0)))
            (let* ((name (buffer-substring-no-properties
                          (car bounds) (cdr bounds)))
                   (types (embark-scope--cheap-identifier-types name)))
              (when (memq target-type types)
                (push bounds results))
              (setq last-end (cdr bounds))
              (goto-char (cdr bounds))))
           (t (forward-char 1))))))
    (nreverse results)))


;;;; Collectors
;; ----------------------------------------------------------------

(defcustom embark-scope-url-regex
  "\\b\\(?:https?\\|ftp\\|file\\)://[^ \t\n\r<>\"'`]+[^ \t\n\r<>\"'`.,;:!?)]"
  "Regex used by `embark-scope-collect-bounds-by-regex' for URLs."
  :type 'regexp
  :group 'embark-scope)

(defcustom embark-scope-email-regex
  "\\b[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[[:alpha:]]\\{2,\\}\\b"
  "Regex used by `embark-scope-collect-bounds-by-regex' for emails."
  :type 'regexp
  :group 'embark-scope)

(defun embark-scope-collect-bounds-by-regex (regex beg end)
  "Fast collector: list of (BEG . END) cons for each REGEX match in [BEG, END].

One-pass regex sweep -- orders of magnitude faster than the per-
position walker for things whose extent can be characterized by a
regex (URL, email, uuid, integer)."
  (let (results)
    (save-excursion
      (goto-char beg)
      (while (re-search-forward regex end t)
        (push (cons (match-beginning 0) (match-end 0)) results)))
    (nreverse results)))

(defun embark-scope-collect-bounds-by-scan (thing beg end)
  "Walk every position in BEG..END, returning every distinct
bounds-of-thing-at-point of THING.

At each position `bounds-of-thing-at-point' returns the smallest
containing instance, so scanning + dedup yields nested/overlapping
bounds (inner sexps inside outer ones, etc.) -- which the
forward-thing walker would miss due to its non-overlap filter."
  (let ((seen (make-hash-table :test 'equal))
        results)
    (save-excursion
      (cl-loop for p from beg below end do
               (goto-char p)
               (when-let* ((b (ignore-errors
                                (bounds-of-thing-at-point thing))))
                 (when (and (> (cdr b) (car b))
                            (not (gethash b seen)))
                   (puthash b t seen)
                   (push b results)))))
    (sort results (lambda (a b)
                    (if (= (car a) (car b))
                        (< (cdr a) (cdr b))
                      (< (car a) (car b)))))))

(defun embark-scope--compound-bound-p (b)
  "Non-nil if bounds B start with an open-delimiter character.
Used to filter out atom-sexps (`foo', `bar') so only list-like
expressions become avy targets."
  (let ((ch (char-after (car b))))
    (and ch (eq (char-syntax ch) ?\())))

(defun embark-scope-collect-org-links-of-scheme (scheme-regex beg end)
  "Collect bounds of `[[LINK][DESC]]' / `[[LINK]]' regions in [BEG, END]
whose LINK matches SCHEME-REGEX.

Returns (BEG . END) cons covering the *visible* portion of each link
-- the DESC region when present, else the LINK region.  This matters
with `org-link-descriptive' (default t): the `[[' / URL portion is
hidden by a display property."
  (let ((re "\\[\\[\\([^][]+\\)\\]\\(?:\\[\\([^][]+\\)\\]\\)?\\]")
        results)
    (save-excursion
      (goto-char beg)
      (while (re-search-forward re end t)
        (when (string-match-p scheme-regex
                              (match-string-no-properties 1))
          (let ((vb (or (match-beginning 2) (match-beginning 1)))
                (ve (or (match-end 2)       (match-end 1))))
            (push (cons vb ve) results)))))
    (nreverse results)))

(defun embark-scope-collect-visible-instances (type thing)
  "Return instances of TYPE (or its mapped THING) intersecting the
selected window's visible range.

Dispatches:
- URL types (`url' / `org-url-link') -> fast regex sweep + org-link
  scanner when applicable.
- Email types -> regex sweep + org-link scanner.
- `org-file-link' -> per-position file-name scan + org-link scanner.
- Symbol-shaped types (per `embark-scope-symbol-target-types') ->
  symbol classifier walker.
- Else -> per-position thing-at-point walker."
  (let* ((win-beg (window-start))
         (win-end (window-end nil t)))
    (cond
     ((eq type 'url)
      (embark-scope-collect-bounds-by-regex
       embark-scope-url-regex win-beg win-end))
     ((eq type 'org-url-link)
      (append
       (embark-scope-collect-bounds-by-regex
        embark-scope-url-regex win-beg win-end)
       (embark-scope-collect-org-links-of-scheme
        "\\`\\(?:https?\\|ftp\\)://" win-beg win-end)))
     ((eq type 'email)
      (embark-scope-collect-bounds-by-regex
       embark-scope-email-regex win-beg win-end))
     ((eq type 'org-email-link)
      (append
       (embark-scope-collect-bounds-by-regex
        embark-scope-email-regex win-beg win-end)
       (embark-scope-collect-org-links-of-scheme
        "\\`mailto:" win-beg win-end)))
     ((eq type 'org-file-link)
      (append
       (embark-scope-collect-bounds-by-scan 'filename win-beg win-end)
       (embark-scope-collect-org-links-of-scheme
        "\\`\\(?:file:\\|attachment:\\|[./]\\)" win-beg win-end)))
     ((memq type embark-scope-symbol-target-types)
      (cl-remove-if-not
       (lambda (b)
         (and (>= (cdr b) win-beg)
              (<= (car b) win-end)))
       (embark-scope--collect-symbols-of-embark-type type)))
     (t
      (let ((bounds (embark-scope-collect-bounds-by-scan
                     thing win-beg win-end)))
        (if (memq thing '(sexp embark-expression))
            (cl-remove-if-not #'embark-scope--compound-bound-p bounds)
          bounds))))))


;;;; Pick: instance (consult)
;; ----------------------------------------------------------------

(defun embark-scope--pick-instance-do (type _thing candidates start)
  "Open consult to pick one of CANDIDATES; act on picked target."
  (let ((cancelled t))
    (unwind-protect
        (let* ((choice (consult--read
                        (mapcar #'car candidates)
                        :prompt (format "Pick %s: " type)
                        :require-match t
                        :sort nil
                        :state
                        (lambda (action cand)
                          (pcase action
                            ('preview
                             (embark-scope--pick-clear-preview)
                             (when (and cand (stringp cand))
                               (when-let* ((b (cdr (assoc cand candidates))))
                                 (let ((ov (make-overlay (car b) (cdr b))))
                                   (overlay-put ov 'face
                                                'embark-scope-other-instance-face)
                                   (overlay-put ov 'priority 100)
                                   (setq embark-scope--pick-preview-overlay ov)
                                   (goto-char (car b))))))))))
               (picked (cdr (assoc choice candidates))))
          (when picked
            (setq cancelled nil)
            (let* ((beg (car picked))
                   (end (cdr picked))
                   (text (buffer-substring-no-properties beg end))
                   (embark-target-finders
                    (list (lambda ()
                            (cons type (cons text (cons beg end)))))))
              (call-interactively #'embark-act))))
      (embark-scope--pick-clear-preview)
      (when cancelled (goto-char start)))))

;;;###autoload
(defun embark-scope-pick-instance ()
  "Pick an instance of the captured target's type via consult.
Uses `embark-scope-collect-visible-instances' to gather targets."
  (interactive)
  (embark-scope--require-capture-mode)
  (let* ((type embark-scope-last-target-type)
         (thing (and type (alist-get type embark-scope-nav-type-map type)))
         (start (point)))
    (cond
     ((null type)
      (message "No embark target captured yet"))
     (t
      (let* ((instances (embark-scope-collect-visible-instances type thing))
             (candidates
              (mapcar (lambda (b)
                        (cons (truncate-string-to-width
                               (buffer-substring-no-properties (car b) (cdr b))
                               60 nil nil "…")
                              b))
                      instances)))
        (if (null candidates)
            (message "No visible instances of `%s'" type)
          (run-at-time 0 nil
                       #'embark-scope--pick-instance-do
                       type thing candidates start)))))))


;;;; Pick: instance (avy)
;; ----------------------------------------------------------------

(defun embark-scope--avy-pick-bounds (instances)
  "Run `avy-process' over INSTANCES (list of BEG.END cons).
Returns the picked (BEG . END) or nil on cancel/abort.  Binds
`avy-action' to `ignore' and captures the selection via
`avy-pre-action'."
  (when (and (fboundp 'avy-process) instances)
    (let* ((picked nil)
           (avy-pre-action (lambda (res) (setq picked res)))
           (avy-action #'ignore))
      (avy-process instances)
      (and (consp picked) (car picked)))))

(defun embark-scope--avy-act (_type bounds)
  "Jump point to BOUNDS' start.  Avy entry points are nav-only."
  (goto-char (car bounds)))

(defun embark-scope--avy-pick-instance-do (type thing start)
  "After embark exits: collect visible instances, avy-pick, act."
  (let ((instances (embark-scope-collect-visible-instances type thing)))
    (cond
     ((null instances)
      (message "No visible instances of `%s'" type)
      (goto-char start))
     (t
      (if-let* ((bounds (embark-scope--avy-pick-bounds instances)))
          (embark-scope--avy-act type bounds)
        (goto-char start))))))

;;;###autoload
(defun embark-scope-avy-pick-instance ()
  "Pick a visible instance of the captured target's type via avy."
  (interactive)
  (embark-scope--require-capture-mode)
  (let* ((type embark-scope-last-target-type)
         (thing (and type (alist-get type embark-scope-nav-type-map type)))
         (start (point)))
    (cond
     ((null type)
      (message "No embark target captured yet"))
     ((not (fboundp 'avy-process))
      (user-error "avy not loaded"))
     (t
      (run-at-time 0 nil
                   #'embark-scope--avy-pick-instance-do
                   type thing start)))))


;;;; Jump-to-type (top-level: no captured target needed)
;; ----------------------------------------------------------------

(defun embark-scope--jump-to-type-closest (instances anchor)
  "Return the instance in INSTANCES whose BEG is nearest to ANCHOR."
  (when instances
    (cl-reduce (lambda (a b)
                 (if (< (abs (- (car a) anchor))
                        (abs (- (car b) anchor)))
                     a b))
               instances)))

(defun embark-scope--jump-to-type-paint (instances)
  "Paint INSTANCES with `embark-scope-other-instance-face' overlays."
  (let (overlays)
    (dolist (b instances)
      (let ((ov (make-overlay (car b) (cdr b))))
        (overlay-put ov 'face 'embark-scope-other-instance-face)
        (overlay-put ov 'embark-scope-highlight t)
        (push ov overlays)))
    overlays))

(defun embark-scope--jump-type-applicable-p (sym)
  "Non-nil if SYM is a thing the buffer has visible instances of."
  (let* ((win-beg (window-start))
         (win-end (window-end nil t)))
    (save-excursion
      (goto-char win-beg)
      (cl-loop while (< (point) win-end)
               for bnds = (ignore-errors (bounds-of-thing-at-point sym))
               when (and bnds (>= (car bnds) win-beg)
                         (<= (cdr bnds) win-end))
               return t
               do (forward-char 1)))))

;;;###autoload
(defun embark-scope-jump-to-type ()
  "Top-level: prompt for a type, then consult-pick a visible instance.
No embark-act needed.  Useful when you know what kind of thing you
want without already being at an embark target."
  (interactive)
  (let* ((all-things (delete-dups
                      (append
                       (mapcar #'cdr embark-scope-nav-type-map)
                       embark-scope-symbol-target-types)))
         (applicable (cl-remove-if-not
                      #'embark-scope--jump-type-applicable-p
                      all-things))
         (choice (and applicable
                      (intern (completing-read
                               "Jump to type: "
                               (mapcar #'symbol-name applicable)
                               nil t)))))
    (when choice
      (let* ((instances (embark-scope-collect-visible-instances
                         choice choice))
             (candidates
              (mapcar (lambda (b)
                        (cons (truncate-string-to-width
                               (buffer-substring-no-properties (car b) (cdr b))
                               60 nil nil "…")
                              b))
                      instances))
             (start (point)))
        (if (null candidates)
            (message "No visible instances of `%s'" choice)
          (embark-scope--pick-instance-do choice choice
                                            candidates start))))))

;;;###autoload
(defun embark-scope-avy-jump-to-type ()
  "Top-level: prompt for a type, then avy-pick a visible instance."
  (interactive)
  (let* ((all-things (delete-dups
                      (append
                       (mapcar #'cdr embark-scope-nav-type-map)
                       embark-scope-symbol-target-types)))
         (applicable (cl-remove-if-not
                      #'embark-scope--jump-type-applicable-p
                      all-things))
         (choice (and applicable
                      (intern (completing-read
                               "Jump to type: "
                               (mapcar #'symbol-name applicable)
                               nil t))))
         (start (point)))
    (when choice
      (embark-scope--avy-pick-instance-do choice choice start))))


;;;; Default bindings + setup
;; ----------------------------------------------------------------

(defcustom embark-scope-default-bindings
  '(("C-j" . embark-scope-nav-next)
    ("C-k" . embark-scope-nav-prev)
    ("C-a" . embark-scope-nav-beg)
    ("C-e" . embark-scope-nav-end)
    ("C-t" . embark-scope-act-set-current-thing)
    ("C-f" . embark-scope-act-focus)
    ("C-v" . embark-scope-act-select-as-region)
    ("C-n" . embark-scope-act-narrow)
    ("C-l" . embark-scope-pick-target-type)
    (";"   . embark-scope-pick-target-type-key)
    ("C-o" . embark-scope-pick-instance)
    ("C-;" . embark-scope-avy-pick-instance)
    ("*"   . embark-scope-act-highlight-instances))
  "Recommended bindings installed by `embark-scope-install-default-bindings'."
  :type '(alist :key-type string :value-type symbol)
  :group 'embark-scope)

;;;###autoload
(defun embark-scope-install-default-bindings ()
  "Install `embark-scope-default-bindings' into `embark-general-map'."
  (interactive)
  (dolist (b embark-scope-default-bindings)
    (define-key embark-general-map (kbd (car b)) (cdr b))))

;;;###autoload
(defun embark-scope-setup ()
  "One-call setup: enable capture-mode + sort-by-bounds-mode +
back-cycle-mode, install default bindings, and register
`embark-scope-defun-map' for `defun' targets."
  (interactive)
  (embark-scope-capture-mode 1)
  (embark-scope-sort-by-bounds-mode 1)
  (embark-scope-back-cycle-mode 1)
  (embark-scope-install-default-bindings)
  (setf (alist-get 'defun embark-keymap-alist) 'embark-scope-defun-map)
  ;; Refresh-highlights advice piggybacks on capture-mode.
  (advice-add 'embark--rotate :filter-return
              #'embark-scope--refresh-highlights-on-rotate))


(provide 'embark-scope)
;;; embark-scope.el ends here
