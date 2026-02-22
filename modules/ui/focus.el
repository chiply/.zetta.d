;;; focus.el --- Configure focus -*- lexical-binding: t; -*-

(use-package focus
  :commands focus-mode

  :init
  (defun zetta-focus-mode (thing)
    "Thing is a quoted symbol"
    (setq-local focus-current-thing thing))


  :brushup
  (add-to-list
   'brushup-styles
   '(progn
      (set-face-attribute 'focus-unfocused nil
                          ;;:height 1.0
                          :foreground
                          (if brushup-dark-p
                              (color-lighten-name brushup-bg 20)
                            (color-lighten-name brushup-bg -35)))
      ;;(set-face-attribute 'focus-focused nil :height 1.0)
      ))

  (add-to-list 'focus-mode-to-thing '(python-ts-mode . lsp-folding-range))


  :general
  (
   :keymaps 'menu-window-map
   "C-f" (** focus-mode)
   )


  ;;:hook (((prog-mode) . (lambda () (focus-mode)))
         ;;(emacs-lisp-mode . (lambda () (zetta-focus-mode 'defun)))
         ;;((python-ts-mode sql-mode yaml-mode sh-mode) . (lambda () (zetta-focus-mode 'defun))))
  ;;(use-package--focus--post-config . (lambda () (zetta-brushup))))
  )
;;; focus.el ends here
