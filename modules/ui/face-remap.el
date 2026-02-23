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
   "=" (repeatable-lite-wrap text-scale-increase)
   "-" (repeatable-lite-wrap text-scale-decrease)
   "+" (repeatable-lite-wrap zetta-big-zoom-in)
   "_" (repeatable-lite-wrap zetta-big-zoom-out)
   )
  )
;;; face-remap.el ends here
