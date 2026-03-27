;;; multi-compile-targets.el --- Target detection pipeline for multi-compile -*- lexical-binding: t; -*-

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
   ((string= build-file-type "shell script") "vterm")))

(defun zmc-make-template (build-file-name target)
  (let ((build-file-type (or (bound-and-true-p build-file-type) "")))
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
      (concat "./" build-file-name)))))

(defun zmc-parse-nx-targets (file)
  (let* ((config-raw (with-temp-buffer
                       (insert-file-contents (expand-file-name file))
                       (buffer-string)))
         (targets (json-parse-string config-raw)))
    (ht-keys (ht-get targets "targets"))))

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
         (paths (split-string paths "\n"))
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

(defun parse-zsh-history (file)
  "Parse zsh history FILE into a list of successful commands (exit code 0)."
  (with-temp-buffer
    (insert-file-contents file)
    (let (commands)
      (while (re-search-forward "^: [0-9]+:0;\\(.+\\)$" nil t)
        (let ((cmd (match-string 1)))
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
         (parent-repo (when (and (member build-file-type
                                         '("nx-run-many"))
                                 (zmc-get-parent-repo project-path))))
         (project-current-path (when-let* ((proj (project-current nil)))
                                 (expand-file-name (project-root proj))))
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
                            project-current-path
                            (or
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
                      ((string= build-file-type "python-test") '(""))
                      ((string= build-file-type "ipython") '(""))
                      ((string= build-file-type "python") '(""))
                      ((string= build-file-type "tmuxinator") '(""))
                      ((string= build-file-type "shell script") '(""))
                      ((string= build-file-type "install-python-project-and-lsp-deps") '(""))))
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

;;; multi-compile-targets.el ends here
