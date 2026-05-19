;;; narrow.el --- Configure narrowing -*- lexical-binding: t; -*-

(defun zetta-narrow-to-fold-dwim ()
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
    (narrow-to-region beg-thing end-thing)
    ))

(defun zetta-narrow-or-widen (p)
  ;; note that narrowing adds artifical space to beginning and end,
  ;; it's practical to be aware of the effects of this
  (interactive "P")
  (declare (interactive-only))
  (cond
   ;; if already narrowed, then widen
   ((and (buffer-narrowed-p) (not p)) (widen))
   ;; if region is active, then narrow to region
   ((region-active-p)
    (narrow-to-region (region-beginning) (region-end)))
   ;; in org mode
   ((derived-mode-p 'org-mode)
    (cond ((ignore-errors (org-edit-src-code))
           (delete-other-windows))
          ((org-at-block-p)
           (org-narrow-to-block))
          (t (org-narrow-to-subtree))))
   ;; on a fold
   ((and
     (boundp 'vimish-fold--folds-in)
     (vimish-fold--folds-in (point-at-bol) (point-at-eol)))
    (let* ((fold (nth 0 (vimish-fold--folds-in (point-at-bol) (point-at-eol))))
           (fold-at-point fold)
           ;; if at first thing, take 1 as lower bound, otherwise
           ;; beginning of thing - 1.
           (beg (if (zetta-thing-at-bobp)
                    1
                  (- (ov-beg fold-at-point) 1)))
           (end (if (zetta-thing-at-eobp)
                    (save-excursion (end-of-buffer) (point))
                  (+ 1 (ov-end fold-at-point))))
           )
      (narrow-to-region beg end)
      )
    )
   (t
    (let (
          ;; if at first thing, take 1 as lower bound, otherwise
          ;; beginning of thing - 1.
          (beg (if (zetta-thing-at-bobp)
                   1
                 (save-excursion
                   (beginning-of-thing zetta-tap-current-thing)
                   ;; in case there is indentation
                   (beginning-of-line)
                   (- (point) 1)
                   )))
          (end (if (zetta-thing-at-eobp)
                   (save-excursion (end-of-buffer) (point))
                 (+ 1 (cdr (bounds-of-thing-at-point zetta-tap-current-thing)))))
          )
      (narrow-to-region beg end)
      )
    ))
  )

(general-define-key
 :keymaps '(override)
 "s-n" 'zetta-narrow-or-widen
 )
;;; narrow.el ends here
