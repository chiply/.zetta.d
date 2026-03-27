;;; windmove.el --- Configure windmove -*- lexical-binding: t; -*-

(use-package windmove
  :ensure nil
  :commands (zetta-split-window-v
             zetta-split-window-V
             zetta-split-window-h
             zetta-split-window-H
             windmove-left
             windmove-right
             windmove-down
             windmove-up)
  :config
  (defun zetta-split-window (how)
    (interactive)
    (cond
     ((string= how "v") (split-window-below) (windmove-down))
     ((string= how "V") (split-window-below))
     ((string= how "h") (split-window-right) (windmove-right))
     ((string= how "H") (split-window-right))))

  (defun zetta-split-window-v () (interactive) (zetta-split-window "v"))
  (defun zetta-split-window-h () (interactive) (zetta-split-window "h"))
  (defun zetta-split-window-V () (interactive) (zetta-split-window "V"))
  (defun zetta-split-window-H () (interactive) (zetta-split-window "H"))

  :general
  (
   :keymaps '(override treemacs-mode-map)
   "C-S-a" 'windmove-left
   "C-S-d" 'windmove-right
   "C-S-s" 'windmove-down
   "C-S-w" 'windmove-up
   )
  (
   :keymaps 'menu-window-map
   "v" (repeatable-lite-wrap zetta-split-window-v)
   "V" (repeatable-lite-wrap zetta-split-window-V)
   "h" (repeatable-lite-wrap zetta-split-window-h)
   "H" (repeatable-lite-wrap zetta-split-window-H)
   ;; Emacs 31: new window layout commands (,w l prefix = layout)
   "l r" 'window-rotate
   "l f" 'window-flip
   "l s" 'split-frame
   "l m" 'merge-frames
   )
  )
;;; windmove.el ends here
