(use-package vimish-fold
  :commands (vimish-fold vimish-fold-mode vimish-fold-toggle vimish-fold-avy)
  :init
  (defun zetta-vimish-fold-tap (&optional thing)
    "If fold exists within tap, then toggle, otherwise create fold
around tap.  If region active, then fold in this region.  If active
folds in tap (eg tap itself isn't what is folded, but rather a subset
of tap), then toggle the closest fold"
    (interactive)
    (let* ((bnds (zetta-locate-thing thing))
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

  (setq vimish-fold-header-width 70)

  :general
  (
   :states '(normal visual)
   :prefix "z"
   "z" 'vimish-fold-avy
   "t" 'vimish-fold-toggle
   "T" 'vimish-fold-toggle-all
   "d" 'vimish-fold-delete
   "D" 'vimish-fold-delete-all
   "j" 'vimish-fold-next-fold
   "k" 'vimish-fold-previous-fold
   "m" 'vimish-fold-mode
   "f" 'vimish-fold-refold-all
   "F" 'vimish-fold-unfold-all
   )
  (
   :states '(normal)
   :keymaps '(
              python-ts-mode-map emacs-lisp-mode-map
              lisp-interaction-mode-map sql-mode-map yaml-mode-map
              css-mode-map dockerfile-mode-map terraform-mode-map)
   "<tab>" 'zetta-vimish-fold-tap
   "<S-tab>" 'vimish-fold-toggle-all
   )
  )
