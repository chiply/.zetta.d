;;; dbt.el --- Configure dbt-mode -*- lexical-binding: t; -*-

;; A dbt model is SQL with Jinja in it.  dbt-mode
;; (https://github.com/CyberShadow/dbt-mode) is a polymode gluing the two:
;; `sql-mode' is the host -- so everything lang/sql.el and tools/sql.el
;; hang on it still applies -- and `jinja2-mode' takes the {{ }}, {% %}
;; and {# #} spans.  polymode and jinja2-mode arrive as its dependencies.
(use-package dbt-mode
  :ensure (:host github :repo "CyberShadow/dbt-mode")
  :commands dbt-mode

  :init
  ;; The package's own `auto-mode-alist' entry keys on a DIRECTORY name
  ;; (dbt/, queries/, macros/, dbt_modules/): that misses the models/ tree
  ;; of an ordinary project and catches any unrelated queries/ directory.
  ;; What makes a .sql file dbt is the project it sits in.  Added here,
  ;; after the package's autoloads, so this entry is the one in front.
  (defun zetta-sql-or-dbt-mode ()
    "`dbt-mode' for SQL inside a dbt project, plain `sql-mode' elsewhere.
A dbt project is a tree with a dbt_project.yml at its root.  Remote files
are not searched for one."
    (if (and buffer-file-name
             (not (file-remote-p buffer-file-name))
             (locate-dominating-file buffer-file-name "dbt_project.yml"))
        (dbt-mode)
      (sql-mode)))
  (add-to-list 'auto-mode-alist '("\\.sql\\'" . zetta-sql-or-dbt-mode)))
;;; dbt.el ends here
