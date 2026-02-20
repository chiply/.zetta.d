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

;;(let ((theme (car custom-enabled-themes)))
  ;;(when theme
    ;;(mapcar (lambda (face)
              ;;(cons (symbol-name face) (face-foreground face)))
            ;;(face-list))))




