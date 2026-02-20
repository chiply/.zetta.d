;; -*- lexical-binding: t; -*-

;;; Searching logseq todo headings
;; Functions zetta-logseq-todo-files and related are defined in bootstrap-org.el

(defun zetta-logseq-search-headings ()
  "Search through headings in all logseq (todo) files using org-ql-find."
  (interactive)
  (let ((files (zetta-logseq-todo-files)))
    (if files
        (org-ql-find files)
      (message "No (todo) files found in %s" zetta-logseq-pages-dir))))

(defun zetta-logseq-search-todos ()
  "Search through TODO items in all logseq (todo) files."
  (interactive)
  (let ((files (zetta-logseq-todo-files)))
    (if files
        (org-ql-search files '(todo))
      (message "No (todo) files found in %s" zetta-logseq-pages-dir))))

(defun zetta-logseq-consult-headings ()
  "Search headings in logseq (todo) files using consult."
  (interactive)
  (let ((files (zetta-logseq-todo-files)))
    (if files
        (consult-org-heading nil files)
      (message "No (todo) files found in %s" zetta-logseq-pages-dir))))

;; Keybindings for logseq search commands
(general-define-key
 :keymaps 'launch-map
 :prefix "o"
 "s" 'zetta-logseq-search-headings
 "t" 'zetta-logseq-search-todos
 "h" 'zetta-logseq-consult-headings)
