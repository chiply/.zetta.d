;;; vimish-fold.el --- Configure vimish-fold -*- lexical-binding: t; -*-

;; Kirigami (modules/editor/kirigami.el) owns the unified `z'-prefix
;; folding bindings now.  Vimish-fold remains installed for ad-hoc
;; region folding via M-x or future custom bindings; the `:general'
;; block was removed during the migration and is intentionally left
;; for you to re-wire as desired.  The `zetta-vimish-fold-tap' helper
;; is preserved below.

(use-package vimish-fold
  :commands (vimish-fold
             vimish-fold-mode
             vimish-fold-toggle
             vimish-fold-toggle-all
             vimish-fold-avy
             vimish-fold-delete
             vimish-fold-delete-all
             vimish-fold-next-fold
             vimish-fold-previous-fold
             vimish-fold-refold-all
             vimish-fold-unfold-all
             zetta-vimish-fold-tap)
  :init
  (defun zetta-vimish-fold-tap (&optional thing)
    "If fold exists within tap, then toggle, otherwise create fold
around tap.  If region active, then fold in this region.  If active
folds in tap (eg tap itself isn't what is folded, but rather a subset
of tap), then toggle the closest fold"
    (interactive)
    (let* ((bnds (treesit-tap-locate-thing thing))
           (beg-thing (nth 0 bnds))
           (end-thing (nth 1 bnds))
           (bol (save-excursion (back-to-indentation) (point)))
           (eol (save-excursion (end-of-line) (point)))
           (cur-point (point)))
      (if (region-active-p)
          ;; when region is active
          (progn
            (when (vimish-fold--folds-in beg-thing end-thing)
              (vimish-fold-delete))
            (vimish-fold (region-beginning) (region-end)))
        ;; when region is not active
        (condition-case nil
            (cond
             ;; at fold, toggle
             ((vimish-fold--folds-in bol eol)
              ;; toggle
              (vimish-fold-toggle))
             ;; not at fold, and multiple folds within thing
             ((and
               (not (vimish-fold--folds-in bol eol))
               (<= 1 (length (vimish-fold--folds-in beg-thing end-thing))))
              ;; toggle closest fold within thing at point
              (let* ((overlay-points (-map (lambda (overlay) (ov-beg overlay))
                                           (vimish-fold--folds-in beg-thing end-thing)))
                     (overlay-points-prev (-filter (lambda (num) (> 0 (- num (point))))
                                                   overlay-points))
                     (overlay-points-next (-filter (lambda (num) (< 0 (- num (point))))
                                                   overlay-points))
                     (prev-point (if overlay-points-prev (-max overlay-points-prev) nil))
                     (next-point (if overlay-points-next (-min overlay-points-next) nil))
                     (surrounding-points (-non-nil `(,prev-point ,next-point)))
                     (surrounding-lines (-map (lambda (pt)
                                                (line-number-at-pos pt))
                                              surrounding-points))
                     (current-line (line-number-at-pos (point)))
                     (closest-line (-min-by
                                    (-on #'> #'(lambda (num) (abs (- current-line num))))
                                    surrounding-lines)))
                (save-excursion (goto-line closest-line) (vimish-fold-toggle))
                )
              )
             ;; no fold in thing
             ((not (vimish-fold--folds-in beg-thing end-thing))
              ;; fold thing
              (vimish-fold beg-thing end-thing))
             )
          (error (vimish-fold-toggle))
          )
        )
      )
    )

  (setq vimish-fold-header-width 70))
;;; vimish-fold.el ends here
