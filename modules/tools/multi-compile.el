;;; multi-compile.el --- Configure multi-compile -*- lexical-binding: t; -*-

;; TODO
;; display buffer function
;; replacement logic -- lay out all the different use casces and options
;; update: I'm going to call this a replace-buffer-function as this is operating at the buffer name level...
;;;; *replace* eg kill original,
;;;; *switch* to original (display and select),
;;;; *display* to original (display and don't select),
;;;; *create* with new buffername (simply prompt with what would have been used, eg provide a randomized thing as default)
;;;; *warn*
;;;; *default-buffer-replace-policy* to ease the change, implement a policy that does default-buffer-replace-policy (currently there is not really a policy, it just does default-buffer-replace-policy). note this would default to the underlying executor's default behavior.  eg for async-shell-command, it would simply warn you that the buffer already exists and do default-buffer-replace-policy.  I would typically prefer to set things explicitly

;;;;;;;;;;;;;;;; DEPENDENCIES
(use-package templatel)
(use-package compile-multi :commands compile-multi)
(use-package consult-compile-multi :after compile-multi :config (consult-compile-multi-mode))
(use-package all-the-icons-completion
  :hook (elpaca-after-init . all-the-icons-completion-mode)
  :config
  (add-hook 'marginalia-mode-hook #'all-the-icons-completion-marginalia-setup))
(use-package compile-multi-all-the-icons :after compile-multi)
(use-package compile-multi-embark :after (compile-multi embark) :config (compile-multi-embark-mode +1))
(use-package projection :commands projection-mode)
(use-package projection-multi
  :after projection
  :config
  (require 'projection-multi-make))
(use-package projection-multi-embark :after (projection embark))

;; TODO - timing of setting local and latest-transient -- should only happen once the transient has been executed, but this may be challenging or require more refactoring

;; VARIABLES
(defvar zmc-extra-project-paths '())
(defvar zmc-cache nil)
(setq zmc-async-shell-command-spinners-enable nil)
;; solution for monorepos:

;;;;;;;;;;;;;;;;;; HELPERS
(defun zmc-get-hashtbl (args)
  (ht<-alist
   (-map
    (lambda (e)
      (let* ((kv (split-string e "="))
             (k (string-replace "--" "" (car kv)))
             (v (string-join (cdr kv) "=")))
        `(,k . ,v)))
    args)))

(defun zmc-compute-bufnm ()
  (or (when (boundp 'local-transient) local-transient) latest-transient))

;;;;;;;;;;;;;;;;;; Enhanced versions of async-shell-command and
;;;;;;;;;;;;;;;;;; detached-shell-command
(defun zmc-command-sentinel (process signal)
  "`zmc-async-shell-command+` is an async/compile variant allowing to
leverage the high speed features of async-shell-command with the
convenient error parsing and ergonomics of compilation-mode.
Also includes mechanisms for notifications, spinners, and
annotation of output (via highlight phrases).  This functions use
of process sentinel should serve as a reference implementation
for doing this with any other subprocess-creating function like
async-shell-command"
  (let* ((buf (process-buffer process))
         (bufnm (buffer-name buf)))
    (when (memq (process-status process) '(exit signal))
      (with-current-buffer buf
        (compilation-minor-mode t)
        (zetta-compile-spin-stop buf signal)
        ;;(zetta-highlight-phrases)
        (alert (concat bufnm " exited with signal: " signal)
               :title "zmc finished"))
      (shell-command-sentinel process signal))))

(defun zmc-async-shell-command+ (command output-buffer &optional error-buffer)
  (let* ((proc (progn
                 (async-shell-command command output-buffer error-buffer)
                 (with-current-buffer output-buffer
                   (zetta-highlight-phrases))
                 (get-buffer-process output-buffer))))
    (if (process-live-p proc)
        (progn
          (set-process-sentinel proc #'zmc-command-sentinel)
          output-buffer)
      (message "No process running"))))

(defun zmc-detached-shell-command+ (command output-buffer)
  (let* ((detached--shell-command-buffer output-buffer)
         (proc (progn
                 (detached-shell-command command)
                 (with-current-buffer output-buffer
                   (zetta-highlight-phrases))
                 (get-buffer-process output-buffer))))
    (if (process-live-p proc)
        (progn
          (set-process-sentinel proc #'zmc-command-sentinel)
          output-buffer)
      (message "No process running"))))

;;;;;;;;;;;;;;;;;;;;;; EXECUTORS
;; TODO keep an eye on this - may cause issues
(setq default-buffer-replace-policy "default-buffer-replace-policy")

(defun zmc-execute (program cmd bufnm &optional buffer-replace-policy transient-name)
  (if (not (member program
                   '("detached" "detached+" "async-shell-command"
                     "async-shell-command+" "vterm" "compile"
                     "detached-compile")))
      (error "zmc-execute: program %s not supported" program))
  (let (;; NOTE remove a trailing " &" from the cmd not sure why this
        ;; happens, but sometimes when I edit code in this file, there
        ;; appears to be a trailing " &" in the cmd.  This can be
        ;; fixed by making seemingly unrelated code changes... not
        ;; sure what's going on. This does seem to solve the issue but
        ;; not all the time... leaving this code and these notes here
        ;; nevertheless
        (cmd (progn
               ;; if cmd contains " &" message about it
               (when (string-match " &" cmd)
                 (message "cmd contains &"))
               (string-replace " &" "" cmd)))
        (bufnm (zmc-compute-bufnm))
        (buffer-replace-policy (or buffer-replace-policy
                                   default-buffer-replace-policy)))
    ;; TODO - factor out the buffer-replace-policy logic
    (cond ((string= buffer-replace-policy "replace")
           (when (get-buffer bufnm)
             ;; kill the process associated with the buffer
             (let ((proc (get-buffer-process bufnm)))
               (when (process-live-p proc)
                 (progn
                   (kill-process proc)
                   (let ((timeout 2)
                         (start-time (current-time)))
                     (while (and (process-live-p proc)
                                 (< (time-to-seconds (time-since start-time))
                                    timeout))
                       (sleep-for 0.05))))))))
          ((string= buffer-replace-policy "switch")
           (when (get-buffer bufnm)
             (switch-to-buffer bufnm)))
          ((string= buffer-replace-policy "display")
           (when (get-buffer bufnm)
             (display-buffer bufnm)))
          ((string= buffer-replace-policy "create")
           (when (get-buffer bufnm)
             (let ((bufnm (generate-new-buffer-name bufnm)))
               (display-buffer bufnm))))
          ((string= buffer-replace-policy "warn")
           (when (get-buffer bufnm)
             (message "Buffer %s already exists" bufnm)))
          ((string= buffer-replace-policy "default-buffer-replace-policy")
           (message "no replacing"))
          (t (message "Buffer %s already exists" bufnm))))
  (let* ((shell-command-switch "-ic")
         ;; TODO - factor out the executor logic
         (buf (cond
               ((string= program "detached") (zmc-es-detached cmd))
               ((string= program "detached+") (zmc-es-detached+ cmd))
               ((string= program "async-shell-command") (zmc-es-async-shell-command cmd))
               ((string= program "async-shell-command+") (zmc-es-async-shell-command+ cmd))
               ((string= program "vterm") (zmc-es-vterm cmd))
               ((string= program "compile") (zmc-es-compile cmd))
               ((string= program "detached-compile") (zmc-es-detached-compile cmd)))))
    (save-window-excursion
      (switch-to-buffer buf)
      (set (make-local-variable 'local-transient) transient-name))
    (if (or (bufferp buf) (bufferp (get-buffer buf)))
        buf
      (error "zmc-execute: executor did not return a buffer"))))

(defun zmc-run (program cmd bufnm side slot select &optional buffer-replace-policy transient-name)
  (let* ((original-buffer (current-buffer))
         (original-window (get-buffer-window original-buffer))
         (new-buffer (zmc-execute program cmd bufnm buffer-replace-policy transient-name)))
    ;; if the buffer is not the original buffer, switch to it
    (unless (string= (buffer-name original-buffer)
                     (cond
                      ((bufferp new-buffer)
                       (buffer-name new-buffer))
                      ;; case it is a string
                      ((stringp new-buffer) new-buffer)))
      ;; removes from the current window's tab list, this has the impact
      ;; of avoiding polluting the tab list of the buffer from which zmc
      ;; is called with potentially unnecessary tabs pointing to the
      ;; created buffer
      (switch-to-buffer new-buffer)
      ;; got this part from bury-buffer function
      (set-window-dedicated-p nil nil)
      (switch-to-prev-buffer nil 'bury)
      ;; display the buffer.  The point here is that
      ;; display-buffer-alist settings are respected by default but
      ;; these can also be overridden by the user NYI TODO implement
      ;; overrideable display
      (display-buffer new-buffer)
      (select-window original-window))
    ;; if select is yes, switch to the buffer
    (when (string= "yes" select)
      (select-window (get-buffer-window new-buffer)))))

;; individual executors NOTE (process-connection-type nil) is a
;; performance optimization, but doesn't work with detached
(defun zmc-es-compile (cmd)
  (let ((compilation-buffer-name-function '(lambda (_) (zmc-compute-bufnm)))
        (compile-command (or local-cmd latest-cmd)))
    (save-window-excursion (compile compile-command))))

(defun zmc-es-detached-compile (cmd)
  (let ((compilation-buffer-name-function '(lambda (_) (zmc-compute-bufnm)))
        (compile-command (or local-cmd latest-cmd)))
    (save-window-excursion (detached-compile compile-command))))

(defun zmc-es-async-shell-command (cmd)
  (let ((bufnm (zmc-compute-bufnm))
        (process-connection-type nil)
        )
    (save-window-excursion
      (window-buffer (async-shell-command cmd bufnm)))))

(defun zmc-es-async-shell-command+ (cmd)
  (let ((bufnm (zmc-compute-bufnm))
        (process-connection-type nil)
        (zmc-async-shell-command-spinners-enable t))
    (save-window-excursion
      (zmc-async-shell-command+ cmd bufnm))))

(defun zmc-es-detached (cmd)
  (let ((bufnm (zmc-compute-bufnm)))
    (let ((detached--shell-command-buffer bufnm))
      (detached-shell-command cmd))
    bufnm))

(defun zmc-es-detached+ (cmd)
  (let ((bufnm (zmc-compute-bufnm))
        (zmc-async-shell-command-spinners-enable t))
    (zmc-detached-shell-command+ cmd bufnm)
    bufnm))

(defun zmc-es-vterm (cmd)
  ;; if bufnm exists kill it
  (let* ((bufnm (zmc-compute-bufnm)))
    ;; TODO make this configurable, should it kill, switch to it,
    ;; create new with uniquify name, prompt for name? prompt for any
    ;; of these options?
    (when (get-buffer bufnm) (kill-buffer bufnm))
    (let* ((vterm-buffer (save-window-excursion (vterm bufnm)))
           (vterm-process (get-buffer-process vterm-buffer)))
      (process-send-string vterm-process (concat cmd "\n"))
      bufnm)))

;;;;;;;;;;;;;;;;;;;;;; ACTION
(defun zmc-transient-act (&optional args)
  (interactive
   (list (transient-args
          (intern (or
                   (when (boundp 'local-transient)
                     local-transient)
                   latest-transient)))))
  (let* ((target (zmc-get-hashtbl args))
         (program (ht-get target "program"))
         (command-template (ht-get target "template"))
         (cmd (templatel-render-string command-template (ht->alist target)))
         (_ (ht-set! target "target" cmd))
         (directory (ht-get target "directory"))
         (default-directory (or
                             (and
                              directory
                              (expand-file-name (eval-expression directory)))
                             default-directory))
         (bufnm (ht-get target "bufnm"))
         (side (intern (or (ht-get target "side") "top"))) ;; default
         (slot (or (ht-get target "slot") 1)) ;; default
         (select (or (ht-get target "select") "no"))
         (buffer-replace-policy (or (ht-get target "buffer-replace-policy")
                                    "default-buffer-replace-policy"))
         ;; TODO redundant logic
         (transient-name (string-replace " " "-" (ht-get target "key")))
         )
    (setq latest-cmd cmd)
    (set (make-local-variable 'local-cmd) cmd)
    (apply 'zmc-run `(,program ,cmd ,bufnm ,side ,slot ,select ,buffer-replace-policy ,transient-name))))

;;;;;;;;;;;;;;;;;;;;;; TRANSIENT
(defun zmc-define-transient (name htbl)
  (eval
   `(transient-define-prefix ,(intern name) ()
      ;; populate initial default arguments from the config
      ;; note!  this only gets defined once, so these default values
      ;; can be effectively overwritten by saving the transient's
      ;; state
      :value
      (quote
       ,(ht-map (lambda (k v) (concat "--" (string-replace " " "-" k) "=" v)) htbl))
      ;; Arguments
      ,(vconcat
        (vector "Arguments")
        (apply
         'vector
         (ht-map
          (lambda (k v)
            `(,(concat "-" (substring k 0 1)) ,k ,(concat "--" (string-replace " " "-" k) "=")))
          htbl)))
      ;; Action: should simply take arguments and override variables
      ["Actions"
       ("<return>" "run" zmc-transient-act)])))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; DETECTORS
(defun zmc-infer-program (build-file-type)
  (cond
   ((string= build-file-type "make") "async-shell-command+")
   ((string= build-file-type "install-python-project-and-lsp-deps") "async-shell-command+")
   ((string= build-file-type "nx") "async-shell-command+")
   ((string= build-file-type "nx-run-many") "async-shell-command+")
   ((string= build-file-type "pytest") "async-shell-command+")
   ((string= build-file-type "python-test") "async-shell-command+")
   ((string= build-file-type "ipython") "vterm")
   ((string= build-file-type "python") "vterm")
   ((string= build-file-type "tmuxinator") "vterm")
   ;; NOTE this is for things like bash scripts that might run
   ;; installations (which typically come with complex spinners that
   ;; don't render all the way in async-shell-command)
   ((string= build-file-type "shell script") "vterm")
   ;; because of the ridiculous spinner
   ))

;; TODO is there a difference bt build-file-name and build-file-type
(defun zmc-make-template (build-file-name target)
  (cond
   ((string= build-file-type "make")
    (concat "make -f " build-file-name " " target))
   ((string= build-file-type "install-python-project-and-lsp-deps")
    (concat "install_all_lsp_servers \"$(pwd)\""))
   ((string= build-file-type "nx")
    (concat "nx run -t " target))
   ((string= build-file-type "nx-run-many")
    (concat "nx run-many -t " target))
   ((string= build-file-type "tmuxinator")
    (concat "tmuxinator start --suppress-tmux-version-warning -p " build-file-name))
   ((string= build-file-type "pytest")
    (concat "poetry run pytest -vvv " target))
   ((string= build-file-type "python-test")
    (concat "poetry run pytest -vvv"))
   ((string= build-file-type "ipython")
    (concat "poetry run ipython"))
   ((string= build-file-type "python")
    (concat "poetry run python"))
   ((string= build-file-type "shell script")
    (concat "./" build-file-name))))

(defun zmc-parse-nx-targets (file)
  (let* ((config-raw (with-temp-buffer
                       (insert-file-contents (expand-file-name file))
                       (buffer-string)))
         (targets (json-parse-string config-raw)))
    (ht-keys (ht-get targets "targets"))))

;; history
;; (string-match-p "python" cmd)
;; (string-match-p "python3" cmd)
;; (string-match-p "poetry" cmd)
;; (string-match-p "/bin/sh" cmd)
;; (string-match-p "bash" cmd)
;; (string-match-p "pip" cmd)
;; (string-match-p "brew" cmd)
;; (string-match-p "pytest" cmd)
;; (string-match-p "docker" cmd)
;; (string-match-p "docker-compose" cmd)
;; (string-match-p "npm" cmd)
;; (string-match-p "node" cmd)
;; (string-match-p "pyreverse" cmd)
;; (string-match-p "code2flow" cmd)
;; (string-match-p "kubectl" cmd)
;; (string-match-p "tilt" cmd)
;; (string-match-p "dagster" cmd)
;; (string-match-p "wget" cmd)
;; (string-match-p "makefile2dot" cmd)
;; (string-match-p "pyan" cmd)
;; (string-match-p "alembic" cmd)
;; (string-match-p "litecli" cmd)
;; (string-match-p "temporal" cmd)
;; (string-match-p "sqlite" cmd)
;; (string-match-p "ipython" cmd)
;; (string-match-p "dbcli" cmd)
;; (string-match-p "nx" cmd)

(defun zmc-get-parent-dirs (path)
  (let* ((path (string-join (butlast (split-string path "/")) "/"))
         (path (if (string= path "") "/" path)))
    (if (string= path "/") '() (cons path (zmc-get-parent-dirs path)))))

(defun zmc-get-pytest-targets-from-project (project-path)
  (message "Extracting pytest targets from %s..." project-path)
  (let* ((default-directory project-path)
         (cmd (concat
               "cd " project-path " && "
               "poetry run pytest "
               "--co -q --disable-warnings"))
         (_ (message cmd))
         (paths (shell-command-to-string cmd))
         (_ (message paths))
         ;;(paths (nth 0 (split-string paths "\n\n")))
         (paths (split-string paths "\n"))
         ;; filter paths for strings containing "::"
         (paths (--filter (string-match "::" it) paths))
         (paths (--map (substring it 0 (string-match "\\[" it)) paths))
         (paths (append
                 ;; function level
                 (delete-dups paths)
                 ;; file level
                 (delete-dups (--map (nth 0 (split-string it "::"))
                                     paths))
                 ;; parent dir level
                 (delete-dups (-flatten (--map (zmc-get-parent-dirs it)
                                               paths))))))
    paths))

(defun zmc-get-parent-repo (subrepo)
  (let* ((subrepo (expand-file-name subrepo))
         (repos
          (-map
           (lambda (repo) (expand-file-name repo))
           (-filter
            (lambda (repo)
              (not (string= repo "~/")))
            (append
             (project-known-project-roots)
             zmc-extra-project-paths)))))
    (car (-filter
          (lambda (repo)
            (and
             (> (length subrepo) (length repo))
             (string=
              (substring subrepo 0 (length repo))
              repo)))
          repos))))

;;(seq-filter
;;(lambda (cmd) (not (string-prefix-p "dtach" cmd)))
;;(parse-zsh-history "~/.zsh_history")
;;)

(defun parse-zsh-history (file)
  "Parse zsh history FILE into a list of successful commands (exit code 0)."
  (with-temp-buffer
    (insert-file-contents file)
    (let (commands)
      ;; NOTE filter out when success status isn't 1
      (while (re-search-forward "^: [0-9]+:0;\\(.+\\)$" nil t) ; Note the ":0;" pattern
        (let ((cmd (match-string 1)))
          ;; Handle multi-line commands (ending with \)
          (while (string-match "\\\\$" cmd)
            (forward-line)
            (let ((next-line (string-trim
                              (buffer-substring-no-properties
                               (line-beginning-position)
                               (line-end-position)))))
              (setq cmd (concat (substring cmd 0 -1) " " next-line))))
          (push cmd commands)))

      (seq-filter
       (lambda (cmd) (not (string-prefix-p "dtach" cmd)))
       (nreverse commands)))))

(defun zmc-make-alist (project-path build-file-name build-file-type)
  (let* ((fname (concat project-path build-file-name))
         (project-path (expand-file-name project-path))
         ;; set parent repo for targets that are found in subrepos,
         ;; but need to be run in parent repos (eg nx run-many).  Note
         ;; this is somewhat of an edge-case
         (parent-repo (when (and (member build-file-type
                                         '("nx-run-many"))
                                 (zmc-get-parent-repo project-path))))
         (project-current-path (expand-file-name (cadr (cdr (project-current nil)))))
         ;; TODO factor out the subtarget logic
         (subtargets (cond
                      ((string= build-file-type "history")
                       (parse-zsh-history fname))
                      ((string= build-file-type "make")
                       (projection-multi-make--targets-from-file2 fname))
                      ((string= build-file-type "nx")
                       (zmc-parse-nx-targets fname))
                      ((string= build-file-type "nx-run-many")
                       (zmc-parse-nx-targets fname))
                      ((and (string= build-file-type "pytest")
                            (or
                             ;; Current project
                             (string= project-current-path (expand-file-name project-path))
                             (and
                              (> (length project-path) (length project-current-path))
                              (string=
                               (substring project-path 0 (length project-current-path))
                               project-current-path)
                              (and
                               (>= (length default-directory) (length project-path))
                               (or
                                (string= default-directory project-path)
                                (string=
                                 (substring default-directory 0 (length project-path))
                                 project-path))))))
                       (progn
                         (zmc-get-pytest-targets-from-project project-path)))
                      ;; eg no subtargets
                      ((string= build-file-type "python-test") '(""))
                      ((string= build-file-type "ipython") '(""))
                      ((string= build-file-type "python") '(""))
                      ((string= build-file-type "tmuxinator") '(""))
                      ((string= build-file-type "shell script") '(""))
                      ((string= build-file-type "install-python-project-and-lsp-deps") '(""))
                      ))
         (dir (or parent-repo project-path))
         (dirname (file-name-nondirectory (directory-file-name dir)))
         (alist (--map
                 `(,(concat dirname " > " build-file-type " > " build-file-name " > " it)
                   .
                   ,(ht-from-alist
                     `(("template" . ,(zmc-make-template build-file-name it))
                       ("directory" . ,dir)
                       ("program" . ,(zmc-infer-program build-file-type)))))
                 subtargets)))
    (ht-from-alist alist)))

(defun zmc-get-targets (project-path build-file-type &optional build-file-regexp)
  (--map
   (let* ((build-file-name (when (file-exists-p
                                  (concat project-path it)) it)))
     (when build-file-name
       (zmc-make-alist project-path build-file-name build-file-type)))
   (directory-files project-path nil build-file-regexp t)))

(defun zmc-detect-targets (build-file-type build-file-regexp)
  (let* ((projects (--filter (and (string-suffix-p "/" it)
                                  (not (string= it "~/")))
                             (append
                              (project-known-project-roots)
                              zmc-extra-project-paths)))
         (lst (--map (zmc-get-targets it build-file-type build-file-regexp) projects))
         (lst (--filter it lst))
         (lst (flatten-list lst)))
    (eval (append '(ht-merge) lst))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; INTERACTIVE FUNCTION
(defun zmc (&optional arg)
  "Choice target and start compile.
CACHE: 1. latest/local transient 2. ~/.zmc-cache)"
  (interactive "P")
  ;; call recent transient if it exists
  (cond
   ((and arg (not (equal arg '(64))) (boundp 'local-transient))
    (progn
      (setq latest-transient local-transient)
      (funcall (intern local-transient))
      (unless (equal arg '(16))
        (execute-kbd-macro (kbd "<return>")))))
   ((and arg (not (equal arg '(64))) latest-transient)
    (progn
      (setq-local local-transient latest-transient)
      (funcall (intern latest-transient))
      (unless (equal arg '(16))
        (execute-kbd-macro (kbd "<return>")))))
   (t (let* ((targets
              (if (and (not (equal arg '(64)))
                       (file-exists-p "~/.zmc-cache.yaml"))
                  (progn
                    (message "using cache")
                    (if zmc-cache
                        zmc-cache
                      (setq zmc-cache
                            (yaml-parse-string
                             (with-temp-buffer
                               (insert-file-contents "~/.zmc-cache.yaml")
                               (buffer-string))
                             :object-key-type 'string))))
                (let* ((_ (message "refreshing cache targets"))
                       (make-targets (zmc-detect-targets "make" "makefile\\|Makefile"))
                       ;; TODO this is a hack, but it works for now --
                       ;; to be fixed in refactoring of the detection
                       (python-lsp-targets
                        (zmc-detect-targets "install-python-project-and-lsp-deps" "nx.json")) ;; monorepo
                       (python-lsp-targets-1
                        (zmc-detect-targets "install-python-project-and-lsp-deps" "pyproject.toml")) ;; other
                       ;; TODO clunky that this is detected twice
                       (nx-targets (zmc-detect-targets "nx" "project.json"))
                       (nx-many-targets (zmc-detect-targets "nx-run-many" "project.json"))
                       (pytest-targets (zmc-detect-targets "pytest" "pyproject.toml"))
                       (python-test-targets (zmc-detect-targets "python-test" "pyproject.toml"))
                       (ipython-targets (zmc-detect-targets "ipython" "pyproject.toml"))
                       (python-targets (zmc-detect-targets "python" "pyproject.toml"))
                       (tmuxinator-targets (zmc-detect-targets "tmuxinator" "\\.tmuxinator\\.yaml"))
                       (bash-script-targets (zmc-detect-targets "shell script" "\\.sh"))

                       ;; TODO do i have to use eval here?
                       (tmuxinator-targets-extra (eval
                                                  (append
                                                   '(ht-merge)
                                                   (--filter
                                                    it (zmc-get-targets
                                                        "~/.config/tmuxinator/"
                                                        "tmuxinator" "")))))
                       (history-targets (zmc-get-targets "~/" "history" ".zsh_history"))
                       ;;(detected-targets (ht-merge make-targets
                       ;;python-lsp-targets
                       ;;python-lsp-targets-1
                       ;;nx-targets
                       ;;nx-many-targets
                       ;;pytest-targets
                       ;;python-test-targets
                       ;;ipython-targets
                       ;;python-targets
                       ;;tmuxinator-targets
                       ;;tmuxinator-targets-extra
                       ;;bash-script-targets
                       ;;))
                       (detected-targets (eval (append
                                                '(ht-merge)
                                                (ht-map
                                                 (lambda (k v)
                                                   (zmc-detect-targets
                                                    (ht-get v "build-file-type")
                                                    (ht-get v "build-file-regexp")))
                                                 zmc-config)
                                                history-targets))
                                         )
                       (config-raw (with-temp-buffer
                                     (insert-file-contents "~/.cmds.yaml")
                                     (buffer-string)))
                       (targets (yaml-parse-string config-raw :object-key-type 'string))
                       (targets (ht-merge detected-targets targets))
                       ;; write the targets to cache
                       (_ (progn
                            (setq zmc-cache targets)
                            (with-temp-buffer
                              ;; NOTE avoids prompt for coding
                              (insert "-*- coding: raw-text;-*-\n")
                              (insert (yaml-encode targets))
                              (write-file "~/.zmc-cache.yaml"))
                            )
                          ))
                  targets)))
             (target-keys (ht-keys (ht-select
                                    (lambda (k v) (if t t (eval (ht-get v "if"))))
                                    targets)))
             ;; needed to pass key into target object
             (key (completing-read "target " target-keys))
             ;; the hash table representing the cmd and its attributes
             (target (ht-get targets key))
             (_ (ht-set! target "key" key))
             (transient-name (string-replace " " "-" key))
             ;; feature NYI: calls transient if exists (to benefti from getting
             ;; history), otherwise creates.  Can force recereation,
             ;; althugh use case for this is rare (eg when editing .cmds.yaml)
             (_ (zmc-define-transient transient-name target)) ; define the transient
             )
        ;; sets the name of the transient currently being used
        ;; transient act uses this to determine what the arms are)
        (setq latest-transient transient-name) ;; global
        (set (make-local-variable 'local-transient) transient-name) ;; local
        (funcall (intern transient-name))))))

(general-define-key
 ;; override alone doesn't work...
 :keymaps (append zetta-modal-states-insert zetta-modal-states-non-insert '(override))
 "s-<return>" 'zmc
 "s-r" '(lambda () (interactive)
          (setq current-prefix-arg '(4))
          (call-interactively 'zmc))
 "s-R" '(lambda () (interactive)
          (setq current-prefix-arg '(16))
          (call-interactively 'zmc))

 ;; TODO better keybinding for this
 "C-S-s-r" '(lambda () (interactive)
              (setq current-prefix-arg '(64))
              (call-interactively 'zmc))

 ;; TODO wether or not to collect the 'slow' detectors, but see how we
 ;; go with cacheing
 )

;;;;;;;;;; CONFIG
;; TODO fix templates use jinja instead
;; TODO determine how to mix custom functions (like pytest collection)
;; with this config -- note that subtargets and targets are somehwat
;; synonymous, check the render template function for this
(setq
 zmc-config
 (ht
  ("make-targets"
   (ht
    ("build-file-type" "make")
    ("build-file-regexp" "makefile\\|Makefile")
    ("template" "make -f ${build-file-name} ${target}")
    ("program" "async-shell-command+")))
  ("python-lsp-targets"
   (ht
    ("build-file-type" "install-python-project-and-lsp-deps")
    ("build-file-regexp" "nx.json")
    ("template" "install_all_lsp_servers \"$(pwd)\"")
    ("program" "async-shell-command+")))
  ("python-lsp-targets-1"
   (ht
    ("build-file-type" "install-python-project-and-lsp-deps")
    ("build-file-regexp" "pyproject.toml")
    ("template" "install_all_lsp_servers \"$(pwd)\"")
    ("program" "async-shell-command+")))
  ("nx-targets"
   (ht
    ("build-file-type" "nx")
    ("build-file-regexp" "project.json")
    ("template" "nx run -t ${target}")
    ("program" "async-shell-command+")))
  ("nx-many-targets"
   (ht
    ("build-file-type" "nx-run-many")
    ("build-file-regexp" "project.json")
    ("template" "nx run-many -t ${target}")
    ("program" "async-shell-command+")))
  ("pytest-targets"
   (ht
    ("build-file-type" "pytest")
    ("build-file-regexp" "pyproject.toml")
    ("template" "poetry run pytest -vvv ${target}")
    ("program" "async-shell-command+")))
  ("python-test-targets"
   (ht
    ("build-file-type" "python-test")
    ("build-file-regexp" "pyproject.toml")
    ("template" "poetry run pytest -vvv")
    ("program" "async-shell-command+")))
  ("ipython-targets"
   (ht
    ("build-file-type" "ipython")
    ("build-file-regexp" "pyproject.toml")
    ("template" "poetry run ipython")
    ("program" "vterm")))
  ("python-targets"
   (ht
    ("build-file-type" "python")
    ("build-file-regexp" "pyproject.toml")
    ("template" "poetry run python")
    ("program" "vterm")))
  ("tmuxinator-targets"
   (ht
    ("build-file-type" "tmuxinator")
    ("build-file-regexp" "\\.tmuxinator\\.yaml")
    ("template" "tmuxinator start --suppress-tmux-version-warning -p ${build-file-name}")
    ("program" "vterm")))
  ("bash-script-targets"
   (ht
    ("build-file-type" "shell script")
    ("build-file-regexp" "\\.sh")
    ("template" "./${build-file-name}")
    ("program" "vterm")))
  ;; TODO add tmuxinator-targets-extra and history targets -- need an extra config that says if this is a getter
  ))
;;; multi-compile.el ends here
