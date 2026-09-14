;;; org-chain.el --- Agent chains: kick, flight, landing, review -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org-ql "0.8"))
;; Keywords: convenience, outlines

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The Org and terminal half of org-chain.
;;
;;   `org-chain-kick'      the entry at point: refuse without a prompt or past
;;                         the chain limit (C-u overrides, and the override is
;;                         logged); write AGENT_SESSION; open a terminal running
;;                         `claude --session-id UUID "<prompt>"'; transition to
;;                         AGENT.  C-u C-u runs headless (`claude -p') in a git
;;                         worktree, the only mode a KICK_AT entry runs in.
;;   `org-chain-land'      read the landing log the Claude Code hooks append
;;                         to, transition AGENT to NEXT (a stop) or QUES (a
;;                         question) through the apply layer, once per line,
;;                         and report the lines no entry owns.
;;   `org-chain-watch'     watch the log; a timer is the fallback.
;;
;; No hook evaluates elisp in the daemon: the hook appends a plist line,
;; and Emacs reads the file.  No landing raises a prompt.  A question
;; shows in the mode line and nothing more; a stop is a notification
;; except inside a quiet window of the routine.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-id)
(require 'org-ql)
(require 'filenotify)
(require 'org-chain-core)
(require 'org-queue-harvest)
(require 'org-queue-apply)

(declare-function org-routine-in-window-p "org-routine" (kind &optional time))
(declare-function org-routine-blocks "org-routine" (&optional time))
(declare-function zetta-notify "alert" (message &optional title severity))
(declare-function vterm-mode "vterm")
(declare-function term-char-mode "term")
(declare-function vterm-send-string "vterm" (string &optional paste-p))
(declare-function vterm-send-return "vterm")

(defcustom org-chain-landings-file
  (expand-file-name "agent-landings.el" user-emacs-directory)
  "The log the Claude Code hooks append to: one plist per line."
  :type 'file
  :group 'org-chain)

(defcustom org-chain-applied-file
  (expand-file-name "agent-landings-applied.el" user-emacs-directory)
  "Where the keys of the landings already applied are kept."
  :type 'file
  :group 'org-chain)

(defcustom org-chain-default-latency 15
  "Minutes a run takes when nothing has been measured yet."
  :type 'integer
  :group 'org-chain)

(defcustom org-chain-default-cycle 20
  "Minutes of your own per cycle when nothing has been measured yet."
  :type 'integer
  :group 'org-chain)

(defcustom org-chain-default-block 240
  "Minutes in a block when the routine cannot say."
  :type 'integer
  :group 'org-chain)

(defvar org-chain-terminal-function #'org-chain--open-terminal
  "Function of (NAME DIRECTORY ARGUMENTS) that starts an interactive session.")

(defvar org-chain-headless-function #'org-chain--start-headless
  "Function of (NAME DIRECTORY ARGUMENTS) that starts an unattended session.")

(defvar org-chain--orphans nil
  "Landings no entry owned, from the last read.")

(defvar org-chain--asks 0
  "How many chains are waiting on an answer, for the mode line.")

(defvar org-chain--watch nil
  "The file-notify descriptor, when watching.")

(defvar org-chain-mode-line-string ""
  "The mode-line text: a question mark per chain waiting on you.")
(put 'org-chain-mode-line-string 'risky-local-variable t)

(defvar org-chain--timer nil
  "The fallback timer, when watching.")


;;;; Reading an entry

(defun org-chain--body ()
  "Return the entry's own body: under the heading to the first child, minus drawers."
  (save-excursion
    (org-back-to-heading t)
    (let ((end (save-excursion (or (outline-next-heading) (goto-char (point-max))) (point)))
          lines)
      (forward-line 1)
      (while (< (point) end)
        (cond
         ((looking-at-p "^[ \t]*:\\(PROPERTIES\\|LOGBOOK\\):")
          (re-search-forward "^[ \t]*:END:" end t)
          (forward-line 1))
         ((looking-at-p "^[ \t]*\\(SCHEDULED\\|DEADLINE\\|CLOSED\\):")
          (forward-line 1))
         (t (push (buffer-substring-no-properties (point) (line-end-position)) lines)
            (forward-line 1))))
      (string-join (nreverse lines) "\n"))))

(defun org-chain--children ()
  "Return the entry's direct children as (TITLE . BODY)."
  (save-excursion
    (org-back-to-heading t)
    (let ((level (org-current-level))
          (end (save-excursion (org-end-of-subtree t t) (point)))
          children)
      (while (and (outline-next-heading) (< (point) end))
        (when (= (org-current-level) (1+ level))
          (push (cons (org-get-heading t t t t) (org-chain--body)) children)))
      (nreverse children))))

(defun org-chain--kick-at ()
  "Return KICK_AT as a minute of the day, or nil."
  (when-let* ((raw (org-entry-get (point) "KICK_AT")))
    (when (string-match "\\([0-9]\\{1,2\\}\\):\\([0-9]\\{2\\}\\)" raw)
      (+ (* 60 (string-to-number (match-string 1 raw)))
         (string-to-number (match-string 2 raw))))))

(defun org-chain-entry-at-point ()
  "Return the entry at point as the plist the core takes."
  (save-excursion
    (org-back-to-heading t)
    (append (list :body (org-chain--body)
                  :children (org-chain--children)
                  :kick-at (org-chain--kick-at)
                  :agent-repo (org-entry-get (point) "AGENT_REPO")
                  :transitions-seconds
                  (mapcar (lambda (cell) (cons (car cell) (floor (float-time (cdr cell)))))
                          (org-queue-state-log)))
            (org-queue-harvest-entry))))

(defun org-chain-entries ()
  "Return the harvest, as the chain core reads it."
  (org-queue-harvest))


;;;; Kicking

(defun org-chain--open-terminal (name directory arguments)
  "Start ARGUMENTS in a terminal buffer NAME in DIRECTORY."
  (let ((default-directory (file-name-as-directory (expand-file-name directory))))
    (if (require 'vterm nil t)
        (let ((buffer (generate-new-buffer name)))
          (with-current-buffer buffer
            (vterm-mode)
            (vterm-send-string (combine-and-quote-strings arguments))
            (vterm-send-return))
          (pop-to-buffer buffer))
      (require 'term)
      (pop-to-buffer (apply #'make-term name (car arguments) nil (cdr arguments)))
      (term-char-mode))))

(defun org-chain--worktree (repo session)
  "Return a worktree of REPO for SESSION, creating it; REPO itself if not git."
  (let ((default-directory (file-name-as-directory (expand-file-name repo))))
    (if (not (file-directory-p ".git"))
        default-directory
      (let ((path (expand-file-name (concat ".worktrees/" session) default-directory)))
        (unless (file-directory-p path)
          (make-directory (file-name-directory path) t)
          (call-process "git" nil nil nil "worktree" "add" "--detach" path))
        path))))

(defun org-chain--start-headless (name directory arguments)
  "Start ARGUMENTS unattended in DIRECTORY, output to a buffer NAME."
  (let ((default-directory (file-name-as-directory (expand-file-name directory))))
    (apply #'start-process name (generate-new-buffer name) (car arguments) (cdr arguments))))

(defun org-chain--repo (entry)
  "Return the repository ENTRY runs in, asking once and remembering it."
  (or (plist-get entry :agent-repo)
      (org-decorate-core-property-safe entry "AI_REPO")
      (let ((dir (read-directory-name "Repository for this chain: " "~/source_code/")))
        (org-queue-apply-actions
         (list (list :action 'property :task entry :name "AGENT_REPO"
                     :value (abbreviate-file-name dir)))
         "chain repository")
        dir)))

(defun org-decorate-core-property-safe (entry name)
  "Return ENTRY's AI_ property NAME when org-decorate read it, else nil."
  (cdr (assoc name (plist-get entry :properties))))

;;;###autoload
(defun org-chain-kick (&optional arg)
  "Kick the entry at point: a session with its prompt as the first turn.
With ARG (\\[universal-argument]) kick past the chain limit, logged.
With two (\\[universal-argument] \\[universal-argument]) run headless in
a worktree, the mode a KICK_AT entry always uses."
  (interactive "P")
  (unless (derived-mode-p 'org-mode) (user-error "Not on an entry"))
  (org-id-get-create)
  (when (buffer-modified-p) (save-buffer))
  (let* ((entry (org-chain-entry-at-point))
         (override (and arg (>= (prefix-numeric-value arg) 4)))
         (headless (and arg (>= (prefix-numeric-value arg) 16)))
         (refusal (org-chain-core-kick-check entry (org-chain-entries) override))
         (mode (org-chain-core-kick-mode entry (not headless))))
    (when refusal (user-error "%s" refusal))
    (when (stringp mode) (user-error "%s" mode))
    (let* ((prompt (org-chain-core-prompt entry))
           (session (org-id-uuid))
           (repo (org-chain--repo entry))
           (directory (if (eq mode 'headless) (org-chain--worktree repo session) repo))
           (name (format "*chain: %s%s*" (plist-get entry :title)
                         (if (eq mode 'headless) " (headless)" ""))))
      (org-queue-apply-actions
       (list (list :action 'property :task entry :name "AGENT_SESSION" :value session)
             (list :action 'state :task entry :to org-chain-agent-state))
       (format "kick%s%s" (if override " (past the limit)" "")
               (if (eq mode 'headless) " headless" "")))
      (funcall (if (eq mode 'headless) org-chain-headless-function org-chain-terminal-function)
               name directory
               (org-chain-core-command prompt session (eq mode 'headless)))
      (message "Kicked %s as %s in %s" (plist-get entry :title) session
               (abbreviate-file-name directory)))))

(defun org-chain-kick-due ()
  "Kick, headless, every KICK_AT entry whose time has come before dawn."
  (let ((minute (let ((now (decode-time))) (+ (* 60 (nth 2 now)) (nth 1 now)))))
    (org-ql-select (org-queue-harvest-files) '(and (todo) (property "KICK_AT"))
      :action (lambda ()
                (let ((entry (org-chain-entry-at-point)))
                  (when (and (org-chain-core-kick-due-p entry minute)
                             (not (equal (plist-get entry :state) org-chain-agent-state)))
                    (org-chain-kick '(16))))))))


;;;; Landing

(defun org-chain--read-plists (file)
  "Return the plists in FILE, one per line, skipping lines that do not read."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (let (plists)
        (while (not (eobp))
          (let ((form (ignore-errors (read (current-buffer)))))
            (when (and form (listp form) (keywordp (car form)))
              (push form plists)))
          (forward-line 1))
        (nreverse plists)))))

(defun org-chain--normalise-landing (landing)
  "Return LANDING with `:event' a symbol and `:at' a number."
  (let ((event (plist-get landing :event))
        (at (plist-get landing :at)))
    (append (list :event (if (stringp event) (intern event) event)
                  :at (if (stringp at) (string-to-number at) at))
            landing)))

(defun org-chain-read-landings ()
  "Return every landing in the log, normalised."
  (mapcar #'org-chain--normalise-landing (org-chain--read-plists org-chain-landings-file)))

(defun org-chain--applied ()
  (car (org-chain--read-plists org-chain-applied-file)))

(defun org-chain--record-applied (keys)
  (make-directory (file-name-directory org-chain-applied-file) t)
  (with-temp-file org-chain-applied-file
    (let ((print-length nil) (print-level nil))
      (prin1 (list :keys (seq-take keys 500)) (current-buffer))
      (insert "\n"))))

(defun org-chain--quiet-p ()
  "Return non-nil inside a quiet window of the routine."
  (and (fboundp 'org-routine-in-window-p)
       (ignore-errors (org-routine-in-window-p :quiet))))

;;;###autoload
(defun org-chain-land ()
  "Apply the landings the hooks have logged since the last read."
  (interactive)
  (let* ((applied (plist-get (org-chain--applied) :keys))
         (result (org-chain-core-land (org-chain-read-landings) (org-chain-entries) applied))
         (actions (plist-get result :actions)))
    (dolist (action actions)
      (let* ((landing (plist-get action :landing))
             (task (plist-get action :task))
             (org-inhibit-logging 'note))
        (org-queue-apply-actions
         (append (list (list :action 'state :task task :to (plist-get action :to)))
                 (when (and (eq (plist-get landing :event) 'question)
                            (plist-get landing :text))
                   (list (list :action 'body-line :task task
                               :text (format "Agent asks: %s" (plist-get landing :text))))))
         (format "landing: %s" (plist-get landing :event)))
        (if (eq (plist-get landing :event) 'question)
            (cl-incf org-chain--asks)
          (unless (org-chain--quiet-p)
            (when (fboundp 'zetta-notify)
              (zetta-notify (format "%s landed" (plist-get task :title)) "Chain"))))))
    (setq org-chain--orphans (plist-get result :orphans))
    (org-chain--record-applied (plist-get result :applied))
    (org-chain--update-mode-line)
    (when (called-interactively-p 'any)
      (message "%d landing%s applied, %d orphan%s"
               (length actions) (if (= 1 (length actions)) "" "s")
               (length org-chain--orphans) (if (= 1 (length org-chain--orphans)) "" "s")))
    result))

(defun org-chain--update-mode-line ()
  "Show the chains waiting on an answer, quietly."
  (setq org-chain--asks
        (length (org-ql-select (org-queue-harvest-files)
                  '(and (todo "QUES") (property "AGENT_SESSION")))))
  (let ((text (if (> org-chain--asks 0)
                  (format " ?%d" org-chain--asks)
                "")))
    (setq global-mode-string
          (append (delete 'org-chain-mode-line-string (or global-mode-string nil))
                  (list 'org-chain-mode-line-string)))
    (setq org-chain-mode-line-string text)
    (force-mode-line-update t)))

;;;###autoload
(defun org-chain-watch ()
  "Watch the landing log; read it whenever it changes, and every minute besides."
  (interactive)
  (make-directory (file-name-directory org-chain-landings-file) t)
  (unless (file-exists-p org-chain-landings-file)
    (with-temp-file org-chain-landings-file))
  (unless org-chain--watch
    (setq org-chain--watch
          (ignore-errors
            (file-notify-add-watch org-chain-landings-file '(change)
                                   (lambda (_event) (org-chain-land))))))
  (unless org-chain--timer
    (setq org-chain--timer (run-with-timer 60 60 #'org-chain-land)))
  (org-chain-land))

(defun org-chain-unwatch ()
  "Stop watching the landing log."
  (interactive)
  (when org-chain--watch (ignore-errors (file-notify-rm-watch org-chain--watch)))
  (when org-chain--timer (cancel-timer org-chain--timer))
  (setq org-chain--watch nil org-chain--timer nil))


;;;; Predicates for the views

(org-ql-defpred landed-from-agent ()
  "Return non-nil if the entry is NEXT straight from AGENT."
  :body (org-chain-core-landed-p
         (mapcar (lambda (cell) (cons (car cell) (floor (float-time (cdr cell)))))
                 (org-queue-state-log))))

(org-ql-defpred agent-asks ()
  "Return non-nil if the entry is a chain waiting on an answer."
  :body (and (equal (org-get-todo-state) "QUES")
             (org-entry-get (point) "AGENT_SESSION")))


;;;; Metrics, the morning line, the close and the pack

(defun org-chain-chains (&optional from to)
  "Return every entry with an AGENT transition, with its metrics.
FROM and TO, YYYYMMDD, restrict to chains that moved in the window."
  (let (chains)
    (org-ql-select (org-queue-harvest-files) '(or (todo) (done))
      :action (lambda ()
                (let* ((entry (org-chain-entry-at-point))
                       (transitions (plist-get entry :transitions-seconds)))
                  (when (cl-some (lambda (cell) (equal (car cell) org-chain-agent-state))
                                 transitions)
                    (when (or (null from)
                              (let ((last (cdr (car (last transitions)))))
                                (and (>= last (org-queue-daylog--day-start-safe from))
                                     (< last (+ 86400 (org-queue-daylog--day-start-safe to))))))
                      (push (append (list :metrics (org-chain-core-metrics transitions))
                                    entry)
                            chains))))))
    (nreverse chains)))

(defun org-queue-daylog--day-start-safe (date)
  "Midnight opening DATE, YYYYMMDD, in epoch seconds."
  (floor (float-time (encode-time 0 0 0 (% date 100) (% (/ date 100) 100) (/ date 10000)))))

(defun org-chain--measured (chains key default)
  "Return the median of KEY over CHAINS' metrics, or DEFAULT.
The median, because one overnight run would drag a mean past the block."
  (let ((values (sort (delq nil (mapcar (lambda (c) (plist-get (plist-get c :metrics) key)) chains))
                      #'<)))
    (if values (nth (/ (length values) 2) values) default)))

(defun org-chain--block-minutes ()
  "Return the minutes of today's first focus block, from the routine."
  (or (and (fboundp 'org-routine-blocks)
           (when-let* ((focus (cl-find 'focus (ignore-errors (org-routine-blocks))
                                       :key (lambda (b) (plist-get b :kind)))))
             (plist-get focus :minutes)))
      org-chain-default-block))

(defun org-chain-morning-line ()
  "The morning report's line on chains: in flight, landings, review minutes."
  (let* ((chains (org-chain-chains))
         (flying (cl-count-if (lambda (c) (plist-get (plist-get c :metrics) :in-flight)) chains)))
    (org-chain-core-morning-line
     flying
     (org-chain--measured chains :latency org-chain-default-latency)
     (org-chain--measured chains :human org-chain-default-cycle)
     (org-chain--block-minutes))))

(defun org-chain-close-chains ()
  "The chains for the close: each with its prompt, or without one."
  (mapcar (lambda (chain)
            (list :task chain :prompt (org-chain-core-prompt chain)))
          (cl-remove-if-not (lambda (c) (plist-get (plist-get c :metrics) :in-flight))
                            (org-chain-chains))))

(defun org-chain-review-lines (from to)
  "The chains' week for the pack: one line per chain that moved."
  (mapcar (lambda (chain)
            (let ((m (plist-get chain :metrics)))
              (format "%-40s %d kick%s, latency %s, review lag %s, you %s / agent %s%s"
                      (truncate-string-to-width (plist-get chain :title) 40)
                      (plist-get m :iterations) (if (= 1 (plist-get m :iterations)) "" "s")
                      (if (plist-get m :latency) (format "%dm" (plist-get m :latency)) "--")
                      (if (plist-get m :review-lag) (format "%dm" (plist-get m :review-lag)) "--")
                      (org-queue-core-format-minutes (plist-get m :human))
                      (org-queue-core-format-minutes (plist-get m :machine))
                      (if (plist-get m :in-flight) ", in flight" ""))))
          (org-chain-chains from to)))

(provide 'org-chain)
;;; org-chain.el ends here
