;;; tap-fold.el --- Type-aware folding via overlay invisibility -*- lexical-binding: t; -*-

;; Folds spans by *type* using overlay invisibility.  Works alongside
;; kirigami: kirigami unifies the structural backends (outline / hs /
;; treesit-fold / org / ...), this layer folds the bounds of any
;; thing-at-point thing or embark target.  Universal: paragraph,
;; sentence, defun, sexp, function, orgtree, brick, etc.
;;
;; Because the underlying mechanism is just overlay invisibility, folds
;; are NOT line-snapped -- a sentence inside a line can be folded with
;; the rest of the line still visible (ellipsis in place of the
;; hidden span).

(require 'thingatpt)

(defgroup zetta-fold nil
  "Type-aware folding."
  :group 'editing)

(defconst zetta-fold--spec 'zetta-fold
  "Symbol used as the `invisible' property value on our overlays
and as the spec entry added to `buffer-invisibility-spec'.")

(defcustom zetta-fold-things
  '(paragraph sentence defun sexp word line brick orgtree)
  "Things prompted for by `zetta-fold-thing-at-point' when called
interactively. Any symbol that `bounds-of-thing-at-point' can
resolve works."
  :type '(repeat symbol))

(defun zetta-fold--ensure-spec ()
  "Add `zetta-fold--spec' to `buffer-invisibility-spec' with
ellipsis enabled, idempotently."
  (let ((entry (cons zetta-fold--spec t)))
    (cond
     ((eq buffer-invisibility-spec t)
      ;; t means "everything invisible" -- replace with a list
      ;; that includes our entry plus t for back-compat semantics.
      (setq buffer-invisibility-spec (list entry)))
     ((not (member entry buffer-invisibility-spec))
      (add-to-invisibility-spec entry)))))

(defun zetta-fold--overlay-at (pos)
  "Return our fold overlay at POS, or nil. Checks both POS and
POS-1 so point-on-the-ellipsis works."
  (or (cl-find-if (lambda (ov) (overlay-get ov 'zetta-fold))
                  (overlays-at pos))
      (and (> pos (point-min))
           (cl-find-if (lambda (ov) (overlay-get ov 'zetta-fold))
                       (overlays-at (1- pos))))))

(defun zetta-fold-region (beg end)
  "Fold the region BEG..END with an invisibility overlay.
Returns the overlay."
  (interactive "r")
  (zetta-fold--ensure-spec)
  (let ((ov (make-overlay beg end nil t nil)))
    (overlay-put ov 'invisible zetta-fold--spec)
    (overlay-put ov 'zetta-fold t)
    (overlay-put ov 'isearch-open-invisible #'delete-overlay)
    (overlay-put ov 'evaporate t)
    ov))

(defun zetta-unfold-at-point ()
  "Remove the fold overlay enclosing point, if any."
  (interactive)
  (if-let* ((ov (zetta-fold--overlay-at (point))))
      (progn (delete-overlay ov)
             (message "Unfolded"))
    (message "No fold at point")))

(defun zetta-unfold-all ()
  "Remove every zetta-fold overlay in the current buffer."
  (interactive)
  (let ((count 0))
    (dolist (ov (overlays-in (point-min) (point-max)))
      (when (overlay-get ov 'zetta-fold)
        (delete-overlay ov)
        (cl-incf count)))
    (message "Cleared %d fold(s)" count)))

(defun zetta-fold-thing (thing)
  "Fold the bounds of THING at point. Non-interactive primitive."
  (if-let* ((b (ignore-errors (bounds-of-thing-at-point thing))))
      (zetta-fold-region (car b) (cdr b))
    (user-error "No `%s' at point" thing)))

(defface zetta-fold-preview-face
  '((((background dark))  :background "#3a2a00" :extend nil)
    (((background light)) :background "#fff3b0" :extend nil))
  "Face used to highlight the candidate bounds in
`zetta-fold-thing-at-point''s consult preview.")

(defvar-local zetta-fold--preview-overlay nil
  "One-shot preview overlay during `zetta-fold-thing-at-point'.")

(defun zetta-fold--clear-preview ()
  (when (overlayp zetta-fold--preview-overlay)
    (delete-overlay zetta-fold--preview-overlay))
  (setq zetta-fold--preview-overlay nil))

(defun zetta-fold--candidates-at-point ()
  "Return alist of (NAME . (BEG . END)) for each thing in
`zetta-fold-things' that has bounds at point."
  (delq nil
        (mapcar (lambda (thing)
                  (when-let* ((b (ignore-errors
                                   (bounds-of-thing-at-point thing))))
                    (when (and (car b) (cdr b) (< (car b) (cdr b)))
                      (cons (symbol-name thing) b))))
                zetta-fold-things)))

(defun zetta-fold-thing-at-point ()
  "Pick a thing at point with consult and fold its bounds.
Only things whose `bounds-of-thing-at-point' returns a real span
at point appear as candidates. Preview paints the candidate's
bounds with `zetta-fold-preview-face' so you can see exactly what
would be folded before committing."
  (interactive)
  (let ((candidates (zetta-fold--candidates-at-point)))
    (cond
     ((null candidates)
      (user-error "Nothing foldable at point"))
     (t
      (unwind-protect
          (let* ((choice
                  (consult--read
                   (mapcar #'car candidates)
                   :prompt "Fold: "
                   :require-match t
                   :sort nil
                   :state
                   (lambda (action cand)
                     (pcase action
                       ('preview
                        (zetta-fold--clear-preview)
                        (when (and cand (stringp cand))
                          (when-let* ((b (cdr (assoc cand candidates))))
                            (let ((ov (make-overlay (car b) (cdr b))))
                              (overlay-put ov 'face
                                           'zetta-fold-preview-face)
                              (overlay-put ov 'priority 100)
                              (setq zetta-fold--preview-overlay ov))))) ))))
                 (b (cdr (assoc choice candidates))))
            (when b (zetta-fold-region (car b) (cdr b))))
        (zetta-fold--clear-preview))))))

(defun zetta-fold-toggle-thing-at-point (thing)
  "If there's a fold at point, unfold it; otherwise fold THING here."
  (interactive
   (list (intern (completing-read
                  "Fold thing: "
                  (mapcar #'symbol-name zetta-fold-things)
                  nil nil))))
  (if (zetta-fold--overlay-at (point))
      (zetta-unfold-at-point)
    (zetta-fold-thing thing)))

(defun zetta-fold-current-thing ()
  "Fold `zetta-tap-current-thing' at point, if set."
  (interactive)
  (cond
   ((not (and (boundp 'zetta-tap-current-thing) zetta-tap-current-thing))
    (user-error "`zetta-tap-current-thing' is not set"))
   (t (zetta-fold-thing zetta-tap-current-thing))))

;; ----------------------------------------------------------------------
;; Embark integration: fold the active embark target's bounds.
;; ----------------------------------------------------------------------

(with-eval-after-load 'embark
  (defun zetta-embark-fold ()
    "Fold the active embark target's bounds. Captured by the
`:always' pre-action hook in `embark.el', so works for any
bounded target."
    (interactive)
    (if-let* ((b (and (boundp 'zetta-embark--current-target-bounds)
                      zetta-embark--current-target-bounds)))
        (zetta-fold-region (car b) (cdr b))
      (message "No bounds on active target")))

  (define-key embark-general-map (kbd "C-z") #'zetta-embark-fold))

;; ----------------------------------------------------------------------
;; Top-level bindings on the launch-map (s-x prefix).  Mirrors the
;; pattern used by zetta-embark-jump-to-type / -avy-jump-to-type.
;; ----------------------------------------------------------------------

(with-eval-after-load 'general
  (general-define-key
   :keymaps '(sql-mode-map lisp-mode-map lisp-interaction-mode-map
              emacs-lisp-mode-map elisp python-ts-mode-map
              yaml-mode-map sh-mode-map shell-command-mode-map
              lark-mode-map org-mode-map text-mode-map)
   "s-x f" #'zetta-fold-thing-at-point
   "s-x F" #'zetta-unfold-at-point
   "s-x M-f" #'zetta-unfold-all
   "s-x C-f" #'zetta-fold-current-thing))

(provide 'tap-fold)
;;; tap-fold.el ends here
