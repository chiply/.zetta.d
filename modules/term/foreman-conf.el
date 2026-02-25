;;; foreman-conf.el --- Configure foreman process manager -*- lexical-binding: t; -*-

;; this file represents config space for 4mn.  This is what an end user will interact with to
;; add their programming language of choice

;; to add a command to foreman, there are 6 steps
;; 1: REGISTER add your command to 4mn-executable-registry or make the necessary wrapper (see below)
;; 2: ENVIRONMENT ensure you have a venv in "~/envs" with the dependencies necessary to run the above
;; 3: CONFIGURE ensure the 4mn-conf is updated with correct data
;; 4: SETTERS ensure that the appropriate setter functions have been set and
;; that these have been added to hydra-4mn, and the keybindings have
;; been set in the relevant major mode
;; 5: ensure that 4mn is initialized by adding a hook to the relevant mode
;; 6. finally update the exec function, although I'm looking for a way around this

;; available commands
(setq 4mn-executable-registry
      '(
        "python"
        "python3"
        "ipython"
        "R"
        "julia"
        "node"
        "sh"
        )
      )

;; initializes config by creating a buffer-local hash table
(defun 4mn-init-conf ()
  (interactive)
  (let ((key (4mn-get-key))
        (dir (4mn-detrampify-path default-directory))
        (w_sqlite3 (4mn-get-wrapper "w_sqlite3.py"))
        (w_docker (4mn-get-wrapper "w_docker.py"))
        (w_act (4mn-get-wrapper "w_act.py"))
        (w_jmespath (4mn-get-wrapper "w_jmespath.py"))
        )
    ;; todo: read this in from a yaml file
    ;; things that are dynamic above would get computed when the ht is
    ;; instantiated, not before (which is currently happening)
    (ht-set!
     4mn-conf
     key
     (ht
      ("sh-mode" (ht
                  ("exec" "sh")
                  ("venv" "none")
                  ("suff" "sh")
                  ("wraps" ())
                  ("wrap" "# ${sourcefile} \n${code}")
                  ("wrapnm" "none")
                  ("dir" dir)
                  ("procname" nil)
                  ("repl" "ipython")
                  ("repl-p" "no")
                  ("pos" "t0")
                  ("suppress-output" "yes")
                  ))
      ("python-ts-mode" (ht
                         ("exec" "python")
                         ("venv" "~/envs/main")
                         ("suff" "py")
                         ("wraps" ())
                         ("wrap" "# ${sourcefile} \n${code}")
                         ("wrapnm" "none")
                         ("dir" dir)
                         ("procname" nil)
                         ("repl" "ipython")
                         ("repl-p" "no")
                         ("pos" "t0")
                         ("suppress-output" "yes")
                         ))
      ("dockerfile-mode" (ht
                          ("exec" "python")
                          ("venv" "~/envs/main")
                          ("suff" "py")
                          ("wraps" (ht ("docker" w_docker)))
                          ("wrap" w_docker)
                          ("wrapnm" "act")
                          ("dir" dir)
                          ("procname" nil)
                          ("repl" "ipython")
                          ("repl-p" "no")
                          ("pos" "t0")
                          ("dockerfile" (file-local-name (or (buffer-file-name) "~/Dockerfile")))
                          ("image-name" "default")
                          ("suppress-output" "yes")
                          ))
      ("jmespath-mode" (ht
                        ("exec" "python")
                        ("venv" "~/envs/main")
                        ("suff" "py")
                        ("wraps" (ht ("jmespath" w_jmespath)))
                        ("wrap" w_jmespath)
                        ("wrapnm" "jmespath")
                        ("dir" dir)
                        ("procname" nil)
                        ("repl" "ipython")
                        ("repl-p" "no")
                        ("pos" "t0")
                        ("json_file" "json.json")
                        ("suppress-output" "yes")
                        ))
      ("yaml-mode" (ht
                    ("exec" "python")
                    ("venv" "~/envs/main")
                    ("suff" "py")
                    ("wraps" (ht ("act" w_act)))
                    ("wrap" w_act)
                    ("wrapnm" "act")
                    ("dir" dir)
                    ("procname" nil)
                    ("repl" "ipython")
                    ("repl-p" "no")
                    ("pos" "t0")
                    ("type" "Github Actions")
                    ("action" "push")
                    ("workflow_file" (buffer-name))
                    ("secret_file_path" "~/.secrets")
                    ("event_path" "")
                    ("suppress-output" "yes")
                    ))
      ("sql-mode" (ht
                   ("exec" "python")
                   ("venv" "~/envs/main")
                   ("suff" "py")
                   ("wraps" (ht
                             ("sqlite3" w_sqlite3)
                             ))
                   ("wrap" w_sqlite3)
                   ("wrapnm" "sqlite3")
                   ("sqlite3dbpath" nil)
                   ("dir" dir)
                   ("procname" nil)
                   ("repl" "ipython")
                   ("repl-p" "no")
                   ("pos" "t0")
                   ("suppress-output" "yes")
                   ))
      ("emacs-lisp-mode" (ht
                          ("exec" "emacs")
                          ("venv" "none")
                          ("suff" "el")
                          ("wraps" ())
                          ("wrap" ";; ${sourcefile}\n${code}")
                          ("wrapnm" "none")
                          ("dir" dir)
                          ("procname" nil)
                          ("repl" "ielm")
                          ("repl-p" "no")
                          ("pos" "t0")
                          ("suppress-output" "yes")
                          ))
      ))
    )
  )

;; 4mn-init-conf is called on-demand (interactively) rather than via mode
;; hooks.  The keybindings below (<return>, <C-return>, <S-return>) trigger
;; 4mn-exec, which expects 4mn-init-conf to have been run for the current
;; buffer.  Call `M-x 4mn-init-conf` in a supported mode before first use.

;;;; Setter macro and generated setters

(defmacro def4mn-setter (name key reader)
  "Define an interactive 4mn setter function.
NAME is the function suffix (e.g. \"executable\" -> 4mn-set-executable).
KEY is the 4mn-conf key string to set.
READER is a form that reads user input and returns the value to store."
  (let ((fn-name (intern (format "4mn-set-%s" name))))
    `(defun ,fn-name ()
       (interactive)
       (s ,key ,reader))))

;; completing-read setters
(def4mn-setter "suppress-output" "suppress-output"
  (completing-read "Suppress output: " '("yes" "no")))
(def4mn-setter "executable" "exec"
  (completing-read "Exec: " 4mn-executable-registry))
(def4mn-setter "procname" "procname"
  (completing-read "Set a procname: " '()))
(def4mn-setter "pos" "pos"
  (completing-read "Position: " '()))
(def4mn-setter "action" "action"
  (completing-read "Action: " '(push pull_request workflow_dispatch delete create workflow_call)))
(def4mn-setter "type" "type"
  (completing-read "Type: " '("Github Actions" "docker-compose")))

;; directory setters
(def4mn-setter "venv" "venv"
  (read-directory-name "Choose a venv: " "~/envs/"))
(def4mn-setter "dir" "dir"
  (4mn-detrampify-path (read-directory-name "Directory: ")))

;; file setters
(def4mn-setter "workflow-file" "workflow_file"
  (read-file-name "Select a file: "))
(def4mn-setter "secret-file-path" "secret_file_path"
  (read-file-name "Select a file: "))
(def4mn-setter "event-path" "event_path"
  (concat "-e " (read-file-name "Select a file: ")))
(def4mn-setter "dockerfile" "dockerfile"
  (read-file-name "Select a file: "))
(def4mn-setter "json-file" "json_file"
  (read-file-name "Select a file: "))

;; minibuffer setter
(def4mn-setter "image-name" "image-name"
  (read-from-minibuffer "Name the image: "))

;;;; Non-trivial setters (kept as manual defuns)

(defun 4mn-get-sqlite3dbpath ()
  "Return the path to the project's sqlite3 db, or \":memory:\" if not found."
  (let* ((dir (project-root (project-current nil default-directory)))
         (sqlite3dbpath (concat dir "main.db")))
    (if (file-exists-p sqlite3dbpath)
        sqlite3dbpath
      ":memory:")))

(defun 4mn-set-wraps ()
  "Select a wrapper, updating wrapnm, wrap, and sqlite3dbpath accordingly."
  (interactive)
  (let ((wrapnm (completing-read "Choose a wrapper: " (ht-keys (g "wraps")))))
    (s "wrapnm" wrapnm)
    (s "wrap" (ht-get* (g "wraps") (g "wrapnm")))
    (if (string= wrapnm "sqlite3")
        (s "sqlite3dbpath" (4mn-get-sqlite3dbpath))
      (s "sqlite3dbpath" nil))))

(defun 4mn-set-sqlite3dbpath ()
  "Prompt for a .db file path when the active wrapper is sqlite3."
  (interactive)
  (when (string= (g 'wrapnm) "sqlite3")
    (let ((dbpath (read-file-name "dbpath: ")))
      (if (string= (file-name-extension dbpath) "db")
          (s "sqlite3dbpath" dbpath)
        (message "not a dbfile")))))

(defun 4mn-set-repl ()
  "Toggle the REPL flag between yes and no."
  (interactive)
  (if (string= "yes" (g 'repl-p))
      (s "repl-p" "no")
    (s "repl-p" "yes")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  Exec function
(defun 4mn-exec (&optional thing)
  (interactive)
  (let* (
         (innercmd (4mn-get-inner-cmd))
         (thing (format "%s\n" (string-trim (zetta-get-thing thing))))
         (code (format
                "%s\n"
                (string-trim
                 (s-format (g 'wrap)
                           'aget
                           ;; TODO couldn't we just set this to the hash table?
                           `(
                             ("code" . ,thing)
                             ("sourcefile" . ,(file-local-name
                                               (or (buffer-file-name) "foo")))
                             ("sqlite3dbpath" . ,(g "sqlite3dbpath"))
                             ;; for actions
                             ("type" . ,(g "type"))
                             ("action" . ,(g "action"))
                             ("workflow_file" . ,(g "workflow_file"))
                             ("secret_file_path" . ,(g "secret_file_path"))
                             ("event_path" . ,(g "event_path"))
                             ;; TODO update this attribute if I use foreman again
                             ;;("(project-name (project-current nil default-directory))" . ,(project-root (project-current nil default-directory)))
                             ;; docker
                             ("dockerfile" . ,(g "dockerfile"))
                             ("image-name" . ,(g "image-name"))
                             ;; json (jmespath)
                             ("json_file" . ,(g "json_file"))
                             )
                           )
                 )))
         (filenm (format "./.4mn_code.%s" (g 'suff)))
         (procname (or (g 'procname) "no_procname")
                   )
         (bufnm (format "*4%s|%s%s--%s*"
                        (g 'pos)
                        (if (4mn-get-tramp-context--hostname) (concat "[r: " (4mn-get-tramp-context--hostname) "]") "")
                        (if (4mn-get-tramp-context--containername) (concat "[d:" (4mn-get-tramp-context--containername) "]") "")
                        procname
                        )))
    (cond ((string= "yes" (g 'repl-p))
           ;; TODO: repl-p path needs rewrite — detached output suppression changed
           (progn
             (when (not (member bufnm
                                (-map
                                 (lambda (buf) (buffer-name buf))
                                 (buffer-list))))
               (detached-shell-command innercmd nil))
             (process-send-string bufnm code)
             (display-buffer bufnm)))
          ((string= "no" (g 'repl-p))
           (progn
             (with-temp-file filenm (insert code))
             (detached-shell-command
              (4mn-get-inner-cmd t)
              (if (string= (g 'suppress-output) "yes") t nil))
             (message (concat "executed \n\n" innercmd "\n\natdir " default-directory))
             ))
          )
    )
  )

(let ((modes '(
               python-ts-mode-map sh-mode-map js2-mode-map ruby-mode-map
               go-mode-map scala-mode-map ess-r-mode-map ess-r-help-mode-map
               julia-mode-map sql-mode-map yaml-mode-map dockerfile-mode-map
               jmespath-mode-map
               )))
  (general-define-key
   :states '(normal visual)
   :keymaps modes
   "<return>" '(lambda () (interactive) (4mn-exec 'line))
   "<C-return>" '4mn-exec
   "<S-return>" '(lambda () (interactive) (4mn-exec 'buf))

   )

  )
;;; foreman-conf.el ends here
