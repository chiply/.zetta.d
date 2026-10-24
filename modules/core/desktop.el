;;; desktop.el --- Configure desktop -*- lexical-binding: t; -*-

(use-package desktop
  :ensure nil
  :config
  (setq desktop-base-file-name (expand-file-name ".data/desktop/.emacs.desktop" user-emacs-directory))
  (setq desktop-restore-frames nil)
  (setq desktop-load-locked-desktop t)
  ;; The directory never existed, so every 30 idle seconds Emacs built the
  ;; desktop state of ~90 buffers and then failed to write it (found
  ;; 2026-09-08).  Create it; restore the first ten buffers eagerly and the
  ;; rest while idle, rather than all of them before the first frame.
  (make-directory (file-name-directory desktop-base-file-name) t)
  (setq desktop-restore-eager 10)
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
;;; desktop.el ends here
