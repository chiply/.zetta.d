(use-package lin
  :config
  (lin-enable-mode-in-buffers)
  (setq lin-face 'lin-green)
  (setq lin-mode-hooks
        '(bongo-mode-hook
          ;;dired-mode-hook ;; conflicts with background styling
          elfeed-search-mode-hook
          git-rebase-mode-hook
          grep-mode-hook
          ibuffer-mode-hook
          ilist-mode-hook
          ledger-report-mode-hook
          log-view-mode-hook
          magit-log-mode-hook
          mu4e-headers-mode
          notmuch-search-mode-hook
          notmuch-tree-mode-hook
          occur-mode-hook
          org-agenda-mode-hook
          proced-mode-hook
          tabulated-list-mode-hook
          treemacs-mode-hook
          ))

  (lin-global-mode 1)
  )
