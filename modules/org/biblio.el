;; zetta-literature-dir is defined in bootstrap-modules.el
(use-package biblio
  :config
  (setq biblio-download-directory (expand-file-name "pdf/" zetta-literature-dir))
  )
