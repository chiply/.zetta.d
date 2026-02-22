;;; image-mode.el --- Configure image-mode -*- lexical-binding: t; -*-

(use-package image-mode
  :ensure nil
  :commands image-mode
  :config
  (defun zetta-image-mode-eaf-open ()
    (interactive)
    (eaf-open (buffer-file-name (current-buffer)))
    )

  :general
  (
   :keymaps 'image-mode-map
   "<C-return>" 'zetta-image-mode-eaf-open
   )
  )
;;; image-mode.el ends here
