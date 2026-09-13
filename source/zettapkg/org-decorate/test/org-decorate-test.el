;;; org-decorate-test.el --- ERT tests for the Org side of org-decorate -*- lexical-binding: t -*-

;;; Commentary:

;; A stubbed model over a real inbox in a temp directory: the request
;; chain, the writes, the accept and reject keys, the duplicate check,
;; the git reader.  Needs Org, org-ql and org-queue:
;;
;;   emacs -Q --batch -L source/zettapkg/org-decorate -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-decorate/test/org-decorate-test.el \
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
(require 'org-decorate)

(defconst odx-fixture
  (expand-file-name "fixtures/inbox.org" (file-name-directory (or load-file-name buffer-file-name))))

(defconst odx-todo
  "#+CATEGORY: buy

* TODO Buy socks  :household:
:PROPERTIES:
:ID:       OPEN-1
:Effort:   0:10
:END:

* DONE Buy dryer sheets
CLOSED: [2026-08-01 Sat 10:00]
:PROPERTIES:
:ID:       DONE-1
:END:
")

(defconst odx-proposal
  '(:kind "task" :keyword "TODO" :target "buy.org" :category "buy"
    :context "@errand" :effort "0:10" :deadline_phrase "friday" :deadline_type "hard"
    :why "a purchasable household item" :confidence 0.88
    :field_confidence ((kind . 0.95) (target . 0.9))))

(defmacro odx-with-corpus (&rest forms)
  "Run FORMS with `inbox' and `todo' files in a temp dir and a stubbed model."
  (declare (indent 0))
  `(let* ((dir (make-temp-file "odx-" t))
          (inbox (expand-file-name "inbox.org" dir))
          (todo (expand-file-name "buy.org" dir))
          (org-agenda-files (list todo))
          (org-decorate-files (list todo))
          (org-decorate-inbox-file inbox)
          (org-queue-files (list todo inbox))
          (org-queue-inbox-file inbox)
          (org-queue-apply-log-file (expand-file-name "applies.el" dir))
          (org-queue-history-file (expand-file-name "history.el" dir))
          (org-decorate-corrections-file (expand-file-name "corrections.el" dir))
          (org-id-locations-file (expand-file-name "ids" dir))
          (org-id-track-globally nil)
          (org-todo-keywords '((sequence "TODO(t!)" "NEXT(N!)" "PROG(p!)" "WAIT(w!)" "QUES(q!)" "HOLD(h!)" "IDEA(i!)" "|" "DONE(d!)" "NOPE(n!)")))
          (org-global-properties '(("Effort_ALL" . "0 0:05 0:10 0:15 0:20 0:30 0:45 1:00")
                                   ("IMPACT_ALL" . "1 2 3 4 5")
                                   ("DEADLINE_TYPE_ALL" . "hard soft")))
          (org-tag-alist '((:startgroup) ("@deep" . ?d) ("@errand" . ?e) (:endgroup)
                           (:startgroup) ("@fresh" . ?f) ("@tired" . ?y) (:endgroup)))
          (org-log-redeadline nil) (org-log-reschedule nil) (org-log-into-drawer t)
          (org-log-refile nil)
          (org-decorate-model-function
           (lambda (_prompt _schema callback) (funcall callback odx-proposal)))
          (org-decorate-neighbours-function (lambda (_entry callback) (funcall callback nil)))
          (inhibit-message t))
     (copy-file odx-fixture inbox)
     (with-temp-file todo (insert odx-todo))
     (unwind-protect
         (progn ,@forms)
       (dolist (buffer (buffer-list))
         (when (and (buffer-file-name buffer) (string-prefix-p dir (buffer-file-name buffer)))
           (with-current-buffer buffer (set-buffer-modified-p nil))
           (kill-buffer buffer)))
       (delete-directory dir t))))

(defun odx-property (file id property)
  (with-temp-buffer
    (insert-file-contents file)
    (org-mode)
    (goto-char (point-min))
    (when (re-search-forward (concat ":ID:\\s-+" (regexp-quote id) "$") nil t)
      (org-back-to-heading t)
      (org-entry-get (point) property))))

(defun odx-entry (file id)
  (with-current-buffer (find-file-noselect file)
    (revert-buffer t t t)
    (org-with-wide-buffer
     (goto-char (point-min))
     (re-search-forward (concat ":ID:\\s-+" (regexp-quote id) "$"))
     (org-decorate-entry-at-point))))


;;;; Dates, against org-read-date

(ert-deftest odx/phrases-resolve-the-way-org-read-date-reads-them ()
  ;; CREATED is Thursday 2026-09-03.
  (should (= 20260908 (org-decorate-resolve-date "tue" 20260903)))
  (should (= 20260904 (org-decorate-resolve-date "tomorrow" 20260903)))
  (should (= 20260904 (org-decorate-resolve-date "by friday" 20260903)))
  (should (= 20260910 (car (org-decorate-resolve-date "thursday at 2pm" 20260903))))
  (should (equal "14:00" (cdr (org-decorate-resolve-date "thursday at 2pm" 20260903))))
  (should-not (org-decorate-resolve-date "whenever you like" 20260903))
  (should-not (org-decorate-resolve-date "" 20260903)))


;;;; The lists

(ert-deftest odx/the-lists-come-from-org-state ()
  (odx-with-corpus
    (let ((lists (org-decorate-lists)))
      (should (equal '("TODO" "WAIT" "QUES" "HOLD" "IDEA") (plist-get lists :keywords)))
      (should (equal '("buy") (plist-get lists :categories)))
      (should (member "buy.org" (plist-get lists :targets)))
      (should (equal '("@deep" "@errand") (plist-get lists :contexts)))
      (should (equal '("household") (plist-get lists :tags)))
      (should (member "0:10" (plist-get lists :efforts))))))


;;;; Decorating

(ert-deftest odx/decorating-writes-ai-properties-and-leaves-the-text-alone ()
  (odx-with-corpus
    (let ((before (with-temp-buffer (insert-file-contents inbox)
                                    (buffer-substring (point-min) (progn (goto-char (point-min))
                                                                         (search-forward "* dryer sheets")
                                                                         (line-end-position))))))
      (org-decorate-inbox inbox)
      (should (equal "TODO" (odx-property inbox "INBOX-1" "AI_KEYWORD")))
      (should (equal "buy.org" (odx-property inbox "INBOX-1" "AI_TARGET")))
      (should (equal "0:10" (odx-property inbox "INBOX-1" "AI_EFFORT")))
      ;; "friday" written on Friday 2026-08-14 is the 21st.
      (should (equal "2026-08-21" (odx-property inbox "INBOX-1" "AI_DEADLINE")))
      (should (odx-property inbox "INBOX-1" "AI_HASH"))
      (should (string-match-p "prompt=1 schema=1" (odx-property inbox "INBOX-1" "AI_STAMP")))
      ;; The heading is byte-identical.
      (should (equal before (with-temp-buffer (insert-file-contents inbox)
                                              (buffer-substring (point-min)
                                                                (progn (goto-char (point-min))
                                                                       (search-forward "* dryer sheets")
                                                                       (line-end-position))))))
      ;; The private entry was never sent.
      (should-not (odx-property inbox "INBOX-5" "AI_HASH"))
      ;; The entry that already had TODO keeps it and AI_WHY says so.
      (should (string-match-p "keyword already set" (odx-property inbox "INBOX-3" "AI_WHY"))))))

(ert-deftest odx/decorating-twice-writes-nothing-the-second-time ()
  (odx-with-corpus
    (org-decorate-inbox inbox)
    (let ((log (length (org-queue-apply--log))))
      (org-decorate-inbox inbox)
      (should (= log (length (org-queue-apply--log)))))))

(ert-deftest odx/garbage-from-the-model-writes-an-error-line-and-nothing-else ()
  (odx-with-corpus
    (let ((org-decorate-model-function
           (lambda (_prompt _schema callback) (funcall callback '(:kind "nonsense" :keyword "DONE")))))
      (org-decorate-inbox inbox)
      (should (string-match-p "no usable proposal" (odx-property inbox "INBOX-1" "AI_WHY")))
      (should-not (odx-property inbox "INBOX-1" "AI_KEYWORD"))
      (should-not (odx-property inbox "INBOX-1" "AI_HASH")))))

(ert-deftest odx/json-from-the-model-becomes-a-proposal ()
  (let ((proposal (org-decorate--json-to-proposal
                   "Here you go:\n{\"kind\": \"task\", \"tags\": [\"a\"], \"impact\": 4, \"field_confidence\": {\"kind\": 0.9}}")))
    (should (equal "task" (plist-get proposal :kind)))
    (should (equal '("a") (plist-get proposal :tags)))
    (should (= 4 (plist-get proposal :impact)))
    (should (equal '((kind . 0.9)) (plist-get proposal :field_confidence))))
  (should-not (org-decorate--json-to-proposal "not json")))


;;;; Accept and reject

(ert-deftest odx/accepting-writes-the-real-fields-strips-and-refiles ()
  (odx-with-corpus
    (org-decorate-inbox inbox)
    (with-current-buffer (find-file-noselect inbox)
      (revert-buffer t t t)
      (org-with-wide-buffer
       (goto-char (point-min))
       (re-search-forward ":ID:\\s-+INBOX-1$")
       (org-decorate-accept)))
    ;; Gone from the inbox, in buy.org with its fields.
    (should-not (odx-property inbox "INBOX-1" "ID"))
    (should (equal "0:10" (odx-property todo "INBOX-1" "Effort")))
    (should (equal "<2026-08-21 Fri>" (odx-property todo "INBOX-1" "DEADLINE")))
    (should-not (odx-property todo "INBOX-1" "AI_KEYWORD"))
    (should-not (odx-property todo "INBOX-1" "AI_HASH"))
    (let ((task (cl-find "INBOX-1" (org-queue-harvest (list todo) 20260912)
                         :key (lambda (task) (plist-get task :id)) :test #'equal)))
      (should (equal "TODO" (plist-get task :state)))
      (should (member "@errand" (plist-get task :tags))))
    ;; And undone in one step.
    (org-queue-undo-apply)
    (should (odx-property inbox "INBOX-1" "AI_KEYWORD"))
    (should-not (odx-property todo "INBOX-1" "ID"))))

(ert-deftest odx/rejecting-leaves-the-entry-as-captured-plus-the-stamp ()
  (odx-with-corpus
    (let ((captured (with-temp-buffer (insert-file-contents odx-fixture) (buffer-string))))
      (org-decorate-inbox inbox)
      (with-current-buffer (find-file-noselect inbox)
        (revert-buffer t t t)
        (org-with-wide-buffer
         (goto-char (point-min))
         (re-search-forward ":ID:\\s-+INBOX-4$")
         (org-decorate-reject)))
      (should-not (odx-property inbox "INBOX-4" "AI_KEYWORD"))
      (should (odx-property inbox "INBOX-4" "AI_REJECTED"))
      ;; The heading and body are what was captured.
      (should (string-match-p "^\\* call the dentist by friday$" captured))
      (with-temp-buffer
        (insert-file-contents inbox)
        (should (string-match-p "^\\* call the dentist by friday$" (buffer-string))))
      ;; The correction file has the rejected fields.
      (should (file-exists-p org-decorate-corrections-file))
      ;; And it is not re-proposed under this prompt.
      (should-not (org-decorate-core-stale-p (odx-entry inbox "INBOX-4"))))))

(ert-deftest odx/accepting-one-field-promotes-it-and-records-the-rest-as-corrections ()
  (odx-with-corpus
    (org-decorate-inbox inbox)
    (with-current-buffer (find-file-noselect inbox)
      (revert-buffer t t t)
      (org-with-wide-buffer
       (goto-char (point-min))
       (re-search-forward ":ID:\\s-+INBOX-2$")
       (org-decorate-accept '("AI_EFFORT"))))
    (should (equal "0:10" (odx-property inbox "INBOX-2" "Effort")))
    (should-not (odx-property inbox "INBOX-2" "AI_HASH"))
    (should (odx-property inbox "INBOX-2" "ID"))   ; not refiled: the target was not accepted
    (with-temp-buffer
      (insert-file-contents org-decorate-corrections-file)
      (should (string-match-p ":field \"AI_KEYWORD\"" (buffer-string))))))


;;;; Duplicates

(ert-deftest odx/a-capture-that-matches-an-open-entry-is-a-duplicate-a-done-one-is-not ()
  (odx-with-corpus
    ;; INBOX-6 says "dryer sheets", which DONE-1 finished: not a duplicate.
    (should-not (org-decorate-check-duplicate "INBOX-6"))
    (should-not (odx-property inbox "INBOX-6" "DUPLICATE_OF"))
    ;; Add an open twin of "Buy socks" and check it.
    (with-current-buffer (find-file-noselect inbox)
      (org-with-wide-buffer
       (goto-char (point-max))
       (insert "\n* buy socks!\n:PROPERTIES:\n:ID: INBOX-7\n:CREATED: [2026-09-11 Fri 09:00]\n:END:\n")
       (save-buffer)))
    (should (org-decorate-check-duplicate "INBOX-7"))
    (should (equal "OPEN-1" (odx-property inbox "INBOX-7" "DUPLICATE_OF")))))


;;;; Commit evidence

(ert-deftest odx/a-commit-naming-an-id-becomes-evidence-once ()
  (odx-with-corpus
    (let ((repo (expand-file-name "repo" dir)))
      (make-directory repo)
      (let ((default-directory repo))
        (dolist (args '(("init" "-q") ("config" "user.email" "t@t") ("config" "user.name" "t")
                        ("commit" "-q" "--allow-empty" "-m" "socks: closes OPEN-1")
                        ("commit" "-q" "--allow-empty" "-m" "unrelated")))
          (apply #'call-process "git" nil nil nil args)))
      (let ((org-decorate-git-repos (list repo)))
        (should (= 2 (length (org-decorate-git-commits repo 7))))
        (should (org-decorate-git-evidence 7))
        (let ((sha (odx-property todo "OPEN-1" "EVIDENCE_DONE")))
          (should sha)
          (should (= 40 (length sha)))
          ;; Idempotent: a second run writes nothing.
          (let ((log (length (org-queue-apply--log))))
            (org-decorate-git-evidence 7)
            (should (= log (length (org-queue-apply--log))))
            (should (equal sha (odx-property todo "OPEN-1" "EVIDENCE_DONE")))))
        ;; The day log sees the commits.
        (let ((events (org-decorate-git-day-events nil 0 most-positive-fixnum)))
          (should (= 2 (length events)))
          (should (eq 'commit (plist-get (car events) :kind))))))))

(provide 'org-decorate-test)
;;; org-decorate-test.el ends here
