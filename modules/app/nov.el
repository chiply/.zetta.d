;;; nov.el --- Configure nov -*- lexical-binding: t; -*-

(use-package nov
  :config
  (add-to-list 'auto-mode-alist '("\\.epub\\'" . nov-mode))

  ;; nov renders into `variable-pitch', which fontaine already sets per
  ;; preset -- remapping it to a fixed family here defeated that.  Left as a
  ;; no-op hook so the intent (and the way back) stays visible.
  (defun my-nov-font-setup ()
    "Formerly pinned `variable-pitch' to Terminus; now follows the preset."
    nil)
  (add-hook 'nov-mode-hook 'my-nov-font-setup)
  ;;(add-hook 'nov-mode-hook (lambda () (git-gutter-mode -1)))
  ;;(setq nov-unzip-program (executable-find "bsdtar"))
        ;;nov-unzip-args `("-xC" "~/logseq/assets/" "-f" filename))
  ;; NOTE this would have an impact on org-remark probably, so try to pick a sensible default
  (setq nov-text-width t)
  )
;;; nov.el ends here
