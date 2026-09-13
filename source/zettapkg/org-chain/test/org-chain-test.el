;;; org-chain-test.el --- ERT tests for the Org side of org-chain -*- lexical-binding: t -*-

;;; Commentary:

;; A real corpus in a temp directory, a stubbed terminal, a landing log
;; written the way the hook writes it.  Needs Org, org-ql and org-queue:
;;
;;   emacs -Q --batch -L source/zettapkg/org-chain -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-chain/test/org-chain-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'org)
(let* ((here (file-name-directory (or load-file-name buffer-file-name)))
       (root (expand-file-name "../../../../" here))
       (builds (expand-file-name "elpaca/builds" root)))
  (add-to-list 'load-path (expand-file-name ".." here))
  (add-to-list 'load-path (expand-file-name "source/zettapkg/org-queue" root))
  (when (file-directory-p builds)
    (dolist (dir (directory-files builds t "\\`[^.]"))
      (when (file-directory-p dir) (add-to-list 'load-path dir)))))
(require 'org-chain)

(defconst ocx-corpus
  "#+CATEGORY: work

* TODO Port the retries  :@deep:
:PROPERTIES:
:ID:       C-1
:Effort:   1:00
:AGENT_REPO: %s
:END:
Notes about the old client.
** Prompt
Replace the retry loop; keep the tests green.

* TODO No prompt here
:PROPERTIES:
:ID:       C-2
:END:

* AGENT In flight one
:PROPERTIES:
:ID:       C-3
:AGENT_SESSION: S-3
:END:
:LOGBOOK:
- State \"AGENT\"      from \"PROG\"       [2026-09-12 Sat 09:05]
- State \"PROG\"       from \"TODO\"       [2026-09-12 Sat 08:40]
:END:
Do the thing.

* AGENT In flight two
:PROPERTIES:
:ID:       C-4
:AGENT_SESSION: S-4
:END:
Do the other thing.

* AGENT In flight three
:PROPERTIES:
:ID:       C-5
:AGENT_SESSION: S-5
:END:
And a third.

* NEXT Landed earlier
:PROPERTIES:
:ID:       C-6
:AGENT_SESSION: S-6
:Effort:   0:40
:END:
:LOGBOOK:
- State \"NEXT\"       from \"AGENT\"      [2026-09-12 Sat 07:50]
- State \"AGENT\"      from \"PROG\"       [2026-09-11 Fri 22:10]
- State \"PROG\"       from \"TODO\"       [2026-09-11 Fri 21:45]
:END:
")

(defvar ocx-started nil "What the stubbed terminal was asked to run.")

(defmacro ocx-with-corpus (&rest forms)
  (declare (indent 0))
  `(let* ((dir (make-temp-file "ocx-" t))
          (file (expand-file-name "work.org" dir))
          (org-queue-files (list file))
          (org-agenda-files (list file))
          (org-queue-apply-log-file (expand-file-name "applies.el" dir))
          (org-queue-history-file (expand-file-name "history.el" dir))
          (org-chain-landings-file (expand-file-name "landings.el" dir))
          (org-chain-applied-file (expand-file-name "applied.el" dir))
          (org-id-locations-file (expand-file-name "ids" dir))
          (org-id-track-globally nil)
          (org-todo-keywords '((sequence "TODO(t!)" "NEXT(N!)" "PROG(p!)" "AGENT(a!)" "WAIT(w!)" "QUES(q!)" "HOLD(h!)" "|" "DONE(d!)" "NOPE(n!)")))
          (org-log-into-drawer t)
          (org-chain-terminal-function (lambda (name directory arguments)
                                         (setq ocx-started (list name directory arguments))))
          (org-chain-headless-function (lambda (name directory arguments)
                                         (setq ocx-started (list 'headless name directory arguments))))
          (ocx-started nil)
          (inhibit-message t))
     (with-temp-file file (insert (format ocx-corpus dir)))
     (unwind-protect
         (progn ,@forms)
       (dolist (buffer (buffer-list))
         (when (and (buffer-file-name buffer) (string-prefix-p dir (buffer-file-name buffer)))
           (with-current-buffer buffer (set-buffer-modified-p nil))
           (kill-buffer buffer)))
       (delete-directory dir t))))

(defun ocx-goto (file id)
  (with-current-buffer (find-file-noselect file)
    (revert-buffer t t t)
    (widen)
    (goto-char (point-min))
    (re-search-forward (concat ":ID:\\s-+" (regexp-quote id) "$"))
    (org-back-to-heading t)
    (current-buffer)))

(defun ocx-state (file id)
  (with-current-buffer (ocx-goto file id) (org-get-todo-state)))

(defun ocx-property (file id property)
  (with-current-buffer (ocx-goto file id) (org-entry-get (point) property)))


;;;; Kicking

(ert-deftest ocx/kicking-writes-the-session-transitions-and-starts-the-terminal-with-the-prompt ()
  (ocx-with-corpus
    ;; Three are in flight already: the fourth is refused.
    (with-current-buffer (ocx-goto file "C-1")
      (should-error (org-chain-kick) :type 'user-error))
    (should-not ocx-started)
    ;; C-u: kicked past the limit, and the log says so.
    (with-current-buffer (ocx-goto file "C-1")
      (org-chain-kick '(4)))
    (should (equal "AGENT" (ocx-state file "C-1")))
    (let ((session (ocx-property file "C-1" "AGENT_SESSION")))
      (should (= 36 (length session)))
      (should (equal (list "claude" "--session-id" session
                           "Replace the retry loop; keep the tests green.")
                     (nth 2 ocx-started))))
    (should (string-match-p "past the limit" (plist-get (car (org-queue-apply--log)) :note)))
    ;; Already in flight: refused again.
    (with-current-buffer (ocx-goto file "C-1")
      (should-error (org-chain-kick '(4)) :type 'user-error))))

(ert-deftest ocx/no-prompt-refuses-to-kick ()
  (ocx-with-corpus
    (with-current-buffer (ocx-goto file "C-2")
      (should (string-match-p "no prompt" (cadr (should-error (org-chain-kick '(4)) :type 'user-error)))))
    (should (equal "TODO" (ocx-state file "C-2")))))

(ert-deftest ocx/c-u-c-u-runs-headless ()
  (ocx-with-corpus
    (with-current-buffer (ocx-goto file "C-1")
      (org-chain-kick '(16)))
    (should (eq 'headless (car ocx-started)))
    (should (member "-p" (nth 3 ocx-started)))))


;;;; Landing

(ert-deftest ocx/landings-are-applied-once-and-orphans-reported ()
  (ocx-with-corpus
    (with-temp-file org-chain-landings-file
      (insert "(:session \"S-3\" :at 1789000000 :cwd \"/r\" :event stop :text \"done\")\n"
              "(:session \"S-4\" :at 1789000100 :cwd \"/r\" :event question :text \"which branch?\")\n"
              "(:session \"S-6\" :at 1789000200 :cwd \"/r\" :event stop :text \"again\")\n"
              "(:session \"S-Z\" :at 1789000300 :cwd \"/r\" :event stop :text \"nobody\")\n"))
    (let ((result (org-chain-land)))
      (should (= 2 (length (plist-get result :actions))))
      (should (equal '("S-6" "S-Z") (mapcar (lambda (l) (plist-get l :session)) org-chain--orphans))))
    (should (equal "NEXT" (ocx-state file "C-3")))
    (should (equal "QUES" (ocx-state file "C-4")))
    (with-current-buffer (ocx-goto file "C-4")
      (should (string-match-p "Agent asks: which branch\\?" (buffer-string))))
    ;; The landed entry reads as landed, and the harvest says so.
    (let ((landed (cl-find "C-3" (org-queue-harvest (list file))
                           :key (lambda (task) (plist-get task :id)) :test #'equal)))
      (should (plist-get landed :landed)))
    ;; A second read applies nothing.
    (let ((log (length (org-queue-apply--log))))
      (org-chain-land)
      (should (= log (length (org-queue-apply--log)))))
    (should (= 1 org-chain--asks))))

(ert-deftest ocx/the-chains-and-their-metrics ()
  (ocx-with-corpus
    (let* ((chains (org-chain-chains))
           (six (cl-find "C-6" chains :key (lambda (c) (plist-get c :id)) :test #'equal)))
      (should (= 2 (length chains)))   ; C-3 and C-6 have AGENT transitions; C-4/C-5 have no log
      (should (= 1 (plist-get (plist-get six :metrics) :iterations)))
      (should (= 580 (plist-get (plist-get six :metrics) :latency)))   ; 22:10 to 07:50
      (should-not (plist-get (plist-get six :metrics) :in-flight))
      (should (string-match-p "1 chain in flight" (org-chain-morning-line))))))

(provide 'org-chain-test)
;;; org-chain-test.el ends here
