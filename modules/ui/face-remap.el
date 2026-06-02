;;; face-remap.el --- Configure face-remap -*- lexical-binding: t; -*-

(use-package face-remap
  :ensure nil
  :config
  (setq text-scale-mode-step 1.2)

  (defun zetta-big-zoom-in ()
    (interactive)
    (if (< text-scale-mode-amount 4)
        (text-scale-set 4)
      (text-scale-set 0)))

  (defun zetta-big-zoom-out ()
    (interactive)
    (if (> text-scale-mode-amount -4)
        (text-scale-set -4)
      (text-scale-set 0)))

  :general
  (
   :keymaps 'menu-window-map
   "=" (repeatable-wrap text-scale-increase)
   "-" (repeatable-wrap text-scale-decrease)
   "+" (repeatable-wrap zetta-big-zoom-in)
   "_" (repeatable-wrap zetta-big-zoom-out)
   )
  )
;;; face-remap.el ends here
