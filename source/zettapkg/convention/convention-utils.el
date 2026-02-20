(defun convention-util-recursive-assoc-cdr (key-tuple alist)
  "Returns an element from a nested ALIST, whose hierarchical address is
   described with a key-tuple, which is a tuple of alist keys"
  (let ((key (car key-tuple)))
    (if (equal (length key-tuple) 1)
        (cdr (assoc key alist))
      (convention-util-recursive-assoc-cdr
       (cdr key-tuple)
       (cdr (assoc key alist))))))


(defun convention-is-sql (image-or-container-name)
  "Returns a boolean indicating whether the LANG corresponds
   to a database engine"
  (let ((lang (convention-guess-lang-from-image-or-container-name image-or-container-name)))
    (member lang '("postgres"
                   "mysql"
                   "mssql"
                   "mariadb"))))


(defun convention-local-async-shell-command (cmd)
  "Runs async command in the home directory of the emacs host (ie
'local').  This is required because, by default, when in a tramp
buffer, emacs will use the host's programs when running
async-shell-command.  This command explicitly overrides that
behavior by setting the default directory to be the end user's
computer"
  (interactive)
  (let ((default-directory "~/"))
    (async-shell-command cmd)))

(defun convention-local-shell-command (cmd)
  (interactive)
  (let ((default-directory "~/"))
    (shell-command cmd)))

(defun convention-local-shell-command-to-string (cmd)
  (interactive)
  (let ((default-directory "~/"))
    (shell-command-to-string cmd)))



(provide 'convention-utils)

