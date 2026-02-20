(use-package projectile
  :config
  (setq projectile-cache-file (expand-file-name ".data/projectile/projectile.cache" user-emacs-directory)
        (project-known-project-roots)-file (expand-file-name ".data/projectile/projectile-bookmarks.eld" user-emacs-directory)
        projectile-completion-system 'auto
        projectile-project-root-files-bottom-up
        '(".projectile" ".git"))
  (projectile-global-mode)

  )
