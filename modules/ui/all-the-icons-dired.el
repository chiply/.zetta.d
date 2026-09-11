;;; all-the-icons-dired.el --- Configure all-the-icons-dired -*- lexical-binding: t; -*-

(use-package all-the-icons-dired
  :init
  (defun zetta-enable-dired-icons-maybe ()
    (unless (file-remote-p default-directory)
      (all-the-icons-dired-mode)
      )
    )

  ;; Off, so that a file icon is drawn in its own extension colour --
  ;; the one `zetta-icons-refresh-colors' (modules/ui/all-the-icons.el)
  ;; has remapped onto the theme's palette.  On, which is the package
  ;; default, every file icon is requested with `:face (face-at-point)'
  ;; and comes out in the dired line's own colour, so dired stayed
  ;; monochrome while the minibuffer completions were coloured.
  ;;
  ;; Directories are unaffected either way: the package always draws them
  ;; in `all-the-icons-dired-dir-face', which the :brushup form below
  ;; pins to the ink ladder, so folders stay neutral furniture and the
  ;; colour in a listing means file type.
  :config
  (setq all-the-icons-dired-monochrome nil)

  :brushup
  (add-to-list 'brushup-styles
               '(set-face-attribute 'all-the-icons-dired-dir-face nil
                                    :height 1.0
                                    :foreground brushup-fg-3))

  :hook ((dired-mode . (lambda () (zetta-enable-dired-icons-maybe)))
         (use-package--all-the-icons-dired--post-config . (lambda () (brushup))))
  )
;;; all-the-icons-dired.el ends here
