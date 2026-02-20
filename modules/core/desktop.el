(use-package desktop
  :ensure nil
  :config
  (setq desktop-base-file-name (expand-file-name ".data/desktop/.emacs.desktop" user-emacs-directory))
  (setq desktop-restore-frames nil)
  (setq desktop-load-locked-desktop t)
  (desktop-save-mode 1)

  (defun zetta-desktop-buffers-not-to-save-function (fnm bufnm mode &rest rest)
    nil
    )
  (setq desktop-buffers-not-to-save-function 'zetta-desktop-buffers-not-to-save-function)

  (defun zetta-desktop-save ()
    (interactive)
    (desktop-save user-emacs-directory))

  (defun zetta-server-shutdown-save-desktop ()
    (interactive)
    (zetta-desktop-save)
    (server-shutdown))
  )
