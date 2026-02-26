;;; keys.el --- Configure keybindings -*- lexical-binding: t; -*-

(general-define-key
 :keymaps 'override
 "C-s" 'save-buffer)

(general-define-key
 :keymaps 'launch-map
 ;;"o" 'hydra-org/body
 "x" 'execute-extended-command
 "F" 'find-file
 "k" 'kill-current-buffer)

(with-eval-after-load 'evil
  (general-define-key
   :keymaps '(evil-insert-state-map
              evil-normal-state-map
              evil-visual-state-map
              evil-motion-state-map)
   "C-e" nil))

(general-define-key
 :keymaps '(pubmed-mode-map)
 "<return>" 'pubmed-show-current-entry
 "<tab>" 'pubmed-bibtex-show
 "f" 'pubmed-get-fulltext
 "s" 'pubmed-search
 )

(with-eval-after-load 'web-mode
  (general-unbind :states '(normal visual) :keymaps '(web-mode-map) "C-e"))
;;; keys.el ends here
