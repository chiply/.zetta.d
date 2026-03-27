;;; xref.el --- Configure xref -*- lexical-binding: t; -*-

(use-package xref
  :ensure nil
  :commands (xref-find-definitions xref-go-back xref-go-forward)
  :config
  ;;(zetta-side "^\\*xref*" 'right -1)

  ;; Emacs 31: control-click to jump to definition (VSCode-style)
  (when (fboundp 'global-xref-mouse-mode)
    (global-xref-mouse-mode 1))

  :general
  (
   ;; just override doesn't work
   :keymaps '(meow-normal-state-keymap evil-normal-state-map)
   "M-." 'xref-find-definitions
   "M-," 'xref-go-back
   ;; note the distinct use from find-definitions.  This is more about
   ;; history traveersal
   "C-M-," 'xref-go-forward
   )
  )
;;; xref.el ends here
