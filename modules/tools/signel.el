;;; signel.el --- Configure signel (Signal messaging) -*- lexical-binding: t; -*-

(use-package signel
  :commands (signel-start signel-dashboard signel-chat)
  :config
  ;; Set `signel-account' to your Signal phone number (E.164, e.g. "+15551234567")
  ;; in ~/.private.el rather than here.

  ;; macOS notifications (D-Bus not available)
  (defun signel--macos-notify (title body)
    "Send a macOS notification with TITLE and BODY."
    (start-process "signel-notify" nil "osascript"
                   "-e" (format "display notification %S with title %S"
                                body title)))

  (advice-add 'notifications-notify :override
              (lambda (&rest args)
                (let ((title (plist-get args :title))
                      (body (plist-get args :body)))
                  (when title
                    (signel--macos-notify title (or body ""))))))

  ;; Message history persistence
  (defvar signel-history-directory
    (expand-file-name "signel-history" user-emacs-directory)
    "Directory for storing Signal message history.")

  (defun signel--history-file (chat-id)
    "Return the history file path for CHAT-ID."
    (let ((safe-name (replace-regexp-in-string "[^a-zA-Z0-9_+-]" "_" chat-id)))
      (expand-file-name (concat safe-name ".txt") signel-history-directory)))

  (defun signel--save-message (chat-id sender text)
    "Append a message from SENDER in CHAT-ID to the history file."
    (when (and chat-id text (not (string-empty-p text)))
      (mkdir signel-history-directory t)
      (let ((file (signel--history-file chat-id))
            (timestamp (format-time-string "%Y-%m-%d %H:%M:%S")))
        (write-region (format "[%s] %s: %s\n" timestamp sender text)
                      nil file 'append 'silent))))

  (defun signel--load-history (chat-id)
    "Load and insert message history for CHAT-ID into the current buffer."
    (let ((file (signel--history-file chat-id)))
      (when (file-exists-p file)
        (let ((inhibit-read-only t))
          (save-excursion
            (goto-char (point-min))
            (insert (with-temp-buffer
                      (insert-file-contents file)
                      (buffer-string))
                    "\n--- history above ---\n\n"))))))

  ;; Hook into message insertion to save history
  (advice-add 'signel--insert-msg :after
              (lambda (chat-id sender text &rest _)
                (signel--save-message chat-id sender text)))

  ;; Load history when opening a chat buffer
  (advice-add 'signel--get-chat-buffer :after
              (lambda (id &rest _)
                (when-let* ((buf (get-buffer (concat "*signel:" id "*"))))
                  (with-current-buffer buf
                    (unless (bound-and-true-p signel--history-loaded)
                      (signel--load-history id)
                      (setq-local signel--history-loaded t))))))

  (signel-start))
;;; signel.el ends here
