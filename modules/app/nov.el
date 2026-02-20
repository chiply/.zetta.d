(use-package nov
  :config
  (add-to-list 'auto-mode-alist '("\\.epub\\'" . nov-mode))

  (defun my-nov-font-setup ()
    (face-remap-add-relative 'variable-pitch :family "Terminus (TTF)"))
  (add-hook 'nov-mode-hook 'my-nov-font-setup)
  ;;(add-hook 'nov-mode-hook (lambda () (git-gutter-mode -1)))
  ;;(setq nov-unzip-program (executable-find "bsdtar"))
        ;;nov-unzip-args `("-xC" "~/logseq/assets/" "-f" filename))
  ;; NOTE this would have an impact on org-remark probably, so try to pick a sensible default
  (setq nov-text-width t)
  )
