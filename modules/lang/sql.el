

(use-package sql
  :ensure nil
  :commands (sql-mode sql-interactive-mode sql-connect)

  :display
  ;;(zetta-side "^\\*sql--*" 'top)
  

  :general
  (
   :states '(normal visual)
   :keymaps 'sql-mode-map
   "==" '(lambda () (interactive) (save-excursion (evil-indent (point-min) (point-max))))
   )

  :hook (
         (sql-interactive-mode . (lambda () (toggle-truncate-lines t)))
         ((sql-mode sql-interactive-mode) . (lambda () (sqlind-minor-mode)))
         )
  )

(use-package sql-indent
  :after (sql)

  :hook (sql-mode . sqlind-minor-mode)
  )


(use-package sqlup-mode
  ;; todo
  :hook (sql-mode . sqlup-mode)
  )
