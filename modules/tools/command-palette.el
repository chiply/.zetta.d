;;; command-palette.el --- Rofi-style command palette via emacsclient -*- lexical-binding: t; -*-

;; Start the Emacs server so emacsclient can connect
(use-package server
  :ensure nil
  :demand t
  :config
  (unless (server-running-p)
    (server-start)))

;; -- Popup frame infrastructure (adapted from Prot) -------------------------

(defvar zetta-popup-frame nil
  "Reference to the current popup frame, if any.")

(defvar zetta-popup-previous-app nil
  "Name of the app that was frontmost before the popup opened.")

(defun zetta-popup-frame-delete (&rest _)
  "Delete the popup frame if it exists, and return focus to the previous app."
  (when (and zetta-popup-frame (frame-live-p zetta-popup-frame))
    (delete-frame zetta-popup-frame t)
    (setq zetta-popup-frame nil)
    (when zetta-popup-previous-app
      (let ((app zetta-popup-previous-app))
        (setq zetta-popup-previous-app nil)
        (start-process "refocus" nil "open" "-a" app)))))

(defun zetta-popup-frame-cleanup-on-minibuffer-exit ()
  "Clean up popup frame when minibuffer exits for any reason."
  (when (and zetta-popup-frame
             (frame-live-p zetta-popup-frame)
             (not (minibufferp)))
    (zetta-popup-frame-delete)))

(defun zetta-popup-frame--make ()
  "Create and return a centered popup frame. Cleans up any stale one first."
  (zetta-popup-frame-delete)
  (let* ((display-w (display-pixel-width))
         (display-h (display-pixel-height))
         (border 16)
         (frame-w (/ (* display-w 3) 10))
         (frame-h (/ display-h 2))
         (total-w (+ frame-w (* 2 border)))
         (total-h (+ frame-h (* 2 border)))
         (frame-x (/ (- display-w total-w) 2))
         (frame-y (/ (- display-h total-h) 2))
         (frame (make-frame
                 `((zetta-popup-frame . t)
                   (name . "command-palette")
                   (width . 60)
                   (height . 1)
                   (minibuffer . only)
                   (undecorated . t)
                   (fullscreen . nil)
                   (internal-border-width . ,border)
                   (left . ,frame-x)
                   (top . ,frame-y)
                   (pixel-width . ,frame-w)
                   (pixel-height . ,frame-h)))))
    (setq zetta-popup-frame frame)
    (set-frame-size frame frame-w frame-h t)
    (set-frame-position frame frame-x frame-y)
    (select-frame-set-input-focus frame)
    frame))

(defun zetta-popup-frame-run (fn &rest args)
  "Run FN with ARGS in a popup frame that always cleans up."
  (zetta-popup-frame--make)
  (add-hook 'minibuffer-exit-hook #'zetta-popup-frame-delete)
  (unwind-protect
      (apply fn args)
    (remove-hook 'minibuffer-exit-hook #'zetta-popup-frame-delete)
    (zetta-popup-frame-delete)))

;; -- App launcher ------------------------------------------------------------

(defvar zetta-app-dirs
  '("/Applications"
    "/System/Applications"
    "/System/Applications/Utilities"
    "~/Applications")
  "Directories to search for macOS applications.")

(defun zetta-app-launcher--list-apps ()
  "Return a list of macOS application names."
  (let (apps)
    (dolist (dir zetta-app-dirs)
      (let ((expanded (expand-file-name dir)))
        (when (file-directory-p expanded)
          (dolist (f (directory-files expanded nil "\\.app$"))
            (push (cons (file-name-sans-extension f)
                        (expand-file-name f expanded))
                  apps)))))
    (cl-sort (delete-dups apps) #'string< :key #'car)))

(defun zetta-app-launcher ()
  "Launch a macOS application using completing-read."
  (interactive)
  (let* ((apps (zetta-app-launcher--list-apps))
         (choice (completing-read "Launch: " apps nil t)))
    (when choice
      (let ((path (cdr (assoc choice apps))))
        (start-process "open" nil "open" "-a" path)))))

;; -- Popup commands ----------------------------------------------------------

(defun zetta-command-palette ()
  "Run execute-extended-command in a popup frame."
  (interactive)
  (zetta-popup-frame-run #'execute-extended-command nil))

(defun zetta-popup-app-launcher ()
  "Run the app launcher in a popup frame."
  (interactive)
  (zetta-popup-frame-run #'zetta-app-launcher))

;; -- Org capture popup -------------------------------------------------------

(defun zetta-popup-org-capture ()
  "Run org-capture in a popup frame that closes after finalize."
  (interactive)
  (let* ((display-w (display-pixel-width))
         (display-h (display-pixel-height))
         (border 16)
         (frame-w (/ (* display-w 3) 10))
         (frame-h (/ display-h 2))
         (total-w (+ frame-w (* 2 border)))
         (total-h (+ frame-h (* 2 border)))
         (frame-x (/ (- display-w total-w) 2))
         (frame-y (/ (- display-h total-h) 2))
         (frame (make-frame
                 `((zetta-popup-frame . t)
                   (name . "command-palette")
                   (fullscreen . nil)
                   (internal-border-width . ,border)
                   (left . ,frame-x)
                   (top . ,frame-y)
                   (width . 80)
                   (height . 20)))))
    (setq zetta-popup-frame frame)
    (set-frame-size frame frame-w frame-h t)
    (set-frame-position frame frame-x frame-y)
    (select-frame-set-input-focus frame)
    (switch-to-buffer (get-buffer-create "*capture*"))
    (delete-other-windows)
    (condition-case nil
        (cl-letf (((symbol-function 'org-switch-to-buffer-other-window)
                   (lambda (buf &rest _) (switch-to-buffer buf))))
          (org-capture))
      (error (zetta-popup-frame-delete)))))

(defun zetta-popup-capture-delete-other-windows ()
  "Delete other windows in popup frame when capture buffer opens."
  (when (and zetta-popup-frame (frame-live-p zetta-popup-frame))
    (with-selected-frame zetta-popup-frame
      (delete-other-windows))
    ;; Also catch delayed window splits
    (run-at-time 0.1 nil
                 (lambda ()
                   (when (and zetta-popup-frame (frame-live-p zetta-popup-frame))
                     (with-selected-frame zetta-popup-frame
                       (delete-other-windows)))))))

(add-hook 'org-capture-mode-hook #'zetta-popup-capture-delete-other-windows)
(add-hook 'org-capture-after-finalize-hook #'zetta-popup-frame-delete)

;; -- Clipboard monitor (global clipboard → kill ring) -----------------------

(setq save-interprogram-paste-before-kill t)

(defvar zetta-clipboard-timer nil
  "Timer for polling the system clipboard.")

(defvar zetta-clipboard-last ""
  "Last clipboard content seen by the monitor.")

(defvar zetta-clipboard-poll-interval 1
  "Seconds between clipboard polls.")

(defun zetta-clipboard-poll ()
  "Check macOS clipboard and push new content into the kill ring."
  (condition-case nil
      (let ((current (with-temp-buffer
                       (call-process "pbpaste" nil t nil)
                       (buffer-string))))
        (when (and current
                   (not (string-empty-p current))
                   (not (string= current zetta-clipboard-last))
                   ;; Don't clobber the kill ring head if it has the same
                   ;; text — it may carry a yank-handler (e.g. evil
                   ;; linewise yank) that would be lost by kill-new.
                   (not (string= current (substring-no-properties
                                          (or (car kill-ring) "")))))
          (setq zetta-clipboard-last current)
          (kill-new current)))
    (error nil)))

(defun zetta-clipboard-monitor-start ()
  "Start polling the macOS clipboard."
  (interactive)
  (zetta-clipboard-monitor-stop)
  (setq zetta-clipboard-last
        (or (ignore-errors
              (with-temp-buffer
                (call-process "pbpaste" nil t nil)
                (buffer-string)))
            ""))
  (setq zetta-clipboard-timer
        (run-at-time zetta-clipboard-poll-interval
                     zetta-clipboard-poll-interval
                     #'zetta-clipboard-poll)))

(defun zetta-clipboard-monitor-stop ()
  "Stop polling the macOS clipboard."
  (interactive)
  (when zetta-clipboard-timer
    (cancel-timer zetta-clipboard-timer)
    (setq zetta-clipboard-timer nil)))

;; Start monitoring on load
(zetta-clipboard-monitor-start)

;; -- Kill ring browser (popup clipboard manager) ----------------------------

(defun zetta-kill-ring-browser ()
  "Browse the kill ring with completing-read and copy selection to clipboard."
  (interactive)
  (let* ((entries (cl-remove-duplicates
                   (mapcar (lambda (s)
                             (replace-regexp-in-string
                              "[ \t\n]+" " "
                              (string-trim (substring-no-properties s))))
                           kill-ring)
                   :test #'string=))
         (choice (minibuffer-with-setup-hook
                     (lambda ()
                       (setq-local vertico-sort-function nil))
                   (completing-read "Clipboard: " entries nil t))))
    (when choice
      ;; Find the original (non-truncated) entry
      (let ((original (cl-find-if
                       (lambda (s)
                         (string= choice
                                  (replace-regexp-in-string
                                   "[ \t\n]+" " "
                                   (string-trim (substring-no-properties s)))))
                       kill-ring)))
        (when original
          (kill-new original)
          (with-temp-buffer
            (insert original)
            (call-process-region (point-min) (point-max) "pbcopy")))))))

(defun zetta-popup-kill-ring ()
  "Browse the kill ring in a popup frame."
  (interactive)
  (zetta-popup-frame-run #'zetta-kill-ring-browser))

(provide 'command-palette)
;;; command-palette.el ends here
