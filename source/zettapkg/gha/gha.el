;;; -*- lexical-binding: t -*-

(setq zetta-gh-list-run-command-for-watch "gh run list --json conclusion,databaseId,displayTitle,event,headBranch,name,startedAt,status,updatedAt,workflowDatabaseId --jq ' [.[] | select(.updatedAt > (now - ( 0.1 * 86400))) ]'")
(setq zetta-gh-run-watch-command "gh run watch -i 10 %s; osascript -e 'display notification \"%s %s\" with title \"%s || %s\" sound name \"Frog\"'")
(setq zetta-gh-list-run-command-for-view "gh run list --json conclusion,databaseId,displayTitle,event,headBranch,name,startedAt,status,updatedAt,workflowDatabaseId --jq ' [.[]| select(.updatedAt > (now-( 30 * 86400)))]'")
(setq zetta-gh-view-run-command "gh run view %s --log")

(defun completing-read-value (prompt list)
  (let* ((selected-run-key (let ((vertico-sort-function nil)) (completing-read prompt list))))
    (alist-get selected-run-key list nil nil 'string=)))

(defun zetta-gh-pick-run (dir cmd)
  (interactive)
  (let* ((default-directory dir)
         (json (shell-command-to-string cmd))
         (json-ht (json-parse-string json))
         (runs (zetta-gh-add-keys-to-record json-ht)))
    (completing-read-value "" runs)))

(defun zetta-gh-add-keys-to-record (data)
  (-map
   (lambda (x)
     `(,(mapconcat (lambda (x) (if (numberp x) (number-to-string x) x)) (ht-values x) " ")
       . ,x))
   data))

(defun zetta-gh-run-watch (dir nosleep)
  (interactive)
  (let* ((default-directory dir)
         (run (zetta-gh-pick-run dir (concat (if nosleep "" "sleep 5 && ") zetta-gh-list-run-command-for-watch)))
         (cmd (format zetta-gh-run-watch-command
                      (ht-get run "databaseId")
                      (ht-get run "displayTitle")
                      (concat "on " (ht-get run "headBranch"))
                      (project-name (project-current nil default-directory))
                      (ht-get run "name")))
         (bufnm (format "*GHA run: %s || %s*"
                        (project-name (project-current nil default-directory))
                        (ht-get run "name")))
         (compilation-buffer-name-function `(lambda (_) ,bufnm)))
    (save-window-excursion (compile cmd))
    ;;(zmc-display-output-buffer bufnm 'top 1)
    (display-buffer bufnm)
    ))

(defun zetta-gh-run-view-log (dir)
  (let* ((default-directory dir)
         (run (zetta-gh-pick-run dir zetta-gh-list-run-command-for-view))
         (id (ht-get run "databaseId"))
         (cmd (format zetta-gh-view-run-command id))
         (bufnm (format "*GHA log: %s || %s*"
                        (project-name (project-current nil default-directory))
                        (ht-get run "name"))))
    (shell-command cmd bufnm)
    ;; run (ansi-color-apply-on-region (point-min) (point-max)) in the bufnm
    (with-current-buffer bufnm
      (ansi-color-apply-on-region (point-min) (point-max)))
    ))

;; UI
(defun zetta-gh-run-watch-interact (&optional arg)
  (interactive "P")
  (zetta-gh-run-watch default-directory arg))

(defun zetta-gh-run-view-log-interact ()
  (interactive)
  (zetta-gh-run-view-log default-directory))

(provide 'gha)
