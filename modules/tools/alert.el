;;; alert.el --- Configure alert -*- lexical-binding: t; -*-

;;;; Notification sound
;;
;; The AppleScript `sound name' clause is deliberately NOT used.  osascript
;; notifications are attributed to Script Editor, and Notification Center
;; drops the sound unless "Play sound for notifications" is enabled for
;; Script Editor under System Settings > Notifications -- a per-app toggle
;; that is not readable from a script on macOS 26, so we cannot detect or
;; repair it.  Playing the file ourselves makes the sound independent of it.
;; The cost is that Notification Center is no longer the one deciding when to
;; stay quiet, so `zetta-notify-respect-focus' has to honour Focus by hand.

(defcustom zetta-notify-sound "Frog"
  "System sound played alongside each desktop notification.
The value is a sound name as found in /System/Library/Sounds or
~/Library/Sounds, without the extension; nil plays nothing."
  :type '(choice (const :tag "Silent" nil) (string :tag "Sound name"))
  :group 'zetta)

(defcustom zetta-notify-respect-focus t
  "When non-nil, stay silent while a macOS Focus mode is active."
  :type 'boolean
  :group 'zetta)

(defconst zetta-notify--focus-db
  (expand-file-name "~/Library/DoNotDisturb/DB/Assertions.json")
  "State file macOS uses to record which Focus modes are asserted.")

(defun zetta-notify--focus-active-p ()
  "Return non-nil when a macOS Focus mode is currently asserted.
Best effort: an unreadable or unparseable state file counts as no Focus,
so a notification is never silently lost to a bad read."
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents zetta-notify--focus-db)
      (goto-char (point-min))
      (let ((data (alist-get 'data (json-parse-buffer :object-type 'alist
                                                      :array-type 'list))))
        (seq-some (lambda (rec) (alist-get 'storeAssertionRecords rec)) data)))))

(defun zetta-notify--sound-file (name)
  "Return a readable sound file for NAME, or nil if there is none."
  (seq-some (lambda (dir)
              (seq-find #'file-readable-p
                        (mapcar (lambda (ext)
                                  (expand-file-name (concat name ext) dir))
                                '(".aiff" ".aif" ".wav" ".m4a" ".caf"))))
            '("/System/Library/Sounds" "~/Library/Sounds")))

(defun zetta-notify--play-sound ()
  "Play `zetta-notify-sound' asynchronously, unless Focus says otherwise."
  (when-let* ((name zetta-notify-sound)
              ((not (and zetta-notify-respect-focus
                         (zetta-notify--focus-active-p))))
              (file (zetta-notify--sound-file name)))
    ;; Async: a notification must never block the command loop.
    (start-process "zetta-notify-sound" nil "afplay" file)))

(use-package alert
  :defer t)

;;;; osx-notifier override
;;
;; Deliberately top level in a `with-eval-after-load' rather than inside the
;; `use-package' :config body.  Elpaca *queues* :config forms instead of
;; running them on load, and a form queued from an earlier load can be
;; processed later and quietly reinstall a stale definition over a newer
;; one.  That is not hypothetical: it reverted this function mid-session,
;; putting the `sound name' clause back and making notifications silent
;; again.  At top level the definition is reinstalled by any plain `load'
;; of this file, which is also what makes it re-evaluable from emacsclient.

(with-eval-after-load 'alert
  (setq alert-default-style 'osx-notifier)

  (defun alert-osx-notifier-notify (info)
    ;; Deliberately *not* via `alert-encode-string': that returns a unibyte
    ;; string, so %S renders every non-ASCII char as a \302\267-style escape
    ;; and osascript rejects the whole line with a syntax error.  Titles here
    ;; routinely carry a middle dot ("Claude Code · zetta.d"), so that path
    ;; silently swallowed the notification.  `call-process' encodes the
    ;; argument itself, and %S doubles as the AppleScript string quoter
    ;; (elisp's escaping is a superset of AppleScript's).
    (let ((script (format "display notification %S with title %S"
                          (plist-get info :message)
                          (plist-get info :title))))
      (with-temp-buffer
        ;; Keep stderr: a failing osascript used to be invisible.
        (unless (eq 0 (call-process "osascript" nil t nil "-e" script))
          (message "alert: osascript failed: %s"
                   (string-trim (buffer-string))))))
    (zetta-notify--play-sound)
    (alert-message-notify info)))

;;;; Shared notification entry point
;;
;; Anything that needs to interrupt the user from outside the current
;; buffer funnels through `zetta-notify' rather than calling `alert'
;; directly, so the style, sound and title convention live in one place.
;; Callers so far: zmc compile sentinels (multi-compile-executors.el),
;; gptel long responses (tools/ai.el), and Claude Code's hooks, which
;; reach it from the shell via
;;
;;   emacsclient --eval '(zetta-notify "message" "title")'
;;
;; (see ~/.claude/claude-notify.sh).  Defined at top level, not inside
;; the `use-package' body, so the autoload is available the moment this
;; module is loaded; `alert' itself is pulled in on first use.

(defun zetta-notify (message &optional title severity)
  "Raise MESSAGE as a desktop notification titled TITLE.
SEVERITY is an `alert' severity symbol and defaults to `normal'.
Returns MESSAGE, so the form reads usefully over `emacsclient --eval'."
  (require 'alert)
  (alert message
         :title (or title "Emacs")
         :severity (or severity 'normal))
  message)

;;; alert.el ends here
