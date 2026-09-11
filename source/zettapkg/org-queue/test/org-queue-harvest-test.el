;;; org-queue-harvest-test.el --- ERT tests for the state-transition reader -*- lexical-binding: t -*-

;;; Commentary:

;; The Org half, so unlike org-queue-core-test.el these need Org loaded --
;; and `org-queue-harvest' requires org-ql, so the installed packages have to
;; be reachable too.  That is arranged below rather than by the caller, so the
;; command stays the same as the core suite's:
;;
;;   emacs -Q --batch -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-queue/test/org-queue-harvest-test.el \
;;     -f ert-run-tests-batch-and-exit
;;
;; Entries are built in a temp buffer rather than read from the fixture, so
;; regenerating testdata/ cannot break them.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'org)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
;; org-ql and its dependencies come from the elpaca build tree.  The root is
;; derived from this file's own path -- four directories up from
;; source/zettapkg/org-queue/test/ -- because under `emacs -Q'
;; `user-emacs-directory' is ~/.emacs.d and not this checkout.  Skipped
;; silently when the tree is absent, so the file still loads elsewhere.
(let* ((here (file-name-directory (or load-file-name buffer-file-name)))
       (root (expand-file-name "../../../../" here))
       (builds (expand-file-name "elpaca/builds" root)))
  (when (file-directory-p builds)
    (dolist (dir (directory-files builds t "\\`[^.]"))
      (when (file-directory-p dir) (add-to-list 'load-path dir)))))
(require 'org-queue-harvest)

(defmacro oqh-with-entry (body-text &rest forms)
  "Run FORMS at the start of an Org entry whose text is BODY-TEXT."
  (declare (indent 1))
  `(with-temp-buffer
     (let ((org-todo-keywords
            '((sequence "TODO(t!)" "NEXT(N!)" "PROG(p!)" "|" "DONE(d!)"))))
       (org-mode)
       (insert ,body-text)
       (goto-char (point-min))
       ,@forms)))

(defconst oqh-now (org-time-string-to-time "[2026-01-08 Thu 18:00]"))


;;;; Reading the log

(ert-deftest oqh/state-log-reads-states-not-buffer-garbage ()
  "Regression: `org-time-string-to-time' resets the match data, so the
state must be read out of the match BEFORE the stamp is parsed."
  (oqh-with-entry
      "* DONE a thing\n:LOGBOOK:\n- State \"DONE\"       from \"PROG\"       [2026-01-08 Thu 15:25]\n- State \"PROG\"       from \"TODO\"       [2026-01-08 Thu 15:15]\n:END:\n"
    (should (equal '("PROG" "DONE") (mapcar #'car (org-queue-state-log))))))

(ert-deftest oqh/state-log-is-sorted-oldest-first ()
  "Org writes newest-first; the reader must not depend on that."
  (oqh-with-entry
      "* DONE a\n:LOGBOOK:\n- State \"PROG\"       from \"TODO\"       [2026-01-08 Thu 15:15]\n- State \"DONE\"       from \"PROG\"       [2026-01-08 Thu 15:25]\n:END:\n"
    (should (equal '("PROG" "DONE") (mapcar #'car (org-queue-state-log))))))

(ert-deftest oqh/a-blank-from-field-still-parses ()
  "Most of the real kb leaves `from' empty."
  (oqh-with-entry
      "* DONE a\n:LOGBOOK:\n- State \"DONE\"       from              [2026-01-08 Thu 15:25]\n- State \"STARTED\"    from              [2026-01-08 Thu 15:15]\n:END:\n"
    (should (equal '("STARTED" "DONE") (mapcar #'car (org-queue-state-log))))))

(ert-deftest oqh/a-child-s-log-is-not-read ()
  "Calibration breaks if a parent inherits its children's hours."
  (oqh-with-entry
      "* TODO parent\n:LOGBOOK:\n- State \"PROG\"       from \"TODO\"       [2026-01-08 Thu 15:00]\n:END:\n** DONE child\n:LOGBOOK:\n- State \"DONE\"       from \"PROG\"       [2026-01-08 Thu 17:00]\n:END:\n"
    (should (= 1 (length (org-queue-state-log))))))


;;;; Intervals

(ert-deftest oqh/n-transitions-give-n-intervals-the-last-open ()
  (oqh-with-entry
      "* PROG a\n:LOGBOOK:\n- State \"PROG\"       from \"TODO\"       [2026-01-08 Thu 15:15]\n- State \"TODO\"       from \"PROG\"       [2026-01-08 Thu 15:00]\n- State \"PROG\"       from \"TODO\"       [2026-01-08 Thu 14:00]\n:END:\n"
    (let ((intervals (org-queue-state-intervals nil oqh-now)))
      (should (= 3 (length intervals)))
      (should (equal '("PROG" "TODO" "PROG")
                     (mapcar (lambda (i) (plist-get i :state)) intervals)))
      (should-not (plist-get (nth 0 intervals) :open))
      (should (plist-get (nth 2 intervals) :open)))))

(ert-deftest oqh/an-interval-is-measured-from-the-transition-that-opens-it ()
  (oqh-with-entry
      "* DONE a\n:LOGBOOK:\n- State \"DONE\"       from \"PROG\"       [2026-01-08 Thu 15:25]\n- State \"PROG\"       from \"TODO\"       [2026-01-08 Thu 15:15]\n:END:\n"
    (let ((first (car (org-queue-state-intervals nil oqh-now))))
      (should (equal "PROG" (plist-get first :state)))
      (should (= 10 (plist-get first :minutes))))))

(ert-deftest oqh/intervals-stay-raw-for-a-gantt-chart ()
  "The cap belongs to the measurement, not to the interval itself."
  (oqh-with-entry
      "* DONE a\n:LOGBOOK:\n- State \"DONE\"       from \"PROG\"       [2026-01-05 Mon 09:00]\n- State \"PROG\"       from \"TODO\"       [2026-01-01 Thu 09:00]\n:END:\n"
    (let ((org-queue-max-interval-minutes 480))
      (should (= (* 4 24 60) (plist-get (car (org-queue-state-intervals nil oqh-now))
                                        :minutes)))
      (should (= 480 (org-queue-state-minutes '("PROG") nil oqh-now))))))


;;;; Measuring

(ert-deftest oqh/only-working-states-are-counted ()
  (oqh-with-entry
      "* DONE a\n:LOGBOOK:\n- State \"DONE\"       from \"PROG\"       [2026-01-08 Thu 16:00]\n- State \"PROG\"       from \"TODO\"       [2026-01-08 Thu 15:00]\n- State \"TODO\"       from \"NEXT\"       [2026-01-08 Thu 12:00]\n:END:\n"
    ;; TODO ran 12:00-15:00 and must not count; PROG ran 15:00-16:00.
    (should (= 60 (org-queue-state-minutes '("PROG") nil oqh-now)))))

(ert-deftest oqh/legacy-started-measures-like-prog ()
  "The kb's older schema used STARTED; those entries must not read as zero."
  (oqh-with-entry
      "* DONE a\n:LOGBOOK:\n- State \"DONE\"       from \"STARTED\"    [2026-01-08 Thu 15:25]\n- State \"STARTED\"    from              [2026-01-08 Thu 15:15]\n:END:\n"
    (should (= 10 (org-queue-state-minutes '("PROG" "STARTED") nil oqh-now)))))

(ert-deftest oqh/multiple-sessions-sum ()
  (oqh-with-entry
      "* DONE a\n:LOGBOOK:\n- State \"DONE\"       from \"PROG\"       [2026-01-08 Thu 16:30]\n- State \"PROG\"       from \"TODO\"       [2026-01-08 Thu 16:00]\n- State \"TODO\"       from \"PROG\"       [2026-01-08 Thu 15:20]\n- State \"PROG\"       from \"TODO\"       [2026-01-08 Thu 15:00]\n:END:\n"
    (should (= 50 (org-queue-state-minutes '("PROG") nil oqh-now)))))

(ert-deftest oqh/an-entry-with-no-log-measures-zero ()
  (oqh-with-entry "* TODO a\n"
    (should (= 0 (org-queue-state-minutes '("PROG") nil oqh-now)))))


;;;; The CLOCK fallback

(ert-deftest oqh/transitions-win-over-clock-lines ()
  "Never the sum: that would count the same work twice."
  (oqh-with-entry
      "* DONE a\n:LOGBOOK:\nCLOCK: [2026-01-08 Thu 09:00]--[2026-01-08 Thu 12:00] =>  3:00\n- State \"DONE\"       from \"PROG\"       [2026-01-08 Thu 15:25]\n- State \"PROG\"       from \"TODO\"       [2026-01-08 Thu 15:15]\n:END:\n"
    (should (= 180 (org-queue-harvest--clock-lines)))
    (should (= 10 (org-queue-harvest--clocked)))))

(ert-deftest oqh/clock-lines-are-used-when-there-is-nothing-to-measure ()
  "Pre-switch entries still have to report their time."
  (oqh-with-entry
      "* DONE a\n:LOGBOOK:\nCLOCK: [2026-01-08 Thu 09:00]--[2026-01-08 Thu 09:45] =>  0:45\n- State \"DONE\"       from              [2026-01-08 Thu 15:25]\n:END:\n"
    (should (= 0 (org-queue-state-minutes '("PROG") nil oqh-now)))
    (should (= 45 (org-queue-harvest--clocked)))))

(provide 'org-queue-harvest-test)
;;; org-queue-harvest-test.el ends here
