(defun convention-prompt-for-container-name-user-postfix (container-name)
  "Returns a string representing a postfic for a particular container"
  (completing-read (concat "Enter a name for your process buffer: " container-name "-") ()))

(defun convention-format-process-buffer-name (container-name)
  "Returns a string representing the name of a process buffer containing
   a repl connected to a container"
  (let ((container-name-user-postfix (convention-prompt-for-container-name-user-postfix container-name)))
    (s-format convention-docker-process-buffer-name
              'aget `(("container-name" . ,container-name)
                      ("container-name-user-postfix" . ,container-name-user-postfix)))))

(defun convention-prompt-for-container-command (container-name)
  "Returns a string representing the command to be sent to a container
   when docker exec-ing into it"
  (let ((default-repl-list (convention-query-lang-info container-name "default-repl-list")))
    (completing-read
     "Command to send to container: " default-repl-list)))

(defun convention-start-process (buffer-name)
  "Starts an ansi term process in which a docker exec ... command will be
   executed"
  (let ((host (4mn-get-tramp-context--hostname)))
    (cond
     ;; when on remote
     ((member "ssh" (4mn-get-tramp-hop-types))
      ;; then create the buffer on local and docker exec into container
      (let ((default-directory "~/"))
        (with-current-buffer (get-buffer-create buffer-name)
          (vterm-mode)
          (setq-local foreman-ssh t)
          (setq-local foreman-docker t))
        (process-send-string buffer-name (format "ssh %s \n" host))
        ))
     ;; then just create the buffer as usual
     (t
      (with-current-buffer (get-buffer-create buffer-name)
        (vterm-mode)
        (setq-local foreman-ssh nil)
        (setq-local foreman-docker t)))
     )
    )
  )

(defun convention-prompt-for-sql-cli-type ()
  "Returns a string representing a cli type for a database engine.  The options are
   default, which will be the default cli interface (usually comes with the database engine),
   and dbcli, which will be the corresponding dbli tool for the specific database engine"
  (completing-read "Use default cli interface or dbcli? " '("default" "dbcli")))

(defun convention-get-sql-cli-program (container-name)
  "Returns a string representing the cli program to be used with the database
   engine specified"
  (let ((dbcli-p (convention-prompt-for-sql-cli-type)))
    (if (equal dbcli-p "default")
        (convention-query-lang-info container-name "default-cli-program")
      (convention-query-lang-info container-name "dbcli-program"))))

(defun convention-prompt-for-db-port ()
  "Returns a string representing the port on which the database is running (inside
   of the container)"
  (completing-read "Enter the database port: " ()))

(defun convention-format-db-connection-string (container-name)
  "Returns a string representing the connection string for a specific database"
  (let* ((port (convention-prompt-for-db-port))
         (password (convention-prompt-for-db-password))
         (root-user-name (convention-query-lang-info container-name "root-user-name"))
         (connection-template (convention-query-lang-info container-name "connection-string")))
    (s-format connection-template 'aget `(("username" . ,root-user-name)
                                          ("port" . ,port)
                                          ("password" . ,password)))))

(defun convention-format-connect-to-db (container-name)
  "Returns a string representing the command used to connect to a specific database
   engine"
  (let* ((sql-cli-program (convention-get-sql-cli-program container-name))
         (connection-string (convention-format-db-connection-string container-name)))
    (concat sql-cli-program " " connection-string)))

(defun convention-format-connect-to-container-cmd (container-name)
  "Returns a string representing the docker command used to connect to a container"
  (let* ((base-cmd (convention-prompt-for-container-command container-name))
         (cmd (if (and (convention-is-sql container-name) (not (equal base-cmd "bash")))
                  (convention-format-connect-to-db container-name)
                (message base-cmd))))
    (s-format convention-docker-command-connect-to-container
              'aget `(("container-name" . ,container-name)
                      ("cmd" . ,cmd)))))

(defun convention-connect-to-container ()
  "Connects to a container.  A 'connection' in this context refers to the act of
   opening a opening a repl connected to a container.  This repl could be bash or
   a language specific cli"
  (interactive)
  (let* ((container-name (convention-prompt-for-running-container))
         (buffer-name (convention-format-process-buffer-name container-name))
         (connect-to-container-cmd (convention-format-connect-to-container-cmd container-name)))
    (convention-start-process buffer-name)
    (process-send-string buffer-name (concat connect-to-container-cmd "\n"))
    (display-buffer buffer-name)
    ))

(defun convention-connect-to-container-from-docker-container-mode ()
  "Connects to a container.  A 'connection' in this context refers to the act of
   opening a opening a repl connected to a container.  This repl could be bash or
   a language specific cli"
  (interactive)
  (let* ((container-name (elt (tabulated-list-get-entry) 6))
         (buffer-name (convention-format-process-buffer-name container-name))
         (connect-to-container-cmd (convention-format-connect-to-container-cmd container-name)))
    (convention-start-process buffer-name)
    (process-send-string buffer-name (concat connect-to-container-cmd "\n"))
    (display-buffer buffer-name)
    )
  )

(provide 'convention-connect-container)
