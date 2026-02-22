;;; web-mode.el --- Configure web-mode -*- lexical-binding: t; -*-

(use-package web-mode
  :mode (("\\.html?\\'" . web-mode)
         ("\\.vue?\\'" . web-mode)
         ("\\.jinja2?\\'" . web-mode))
  :config
  (setq web-mode-engines-alist
        '(("django"    . "\\.html\\'"))
        web-mode-ac-sources-alist
        '(("css" . (ac-source-css-property))
          ("vue" . (ac-source-words-in-buffer ac-source-abbrev))
          ("html" . (ac-source-words-in-buffer ac-source-abbrev)))
        web-mode-enable-auto-closing t
        web-mode-enable-auto-quoting t) 

  :brushup
  (add-to-list 'brushup-styles
               '(progn
                  (set-face-attribute 'web-mode-folded-face nil
                                      :box t
                                      :underline nil
                                      )))

  :evil (evil-set-initial-state 'web-mode 'normal)

  :general
  (
   :keymaps '(web-mode-map)
   "M-e" 'web-mode-mark-and-expand
   "C-e" 'er/expand-region
   "s-j" 'web-mode-element-next
   "s-k" 'web-mode-element-previous
   "s-C-j" 'web-mode-element-sibling-next
   "s-C-k" 'web-mode-element-sibling-previous
   "s-J" 'web-mode-attribute-next
   "s-K" 'web-mode-attribute-previous
   "s-l" 'emmet-next-edit-point
   "s-L" 'emmet-prev-edit-point
   "s-h" 'web-mode-element-parent
   "s-;" 'web-mode-navigate
   "<C-S-return>" 'browse-url-of-file
   "<S-return>" '(lambda () (interactive)
                   (save-buffer)
                   (eww-open-file (buffer-file-name))))
  (
   :states '(normal visual)
   :keymaps '(web-mode-map)
   "<tab>" 'web-mode-fold-or-unfold
   "S-<tab>" 'web-mode-element-children-fold-or-unfold
   "C-d" 'web-mode-element-kill ;; ie it's subtree
   )

  :hook ((web-mode . (lambda () (smartparens-mode +1)))
         (use-package--web-mode--post-config . zetta-brushup)
         (mhtml-mode . web-mode)
         )
  )
;;; web-mode.el ends here
