;;; color-identifiers-mode.el --- Configure color-identifiers-mode -*- lexical-binding: t; -*-

;; inspired by https://medium.com/@evnbr/coding-in-color-3a6db2743a1e
(use-package color-identifiers-mode
  :config
  ;; NOTE need to add some modes
  (add-to-list 'color-identifiers:modes-alist
               '(python-ts-mode "\\(?:[^.]\\|^\\)[[:space:]]*"
                                "\\_<\\([a-zA-Z_$]\\(?:\\s_\\|\\sw\\)*\\)"
                                (nil font-lock-variable-name-face
                                     tree-sitter-hl-face:variable)))
  (global-color-identifiers-mode)
  ;; NOTE takes a while to kick in, not sure why.  don't want to
  ;; wastefully bind it to post-commad hook.  I can live with the
  ;; issue
  )
;;; color-identifiers-mode.el ends here
