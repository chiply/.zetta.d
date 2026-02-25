;;; bootstrap-zettafn.el --- Configure zetta utility functions -*- lexical-binding: t; -*-

(defun zetta-load-config-file (file)
  (interactive)
  "Load a file in current user's configuration directory"
  (message file)
  (let* ((emacsdir (expand-file-name user-emacs-directory))
         (sourcefile-path (format "%smodules/%s" emacsdir file))
         (file-extension (file-name-extension file))
         (root (file-name-sans-extension file))
         )
    (cond
     ((string= "el" file-extension)
      (load-file sourcefile-path))
     ((string= "org" file-extension)
      (let* ((tanglefile-path (format "%smodules/tangled/%s.el" emacsdir root)))
        (org-babel-tangle-file sourcefile-path tanglefile-path)
        (load-file tanglefile-path)
        ))
     )
    )
  )

(defun zetta-general-describe-keybindings (&optional arg)
  "Show all keys that have been bound with general in an org buffer.
Any local keybindings will be shown first followed by global keybindings.
With a non-nil prefix ARG only show bindings in active maps."
  (interactive "P")
  (with-output-to-temp-buffer "*General Keybindings*"
    (let* ((keybindings (append
                         (copy-alist general-keybindings)
                         (list (cons 'local general-local-keybindings))))
           (active-maps (current-active-maps)))
      ;; print prioritized keymaps first (if any)
      (dolist (keymap general-describe-priority-keymaps)
        (let ((keymap-cons (assq keymap keybindings)))
          (when (and keymap-cons
                     (or (null arg)
                         (and (boundp (car keymap-cons))
                              (memq (symbol-value (car keymap-cons))
                                    active-maps))))
            (general--print-keymap-heading keymap-cons)
            (setq keybindings (assq-delete-all keymap keybindings)))))
      ;; sort the remaining and then print them
      (when general-describe-keymap-sort-function
        (setq keybindings (funcall general-describe-keymap-sort-function
                                   keybindings)))
      (dolist (keymap-cons keybindings)
        (when (or (null arg)
                  (and (boundp (car keymap-cons))
                       (memq (symbol-value (car keymap-cons)) active-maps)))
          (general--print-keymap-heading keymap-cons)))))

  (with-current-buffer "*General Keybindings*"
    (write-region
     (point-min)
     (point-max)
     (expand-file-name "keybindings.org" user-emacs-directory)
     t)
    (kill-buffer)
    )
  )

;; build docs
(defun zetta-build-docs ()
  (interactive)
  (with-current-buffer (find-file-noselect (expand-file-name "read.org" user-emacs-directory))
    (org-babel-execute-buffer)
    (save-buffer)
    (org-open-file (org-html-export-to-html))
    (kill-buffer)
    )
  )

;; create a face inherits from 'link, except uses purple as the color
(defface zetta-link-face
  '((t :inherit link :foreground "purple"))
  "Face for links."
  :group 'basic-faces)

(defun zetta-highlight-phrases ()
  (interactive)

  ;; SQLALCHEMY Logs
  (highlight-phrase "WARNING" 'modus-themes-intense-yellow)
  (highlight-phrase "STEP_SUCCESS" 'modus-themes-subtle-green)
  (highlight-phrase "PIPELINE_SUCCESS" 'modus-themes-intense-green)
  (highlight-phrase "ERROR" 'error)
  (highlight-phrase "HOOK_ERRORED" 'modus-themes-subtle-red)
  (highlight-phrase "New Records" 'modus-themes-subtle-blue)

  (highlight-phrase "COMMIT" 'modus-themes-subtle-red)
  (highlight-phrase "ROLLBACK" 'modus-themes-red-nuanced)
  (highlight-phrase "SELECT" 'modus-themes-subtle-blue)

  (highlight-phrase "INSERT" 'modus-themes-subtle-green)
  (highlight-phrase "UPDATE" 'modus-themes-subtle-green)
  (highlight-phrase "DELETE" 'modus-themes-subtle-green)

  ;; pytest
  (highlight-phrase "Error" 'modus-themes-subtle-red)
  (highlight-phrase "error" 'modus-themes-subtle-red)
  (highlight-phrase "ERROR" 'modus-themes-subtle-red)

  (highlight-phrase "Warning" 'modus-themes-subtle-yellow)
  (highlight-phrase "warning" 'modus-themes-subtle-yellow)
  (highlight-phrase "WARNING" 'modus-themes-subtle-yellow)

  (highlight-phrase "Failed" 'modus-themes-subtle-yellow)
  (highlight-phrase "failed" 'modus-themes-subtle-yellow)
  (highlight-phrase "FAILED" 'modus-themes-subtle-yellow)

  (highlight-phrase "Captured stdout call" 'modus-themes-subtle-green)

  ;; regex should match exactly 1 space either side of the + sign
  (highlight-regexp " \\+ " 'modus-themes-subtle-green)
  ;; regex should match exactly 1 space either side of the - sign
  (highlight-regexp " - " 'modus-themes-subtle-red)
  (highlight-phrase "!=" 'modus-themes-subtle-cyan)

  (highlight-phrase "debug" 'modus-themes-subtle-yellow)

  ;; http
  (highlight-phrase "400" 'modus-themes-subtle-red)
  (highlight-phrase "401" 'modus-themes-subtle-red)
  (highlight-phrase "402" 'modus-themes-subtle-red)
  (highlight-phrase "404" 'modus-themes-subtle-red)
  (highlight-phrase "500" 'modus-themes-intense-red)

  (highlight-phrase "422" 'modus-themes-subtle-magenta)

  (highlight-phrase "200" 'modus-themes-subtle-green)
  (highlight-phrase "201" 'modus-themes-subtle-green)

  ;; highlight uuids
  (highlight-phrase "[a-f0-9]\\{8\\}-[a-f0-9]\\{4\\}-[a-f0-9]\\{4\\}-[a-f0-9]\\{4\\}-[a-f0-9]\\{12\\}" 'modus-themes-subtle-blue)

  ;; -->
  (highlight-phrase "-->" 'modus-themes-subtle-green)

  ;; temporal
  (highlight-phrase "Starting workflow" 'modus-themes-subtle-cyan)

  ;; paths
  (highlight-regexp "\\(/\\|~\\)[^ ]+\\.[a-zA-Z0-9]+" 'zetta-link-face)

  ;; urls
  (highlight-regexp "http\\(s\\)?://[^ ]+" 'link)

  ;; highlight case insensitive occurrences of "token"
  (highlight-phrase "token" 'modus-themes-subtle-blue)
  )

(defun zetta-touch-maybe (path)
  "Create file or directory at PATH if it doesn't already exist.
If PATH has an extension, creates a file; otherwise creates a directory."
  (if (file-exists-p path)
      (message "{%s} already exists" path)
    (if (string-match-p
         (regexp-quote ".")
         (file-name-nondirectory path))
        ;; it's a file, so create it
        (progn
          (make-directory (file-name-directory path) t)
          (with-temp-file path (insert ""))
          (message "Created file: %s" path))
      ;; it's a dir, so mkdir
      (progn
        (make-directory path t)
        (message "Created directory: %s" path)))))

;; leaves all but last dir
(defun zetta-minify-path (path)
  (let* ((path (abbreviate-file-name path))
         (path-split (split-string path "/"))
         (leaf-dir-name (car (last path-split 2)))
         (path-split (butlast path-split 2))
         )
    (concat
     (mapconcat
      (lambda (s) (if (> (length s) 1) (substring s 0 2) s))
      path-split "/")
     "/" leaf-dir-name)))

(defun zetta-create-scratch-buffer (mode)
  "Create a new scratch buffer to work in. (could be any mode)"
  (interactive "sMode: ")
  (switch-to-buffer (get-buffer-create (concat "*scratch-" mode "*")))
  (funcall (intern mode)))

(provide 'bootstrap-zettafn)
;;; bootstrap-zettafn.el ends here
