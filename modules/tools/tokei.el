(use-package tokei
  :config
  ;; overwriting the tokei function to allow for display buffer
  (defun tokei ()
    "Show codebase statistics."
    (interactive)
    (unless (executable-find tokei-program)
      (user-error "Command not found: %s" tokei-program))
    ;; this is the part that changed
    (let ((buf (get-buffer-create "*tokei*")))
      (with-current-buffer buf
        (tokei-mode)
      )
      (display-buffer buf)
      )
    )

  :display
  ;;(zetta-side "tokei-mode" 'right 1)
  )
