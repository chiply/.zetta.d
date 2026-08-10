;;; expand-region.el --- Configure expand-region -*- lexical-binding: t; -*-

(use-package expand-region
  :general
  (:states '(normal visual)
   :keymaps '(org-mode-map org-agenda-mode-map sql-mode-map
              python-ts-mode-map lisp-interaction-mode-map
              emacs-lisp-mode-map lisp-mode-map dired-mode-map
              snippet-mode-map shell-command-mode-map vterm-mode-map
              embark-collect-mode-map wgrep-mode-map csv-mode-map
              help-mode-map helpful-mode-map text-mode-map
              pubmed-show-mode-map json-mode-map eww-mode-map
              messages-buffer-mode-map
              jmespath-mode-map jsonian-mode-map js2-mode-map
              compilation-mode-map lark-mode-map css-mode-map
              fundamental-mode-map lisp-data-mode-map prog-mode-map)
   "C-e" 'er/expand-region))

;;; expand-region.el ends here
