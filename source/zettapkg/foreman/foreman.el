;; -*- lexical-binding: t; -*-
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Foreman stuff

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Utils
;; Server / File
(defun 4mn-detrampify-path (&optional dirname)
  "Returns buffer file name, excluding the ssh hops as provided
by TRAMP when inside of a remote buffer"
  (if dirname
      (nth 0 (-take-last 1 (split-string dirname ":")))
    (nth 0 (-take-last 1 (split-string (if (buffer-file-name) (buffer-file-name) "") ":")))))

(defun 4mn-get-tramp-context (&optional dirname)
  "Returns buffer file name, excluding the ssh hops as provided
by TRAMP when inside of a remote buffer"
  (mapconcat 'identity (if dirname
                           (butlast (split-string dirname ":"))
                         (butlast (split-string (if (buffer-file-name) (buffer-file-name) "") ":"))
                         ) ":"))

(defun recursive-count (regex string start)
  (if (string-match regex string start)
      (+ 1 (recursive-count regex string (match-end 0)))
    0))


(defun 4mn-get-tramp-remote-part ()
  (interactive)
  (if (< 0 (recursive-count ":" default-directory 0))
      (let* ((context default-directory)
             (n-colons (recursive-count ":" context 0))
             (remote-part0 (mapconcat 'identity (butlast (split-string context ":") 1) ":"))
             )
        (substring remote-part0 1 (length remote-part0))
        )
    ""
    )
  )

(defun 4mn-get-tramp-hops ()
  (interactive)
  (if (< 0 (recursive-count ":" default-directory 0))
      (let* ((context default-directory)
             (n-colons (recursive-count ":" context 0)) ;; unused
             (remote-part0 (mapconcat 'identity (butlast (split-string context ":") 1) ":"))
             (remote-part (substring remote-part0 1 (length remote-part0)))
             (hops (split-string remote-part "|"))
             )
        hops)
    '("")
    )
  )

(defun 4mn-get-tramp-hop-types ()
  (interactive)
  (if (< 0 (recursive-count ":" default-directory 0))
      (-map (lambda (hop) (nth 0 (split-string hop ":"))) (4mn-get-tramp-hops))
    '("")
    )
  )

(defun 4mn-get-tramp-context--containername ()
  (let (
        ;; nth 0: not handling for multiple docker hops
        (docker-hop (nth 0 (-filter
                            (lambda (hop) (string-match-p (regexp-quote "docker:") hop))
                            (4mn-get-tramp-hops))))
        )
    (when docker-hop
      (nth 1 (split-string docker-hop ":"))
      )
    )
  )

(defun 4mn-get-tramp-context--hostname ()
  (let (
        ;; nth 0: not handling for multiple ssh hops
        (ssh-hop (nth 0 (-filter
                         (lambda (hop) (string-match-p (regexp-quote "ssh:") hop))
                         (4mn-get-tramp-hops))))
        )
    (when ssh-hop
      (nth 1 (split-string ssh-hop ":"))
      )
    )
  )



;; Wrapper
(defun 4mn-get-wrapper (nm)
  "Return nm's file content."
  (let ((filePath (concat user-emacs-directory "source/lib/4mn_wrappers/" nm)))
    (with-temp-buffer
      (insert-file-contents filePath)
      (buffer-string))))

;; TMUX Session / Window
;; (defun tmux-get-file-session-name ()
;;   (replace-regexp-in-string
;;    (regexp-quote ".") "__"
;;    (f-filename (or
;;                 (project-root (project-current nil default-directory))
;;                 default-directory))))

;; (defun tmux-get-file-window-name ()
;;   (if (buffer-file-name)
;;       (replace-regexp-in-string
;;        (regexp-quote ".")
;;        "__"
;;        (f-filename (buffer-file-name)))
;;     (replace-regexp-in-string
;;      (regexp-quote "-")
;;      "_"
;;      (symbol-name major-mode))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Initialization
(setq 4mn-conf (ht-create))

(defun 4mn-get-key ()
  (cond
   ((and (buffer-file-name) (cdr (project-current nil)))
    (concat "project_dir:" (cdr (project-current nil)) "___" "file:" (buffer-file-name)))
   ((buffer-file-name)
    (concat "dir:" default-directory "___" "file:" (buffer-file-name)))
   ((not (buffer-file-name))
    (concat "mode:" (prin1-to-string major-mode) "___" (buffer-name)))
   ))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; API to 4mn controls
;; get
(defun g (key)
  (ht-get* 4mn-conf
           (4mn-get-key)
           (symbol-name major-mode)
           (if (symbolp key)
               (symbol-name key)
             key)))

;; set
(defun s (att val)
  (let ((key (4mn-get-key))
        (mode (symbol-name major-mode)))
    (setf (ht-get* 4mn-conf key mode att) val)))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Assemble commands
(defun 4mn-get-inner-cmd (&optional emacs)
  (condition-case nil
      (format (if emacs "%s %s %s" "%s %s %s")
              (format "cd %s &&\n " (g 'dir))
              (if (not (string= (g 'venv) "none"))
                  (format "source %s/bin/activate &&\n " (g 'venv))
                ""
                )
              (if (string= "yes" (g 'repl-p))
                  (format "%s " (g 'repl))
                (format "%s ./.4mn_code.%s "
                        (g 'exec)
                        (g 'suff))))
    (error "Not enough info")))

;; (defun 4mn-get-outer-cmd ()
;;   (interactive "P")
;;   ;; need their own functions
;;   (let ((session (g 'session))
;;         (window (g 'window)))
;;     (setq-local 4mn--local--outer-cmd
;;                 (cond ((not (tmux-session-exists-p))
;;                        ;; ... create new session + window
;;                        (format tmux-new-session-command-template 
;;                                session window session window))
;;                       ((and (tmux-session-exists-p) (not (tmux-session-window-exists-p))) 
;;                        ;; ... create new window in session
;;                        (format tmux-new-session-window-command-template 
;;                                session window session window))
;;                       ((and (tmux-session-exists-p) (tmux-session-window-exists-p)) 
;;                        ;; ...so replace the session-window
;;                        ;; TODO logic to handle if session is live already - don't want to overwrite whatever is running
;;                        (format tmux-replace-session-window-command-template 
;;                                session window window session window))))))

;; (defun 4mn--assemble-cmd ()
;;   (format "%s \"%s\" C-m" (4mn-get-outer-cmd) (4mn-get-inner-cmd)))





(provide 'foreman)



