(defun zetta-sql-set-engine (arg)
  (interactive "P")
  (let ((engine (if (or arg
                        (not (boundp 'zetta-sql-engine)))
                    (ido-completing-read "Please enter a source: " '("oracle" "sqlite"))
                  (message zetta-sql-engine))))
    (setq-local zetta-sql-engine engine)))

(defun zetta-sqlite-set-dbfile (arg)
  (interactive "P")
  (let* ((dbs (-filter
               (lambda (x) (member "db" (split-string x "\\.")))
               (split-string (shell-command-to-string "ls") "\n")))
         (dbfile (if (or arg
                         (not (boundp 'zetta-sqlite-dbfile)))
                     (ido-completing-read "Please enter a source: " dbs)
                   (message zetta-sqlite-dbfile))))
    (setq-local zetta-sqlite-dbfile dbfile)))

(defun zetta-set-async-output-buffer-for-buffer (&optional arg)
  (let* ((user-tag (if (or arg (not (boundp 'zetta-output-buffer-for-buffer)))
                       (completing-read "Name the output buffer: " (-map (lambda (x) (buffer-name x))
                                                                         (zetta-soda-list-mode-buffers "shell-command-mode")))
                     zetta-output-buffer-for-buffer))

         (buffer-name (if (string-match "*sql--" user-tag)
                          user-tag
                        (concat "*sql--" user-tag "*"))))
    (setq-local zetta-output-buffer-for-buffer buffer-name)))

(setq zetta-python-exec-sqlite-sql (concat "sqlite3 ${db} < .tmp_code.sql"))

(defun zetta-dql-sqlite (arg)
  "Returns a 2 length list representing the bounds for
   either the entire buffer or the REGION"
  (interactive "P")
  ;; not ideal to reset both at the same time, but okay for now
  (zetta-sqlite-set-dbfile arg)
  (zetta-set-async-output-buffer-for-buffer arg)
  (let ((bounds (if (use-region-p)
                    (cons (region-beginning) `(,(region-end)))
                  (cons (point-at-bol) `(,(point-at-eol))))))
    (write-region (nth 0 bounds) (nth 1 bounds) "./.tmp_code.sql" nil)
    (async-shell-command (s-format zetta-python-exec-sqlite-sql 'aget `(("db" . ,zetta-sqlite-dbfile))) zetta-output-buffer-for-buffer)))
