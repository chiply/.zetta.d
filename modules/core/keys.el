;;; keys.el --- Configure keybindings -*- lexical-binding: t; -*-

(general-define-key
 :keymaps 'override
 "C-s" 'save-buffer
 ;; VS Code's command palette.  Spelled "s-P" rather than "s-S-p": for an
 ;; ASCII letter macOS folds Shift into the character itself, so Cmd+Shift+P
 ;; arrives as super + capital P -- [8388688], where "s-S-p" is [41943152],
 ;; an event the keyboard never sends.  Same convention as the "s-V"
 ;; `vertico-repeat' binding in completion/vertico.el.
 ;;
 ;; The palette look is the other half of this: `execute-extended-command'
 ;; opens in a top-centred posframe, see `vertico-multiform-commands' in
 ;; completion/vertico.el.
 "s-P" 'execute-extended-command)

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
