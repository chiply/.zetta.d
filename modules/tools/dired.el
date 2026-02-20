(use-package dired
  :ensure nil ;; builtin


  :init

  ;;(zetta-load-extension-file "dired/dired.el")
  (when (string= system-type "darwin")       
    (setq dired-use-ls-dired nil))

  (setq dired-use-ls-dired nil)

  (defun zetta-dired-file-peak ()
    "
A docstring
"

    (interactive)
    (let* ((file (dired-get-file-for-visit))
           (buf (find-file-noselect file)))
      (zetta-indirect-buffer buf)
      ) 
    )

  (defun zetta-soda-create-and-display-dired (&optional buf-or-mode-name)
    (if (cdr (project-current nil))
        (let ((buf (current-buffer)))
          ;; can yield unexpect results on remote, so manually
          ;; assembling the file name here
          (dired (concat
                  (if (not (string= "" (4mn-get-tramp-remote-part)))
                      (concat
                       "/"
                       (4mn-get-tramp-remote-part)
                       ":"
                       )
                    ""
                    )
                  (if (string-match ":" (project-root (project-current nil default-directory)))
                      (nth 0 (last (split-string (project-root (project-current nil default-directory)) ":")))
                    (project-root (project-current nil default-directory)))
                  ))
          ;;(select-window (get-buffer-window buf))
          )
      (if buffer-file-name ; ie if in a file (not scratch agenda, etc)
          (let ((buf (current-buffer)))
            (dired (file-name-directory (or load-file-name buffer-file-name)))
            ;;(select-window (get-buffer-window buf))
            )
        (call-interactively 'find-file)
        )
      )
    )

  ;; function that returns the directory for the thing at point 
  (defun zetta-dired-dir-at-point ()
    (interactive)
    (let ((thing (dired-get-file-for-visit)))
      (if (file-directory-p thing)
          (message thing)
        (file-name-directory thing))
      ))


  (defun dired-ace-new-file ()
    "Use ace window to select a window for opening a file from dired."
    (interactive)
    (if (not (dired-get-file-for-visit)) (message "foo"))
    )

  (defun dired-ace-new-file-vert ()
    "Use ace window to select a window for opening a file from dired."
    (interactive)
    (let* ((file (zetta-dired-dir-at-point)))
      (if (file-directory-p (dired-get-file-for-visit))
          (dired-find-file)
        ;;(if (> (length (aw-window-list)) 1)
        (aw-select "" (lambda (window)
                        (aw-switch-to-window window)
                        (split-window-below)
                        (windmove-down)
                        (find-file (read-file-name "Enter a file name: " file))))
        ;;(find-file-other-window file)
        )))

  (defun dired-ace-new-file-hor ()
    "Use ace window to select a window for opening a file from dired."
    (interactive)
    (let* ((file (zetta-dired-dir-at-point)))
      (if (file-directory-p (dired-get-file-for-visit))
          (dired-find-file)
        (if (> (length (aw-window-list)) 1)
            (aw-select "" (lambda (window)
                            (aw-switch-to-window window)
                            (split-window-right)
                            (windmove-right)
                            (find-file (read-file-name "Enter a file name: " file))))
          (find-file-other-window file)))))


  (defun dired-ace-find-file ()
    "Use ace window to select a window for opening a file from dired."
    (interactive)
    (let ((file (dired-get-file-for-visit)))
      (if (file-directory-p (dired-get-file-for-visit))
          (dired-find-file)
        (if (> (length (aw-window-list)) 1)
            (aw-select "FOOBAR" (lambda (window)
                                  (aw-switch-to-window window)
                                  (find-file file)))
          (find-file-other-window file)))))






  (defun dired-ace-find-file-vert ()
    "Use ce window to select a window (to split vertically) for opening a file from dired."
    (interactive)
    (let ((file (dired-get-file-for-visit)))
      ;; hello world
      (if (file-directory-p (dired-get-file-for-visit))
          (dired-find-file)
        (if (> (length (aw-window-list)) 1)
            (aw-select "" (lambda (window)
                            (aw-switch-to-window window)
                            (split-window-below)
                            (windmove-down)
                            (find-file file)))
          (find-file-other-window file)))))



  (defun dired-ace-find-file-hor ()
    "Use ace window to select a window (to split horizontatlly) for opening a file from dired."
    (interactive)
    (let ((file (dired-get-file-for-visit)))
      (if (file-directory-p (dired-get-file-for-visit))
          (dired-find-file)
        (if (> (length (aw-window-list)) 1)
            (aw-select "" (lambda (window)
                            (aw-switch-to-window window)
                            (split-window-right)
                            (windmove-right)
                            (find-file file)))
          (find-file-other-window file))
        )
      ))

  (defun zetta-dired-do-flagged-delete ()
    "Performs delete and reverts buffer"
    (interactive)
    (dired-do-flagged-delete)
    (unless (file-remote-p default-directory) (revert-buffer)))

  (defun zetta-dired-do-delete ()
    "Performs delete and reverts buffer"
    (interactive)
    (dired-do-delete)
    (unless (file-remote-p default-directory) (revert-buffer)))

  (defun zetta-dired-do-copy ()
    "Performs copy and reverts buffer"
    (interactive)
    (dired-do-copy)
    (unless (file-remote-p default-directory) (revert-buffer)))

  (defun zetta-dired-do-rename ()
    "Performs delete and reverts buffer"
    (interactive)
    (dired-do-rename)
    (unless (file-remote-p default-directory) (revert-buffer)))

  (defun zetta-dired-create-directory ()
    "Performs delete and reverts buffer"
    (interactive)
    (call-interactively #'dired-create-directory)
    (unless (file-remote-p default-directory) (revert-buffer)))

  (defun zetta-dired-subtree-cycle ()
    (interactive)
    (dired-subtree-cycle 10)
    (unless (file-remote-p default-directory) (revert-buffer)))

  (defun zetta-dired-subtree-toggle ()
    (interactive)
    (dired-subtree-toggle)
    (unless (file-remote-p default-directory) (revert-buffer))
    (file-remote-p default-directory)
    )

  (defun zetta-dired-ag ()
    "Convenient helm ag for directory at point in dired buffers"
    (interactive)
    (let ((dir (if  (file-directory-p (dired-get-file-for-visit))
                   (dired-get-file-for-visit)
                 (file-name-directory (dired-get-file-for-visit)))))
      (helm-ag dir)))



  (defun zetta-dired-ranger-copy ()
    (interactive)
    (call-interactively 'dired-ranger-copy)
    (unless (file-remote-p default-directory) (revert-buffer))
    )

  (defun zetta-dired-ranger-paste ()
    (interactive)
    (call-interactively 'dired-ranger-paste)
    (unless (file-remote-p default-directory) (revert-buffer))
    )

  (defun zetta-dired-ranger-move ()
    (interactive)
    (call-interactively 'dired-ranger-move)
    (unless (file-remote-p default-directory) (revert-buffer))
    )


  (defun zetta-dired-open-in-chrome ()
    (interactive)
    (let (
          (file (dired-get-file-for-visit))
          )
      (shell-command (concat "open -a \"Google Chrome\" " file))
      ))

  (defun xah-open-in-external-app (&optional @fname)
    "Open the current file or dired marked files in external app.
The app is chosen from your OS's preference.

When called in emacs lisp, if @fname is given, open that.

URL `http://ergoemacs.org/emacs/emacs_dired_open_file_in_ext_apps.html'
Version 2019-11-04"
    (interactive)
    (let* (
           ($file-list
            (if @fname
                (progn (list @fname))
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
              (concat "open " (shell-quote-argument $fpath))))  $file-list))
         ((string-equal system-type "gnu/linux")
          (mapc
           (lambda ($fpath) (let ((process-connection-type nil))
                              (start-process "" nil "xdg-open" $fpath))) $file-list))))))


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
   "d" (** zetta-soda-drink-dired)
   "D" (** zetta-soda-cap-dired))


  :general
  (
   :keymaps '(dired-mode-map)
   "<tab>" 'zetta-dired-subtree-toggle
   "S-<tab>" 'zetta-dired-subtree-cycle
   "o" 'dired-ace-find-file
   "v" 'dired-ace-find-file-vert
   "h" 'dired-ace-find-file-hor
   "O" 'dired-ace-new-file
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
   ;;"gg" 'evil-goto-first-line
   "G" 'evil-goto-line
   "<C-return>" 'xah-open-in-external-app
   )

  :hook (
         (dired-mode . (lambda () (dired-hide-details-mode 1)))
         ;;(dired-mode . (lambda () (text-scale-set -2)))
         )
  )










