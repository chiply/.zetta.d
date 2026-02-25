;;; dired.el --- Configure dired -*- lexical-binding: t; -*-

(use-package dired
  :ensure nil ;; builtin

  :config

  (when (string= system-type "darwin")
    (setq dired-use-ls-dired nil))

  ;; ---------------------------------------------------------------------------
  ;; Helpers
  ;; ---------------------------------------------------------------------------

  (defun zetta-dired-file-peak ()
    "Preview the file at point in an indirect buffer."
    (interactive)
    (let* ((file (dired-get-file-for-visit))
           (buf (find-file-noselect file)))
      (zetta-indirect-buffer buf)))

  (defun zetta-dired-dir-at-point ()
    "Return the directory for the thing at point.
If point is on a directory, return it; otherwise return the
parent directory of the file at point."
    (interactive)
    (let ((thing (dired-get-file-for-visit)))
      (if (file-directory-p thing)
          (message thing)
        (file-name-directory thing))))

  ;; Cross-module dependency: `4mn-get-tramp-remote-part' is defined in
  ;; source/zettapkg/foreman/foreman.el and returns the TRAMP remote part
  ;; of `default-directory' (empty string when local).
  (defun zetta-soda-create-and-display-dired (&optional _buf-or-mode-name)
    "Open dired for the current project root, or the current file's directory."
    (if (cdr (project-current nil))
        (dired (concat
                (let ((remote (4mn-get-tramp-remote-part)))
                  (if (not (string= "" remote))
                      (concat "/" remote ":")
                    ""))
                (let ((root (project-root (project-current nil default-directory))))
                  (if (string-match ":" root)
                      (car (last (split-string root ":")))
                    root))))
      (if buffer-file-name
          (dired (file-name-directory (or load-file-name buffer-file-name)))
        (call-interactively 'find-file))))

  ;; ---------------------------------------------------------------------------
  ;; Ace-window file opening (parameterized)
  ;; ---------------------------------------------------------------------------

  (defun zetta-dired-ace-open (split prompt-for-file)
    "Open the file at point via ace-window, optionally splitting.

SPLIT is one of nil (no split), `below', or `right'.
When PROMPT-FOR-FILE is non-nil, prompt for a filename within the
directory at point instead of opening the file at point directly."
    (let ((file (if prompt-for-file
                    nil
                  (dired-get-file-for-visit)))
          (dir  (when prompt-for-file
                  (zetta-dired-dir-at-point))))
      ;; Directories: always descend in place
      (if (and file (file-directory-p file))
          (dired-find-file)
        ;; Files: pick target window via ace-window
        (if (> (length (aw-window-list)) 1)
            (aw-select ""
                       (lambda (window)
                         (aw-switch-to-window window)
                         (pcase split
                           ('below (split-window-below) (windmove-down))
                           ('right (split-window-right) (windmove-right)))
                         (find-file
                          (if prompt-for-file
                              (read-file-name "Enter a file name: " dir)
                            file))))
          (find-file-other-window
           (if prompt-for-file
               (read-file-name "Enter a file name: " dir)
             file))))))

  (defun dired-ace-find-file ()
    "Use ace-window to open the file at point."
    (interactive)
    (zetta-dired-ace-open nil nil))

  (defun dired-ace-find-file-vert ()
    "Use ace-window to open the file at point in a vertical split."
    (interactive)
    (zetta-dired-ace-open 'below nil))

  (defun dired-ace-find-file-hor ()
    "Use ace-window to open the file at point in a horizontal split."
    (interactive)
    (zetta-dired-ace-open 'right nil))

  (defun dired-ace-new-file-vert ()
    "Use ace-window to open a prompted file in a vertical split."
    (interactive)
    (zetta-dired-ace-open 'below t))

  (defun dired-ace-new-file-hor ()
    "Use ace-window to open a prompted file in a horizontal split."
    (interactive)
    (zetta-dired-ace-open 'right t))

  ;; ---------------------------------------------------------------------------
  ;; Dired operations with auto-revert
  ;; ---------------------------------------------------------------------------

  (defmacro zetta-dired-with-revert (op &optional interactive-p)
    "Define body that calls OP and reverts the buffer (unless remote).
When INTERACTIVE-P is non-nil, call OP interactively."
    `(progn
       ,(if interactive-p
            `(call-interactively #',op)
          `(,op))
       (unless (file-remote-p default-directory) (revert-buffer))))

  (defun zetta-dired-do-flagged-delete ()
    "Delete flagged files and revert."
    (interactive)
    (zetta-dired-with-revert dired-do-flagged-delete))

  (defun zetta-dired-do-delete ()
    "Delete marked files and revert."
    (interactive)
    (zetta-dired-with-revert dired-do-delete))

  (defun zetta-dired-do-copy ()
    "Copy marked files and revert."
    (interactive)
    (zetta-dired-with-revert dired-do-copy))

  (defun zetta-dired-do-rename ()
    "Rename marked files and revert."
    (interactive)
    (zetta-dired-with-revert dired-do-rename))

  (defun zetta-dired-create-directory ()
    "Create a directory and revert."
    (interactive)
    (zetta-dired-with-revert dired-create-directory t))

  ;; ---------------------------------------------------------------------------
  ;; Subtree helpers
  ;; ---------------------------------------------------------------------------

  (defun zetta-dired-subtree-cycle ()
    "Cycle dired subtree and revert."
    (interactive)
    (dired-subtree-cycle 10)
    (unless (file-remote-p default-directory) (revert-buffer)))

  (defun zetta-dired-subtree-toggle ()
    "Toggle dired subtree and revert."
    (interactive)
    (dired-subtree-toggle)
    (unless (file-remote-p default-directory) (revert-buffer)))

  ;; ---------------------------------------------------------------------------
  ;; Search / external-app helpers
  ;; ---------------------------------------------------------------------------

  (defun zetta-dired-ag ()
    "Run helm-ag on the directory at point."
    (interactive)
    (let ((dir (if (file-directory-p (dired-get-file-for-visit))
                   (dired-get-file-for-visit)
                 (file-name-directory (dired-get-file-for-visit)))))
      (helm-ag dir)))

  (defun zetta-dired-ranger-copy ()
    "Copy via dired-ranger and revert."
    (interactive)
    (call-interactively 'dired-ranger-copy)
    (unless (file-remote-p default-directory) (revert-buffer)))

  (defun zetta-dired-ranger-paste ()
    "Paste via dired-ranger and revert."
    (interactive)
    (call-interactively 'dired-ranger-paste)
    (unless (file-remote-p default-directory) (revert-buffer)))

  (defun zetta-dired-ranger-move ()
    "Move via dired-ranger and revert."
    (interactive)
    (call-interactively 'dired-ranger-move)
    (unless (file-remote-p default-directory) (revert-buffer)))

  (defun zetta-dired-open-in-chrome ()
    "Open the file at point in Google Chrome."
    (interactive)
    (let ((file (dired-get-file-for-visit)))
      (shell-command (concat "open -a \"Google Chrome\" " file))))

  (defun xah-open-in-external-app (&optional @fname)
    "Open the current file or dired marked files in external app.
The app is chosen from your OS's preference.

When called in emacs lisp, if @fname is given, open that.

URL `http://ergoemacs.org/emacs/emacs_dired_open_file_in_ext_apps.html'
Version 2019-11-04"
    (interactive)
    (let* (($file-list
            (if @fname
                (list @fname)
              (if (string-equal major-mode "dired-mode")
                  (dired-get-marked-files)
                (list (buffer-file-name)))))
           ($do-it-p (if (<= (length $file-list) 5)
                         t
                       (y-or-n-p "Open more than 5 files? "))))
      (when $do-it-p
        (cond
         ((string-equal system-type "windows-nt")
          (mapc
           (lambda ($fpath)
             (w32-shell-execute "open" $fpath)) $file-list))
         ((string-equal system-type "darwin")
          (mapc
           (lambda ($fpath)
             (shell-command
              (concat "open " (shell-quote-argument $fpath)))) $file-list))
         ((string-equal system-type "gnu/linux")
          (mapc
           (lambda ($fpath)
             (let ((process-connection-type nil))
               (start-process "" nil "xdg-open" $fpath))) $file-list))))))

  ;; ---------------------------------------------------------------------------
  ;; Soda integration
  ;; ---------------------------------------------------------------------------

  (defun zetta-soda-drink-dired ()
    (interactive)
    (zetta-soda-drink
     (quote zetta-soda-create-and-display-dired)
     "dired-mode"))

  (defun zetta-soda-cap-dired ()
    (interactive)
    (zetta-soda-cap "\\dired-mode*" 1))

  (general-define-key
   :keymaps 'menu-run-map
   "d" (repeatable-lite-wrap zetta-soda-drink-dired)
   "D" (repeatable-lite-wrap zetta-soda-cap-dired))

  :general
  (:keymaps '(dired-mode-map)
   "<tab>" 'zetta-dired-subtree-toggle
   "S-<tab>" 'zetta-dired-subtree-cycle
   "o" 'dired-ace-find-file
   "v" 'dired-ace-find-file-vert
   "h" 'dired-ace-find-file-hor
   "V" 'evil-visual-line
   "H" 'dired-ace-new-file-hor
   "J" 'dired-subtree-down
   "K" 'dired-subtree-up
   "p" 'zetta-dired-file-peak
   "A" 'zetta-dired-ag
   "r" 'revert-buffer
   "R" 'zetta-dired-do-rename
   "x" 'zetta-dired-do-flagged-delete
   "D" 'zetta-dired-do-delete
   "C" 'zetta-dired-do-copy
   "+" 'zetta-dired-create-directory
   "y" 'evil-yank
   "Y" 'zetta-dired-ranger-copy
   "P" 'zetta-dired-ranger-paste
   "M" 'zetta-dired-ranger-move
   "B" 'zetta-dired-open-in-chrome
   "G" 'evil-goto-line
   "<C-return>" 'xah-open-in-external-app)

  :hook ((dired-mode . (lambda () (dired-hide-details-mode 1)))))

;;; dired.el ends here
