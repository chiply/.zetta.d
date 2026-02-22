;;; emmet-mode.el --- Configure emmet-mode -*- lexical-binding: t; -*-

(use-package emmet-mode
  :after (web-mode js2-mode rjsx-mode)
  :config
  (setq emmet-move-cursor-between-quotes t)

  :general
  (
   :keymaps '(sgml-mode web-mode css-mode rjsx-mode js2-mode)
   "C-<" 'emmet-prev-edit-point
   "C->" 'emmet-next-edit-point
   )

  :hook (
         ((sgml-mode web-mode css-mode rjsx-mode js2-mode) . emmet-mode)
         (rjsx-mode . (lambda () (setq-local emmet-expand-jsx-className? t)))
         (web-mode . (lambda () (setq-local emmet-expand-jsx-className? nil)))
         )
  )
;;; emmet-mode.el ends here
