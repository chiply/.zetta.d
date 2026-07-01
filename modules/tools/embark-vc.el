;;; embark-vc.el --- Configure embark-vc -*- lexical-binding: t; -*-

(use-package embark-vc
  :after (pr-review consult-gh)
  :config
  (setq embark-vc-review-provider 'pr-review)
  (general-define-key
   :keymaps '(consult-gh-embark-prs-edit-menu-map)
   "R" 'embark-vc-start-review)

  ;; Make the forge topic the DEFAULT embark target on a PR/issue line.
  ;;
  ;; `embark-vc-target-topic-at-point' returns an UNBOUNDED target (no
  ;; START . END).  Our `embark-scope-sort-by-bounds-mode' installs a
  ;; `:filter-return' advice on `embark--targets' that sorts bounded targets
  ;; innermost-first and appends every unbounded target at the very END of the
  ;; cycle (see `embark-scope--sort-targets-by-bounds').  So on a PR line the
  ;; default target was always a scope target (line/brick/word/...), never the
  ;; `pull-request' -- `embark-act' then `r' hit the general map, where `r' is
  ;; unbound, and fell through to `magit-rebase'.
  ;;
  ;; Fix: a drop-in finder that returns the SAME topic target WITH bounds -- the
  ;; `#N' reference when point is on it, else a zero-width span at line start
  ;; (size 0, so it sorts first).  Now `pull-request'/`issue' is the default
  ;; target anywhere on the line, and `C-.' then `r' opens the PR in pr-review.
  (defun zetta-embark-vc-target-topic-at-point ()
    "Target the forge topic at point, WITH bounds (see comment above)."
    (when (and (derived-mode-p 'magit-mode)
               (fboundp 'forge-topic-at-point))
      (when-let* ((topic (forge-topic-at-point)))
        (let* ((type (if (and (fboundp 'forge-issue-at-point)
                              (forge-issue-at-point))
                         'issue 'pull-request))
               (beg (line-beginning-position))
               (bounds (or (ignore-errors (bounds-of-thing-at-point 'forge-topic))
                           (cons beg beg))))
          `(,type ,(oref topic number) ,(car bounds) . ,(cdr bounds))))))
  ;; Swap our bounded finder in for embark-vc's unbounded one.
  (setq embark-target-finders
        (cons 'zetta-embark-vc-target-topic-at-point
              (remq 'embark-vc-target-topic-at-point embark-target-finders)))
  )
;;; embark-vc.el ends here
