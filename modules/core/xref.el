;;; xref.el --- Configure xref -*- lexical-binding: t; -*-

(use-package xref
  :ensure nil
  :init
  ;; `project-find-regexp' and friends shell out to this when no xref
  ;; backend answers; rg is already what consult uses.  grep stays where
  ;; rg is not installed (the hub).
  (setq xref-search-program (if (executable-find "rg") 'ripgrep 'grep))
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
