;;; multi-compile-executors.el --- Executor system for multi-compile -*- lexical-binding: t; -*-

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
(setq default-buffer-replace-policy "default-buffer-replace-policy")

(defun zmc-execute (program cmd bufnm &optional buffer-replace-policy transient-name)
  (if (not (member program
                   '("detached" "detached+" "async-shell-command"
                     "async-shell-command+" "vterm" "compile"
                     "detached-compile")))
      (error "zmc-execute: program %s not supported" program))
  (let ((cmd (progn
               (when (string-match " &" cmd)
                 (message "cmd contains &"))
               (string-replace " &" "" cmd)))
        (bufnm (zmc-compute-bufnm))
        (buffer-replace-policy (or buffer-replace-policy
                                   default-buffer-replace-policy)))
    (cond ((string= buffer-replace-policy "replace")
           (when (get-buffer bufnm)
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
    (unless (string= (buffer-name original-buffer)
                     (cond
                      ((bufferp new-buffer)
                       (buffer-name new-buffer))
                      ((stringp new-buffer) new-buffer)))
      (switch-to-buffer new-buffer)
      (set-window-dedicated-p nil nil)
      (switch-to-prev-buffer nil 'bury)
      (display-buffer new-buffer)
      (select-window original-window))
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
        (process-connection-type nil))
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
  (let* ((bufnm (zmc-compute-bufnm)))
    (when (get-buffer bufnm) (kill-buffer bufnm))
    (let* ((vterm-buffer (save-window-excursion (vterm bufnm)))
           (vterm-process (get-buffer-process vterm-buffer)))
      (process-send-string vterm-process (concat cmd "\n"))
      bufnm)))

;;; multi-compile-executors.el ends here
