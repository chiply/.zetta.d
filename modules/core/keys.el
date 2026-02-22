;;; keys.el --- Configure keybindings -*- lexical-binding: t; -*-

(general-define-key
 :keymaps 'override
 "C-s" 'save-buffer)

(general-define-key
 :keymaps 'launch-map
 ;;"o" 'hydra-org/body
 "b" 'consult-buffer
 "B" 'consult-buffer
 "x" 'execute-extended-command
 "f" 'consult-project-extra-find
 "F" 'find-file
 "k" 'kill-current-buffer)

(general-define-key
 :keymaps '(evil-insert-state-map
            evil-normal-state-map
            evil-visual-state-map
            evil-motion-state-map)
 "C-e" nil
 )

(general-define-key
 :keymaps '(pubmed-mode-map)
 "<return>" 'pubmed-show-current-entry
 "<tab>" 'pubmed-bibtex-show
 "f" 'pubmed-get-fulltext
 "s" 'pubmed-search
 )

(general-unbind
  :states '(normal visual)
  :keymaps '(web-mode-map)
  "C-e")
;;; keys.el ends here
