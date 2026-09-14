;;; org-queue-season-test.el --- ERT tests for horizons and the intake gate -*- lexical-binding: t -*-

;;; Commentary:

;; Hand-built plists, no Org.  Run with:
;;
;;   emacs -Q --batch -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-queue/test/org-queue-season-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'org-queue-season-core)
(require 'org-queue-intake-core)

(defconst oqs-today 20260912)

(defun oqs-task (title &rest properties)
  (append properties
          (list :id title :title title :file "test.org" :category "test"
                :state "TODO" :effort 60 :created 20260901)))

(defun oqs-mission (id &optional season) (list :id id :title id :season season))


;;;; Horizons

(ert-deftest oqs/the-season-name ()
  (should (equal "2026-Q3" (org-queue-season-core-name 20260912)))
  (should (equal "2026-Q1" (org-queue-season-core-name 20260101)))
  (should (equal "2026-Q4" (org-queue-season-core-name 20261231))))

(ert-deftest oqs/a-fourth-mission-is-refused-with-the-names ()
  (let ((org-queue-mission-limit 3))
    (should-not (org-queue-season-core-check
                 (list (oqs-mission "a") (oqs-mission "b") (oqs-mission "c")) "2026-Q3"))
    (let ((refusal (org-queue-season-core-check
                    (list (oqs-mission "a" "2026-Q3") (oqs-mission "b") (oqs-mission "c")
                          (oqs-mission "d" "2026-Q3") (oqs-mission "old" "2026-Q1"))
                    "2026-Q3")))
      (should refusal)
      (should (string-match-p "4 missions" refusal))
      (should (string-match-p "a, b, c, d" refusal))
      (should-not (string-match-p ", old" refusal)))))

(ert-deftest oqs/orphans-are-open-commitments-with-no-mission-reachable ()
  (let* ((served (oqs-task "served" :mission "M1"))
         (grandchild (oqs-task "grandchild" :mission "M1"))   ; the harvest inherits
         (orphan (oqs-task "orphan"))
         (parked (oqs-task "parked" :state "HOLD"))
         (habit (oqs-task "habit" :habit t))
         (done (oqs-task "done" :state "DONE"))
         (orphans (org-queue-season-core-orphans (list served grandchild orphan parked habit done))))
    (should (equal '("orphan") (mapcar (lambda (task) (plist-get task :title)) orphans)))))

(ert-deftest oqs/a-mission-with-no-rock-this-week-is-rockless ()
  (let* ((missions (list (oqs-mission "M1") (oqs-mission "M2") (oqs-mission "M3")))
         (tasks (list (oqs-task "a" :mission "M1" :state "NEXT")
                      (oqs-task "b" :mission "M2" :scheduled 20260930)
                      (oqs-task "c" :mission "M3" :state "DONE"))))
    (should (equal '("M2" "M3")
                   (mapcar (lambda (m) (plist-get m :id))
                           (org-queue-season-core-rockless missions tasks oqs-today))))))

(ert-deftest oqs/a-mission-whose-every-project-is-done-is-finished ()
  (let* ((missions (list (oqs-mission "M1") (oqs-mission "M2") (oqs-mission "M3")))
         (tasks (list (oqs-task "a" :mission "M1" :state "DONE")
                      (oqs-task "b" :mission "M1" :state "NOPE")
                      (oqs-task "c" :mission "M2" :state "DONE")
                      (oqs-task "d" :mission "M2"))))
    (should (equal '("M1") (mapcar (lambda (m) (plist-get m :id))
                                   (org-queue-season-core-finished missions tasks))))))

(ert-deftest oqs/a-theme-older-than-a-season-is-stale ()
  (let ((org-queue-season-days 90))
    (should (org-queue-season-core-stale-p 20260601 oqs-today))
    (should-not (org-queue-season-core-stale-p 20260801 oqs-today))
    (should-not (org-queue-season-core-stale-p nil oqs-today))))

(ert-deftest oqs/two-identical-tasks-differ-by-exactly-the-mission-weight ()
  (let* ((org-queue-weights (cons '(mission . 2.4) org-queue-weights))
         (plain (oqs-task "plain"))
         (aligned (oqs-task "aligned" :mission "M1")))
    (should (< (abs (- 2.4 (- (org-queue-core-score aligned oqs-today)
                              (org-queue-core-score plain oqs-today))))
               1e-9))))


;;;; The intake gate

(defmacro oqs-flat (minutes &rest forms)
  (declare (indent 1))
  `(let ((org-queue-buckets nil)
         (org-queue-capacity (mapcar (lambda (d) (cons d ,minutes)) '(0 1 2 3 4 5 6)))
         (org-queue-slack-fraction 0.0)
         (org-queue-calibrate nil))
     ,@forms))

(ert-deftest oqs/a-full-window-reports-the-overcommitment-and-no-fit ()
  "Two hours a day for three days, six hours already due: the candidate does not fit."
  (oqs-flat 120
    (let* ((tasks (list (oqs-task "a" :effort 120 :deadline 20260912)
                        (oqs-task "b" :effort 120 :deadline 20260913)
                        (oqs-task "c" :effort 120 :deadline 20260914)))
           (candidate (oqs-task "new" :effort 120))
           (report (org-queue-intake-core tasks candidate 20260914 oqs-today)))
      (should (= 3 (plist-get report :window)))
      (should (= 360 (plist-get report :capacity)))
      (should (= 360 (plist-get report :committed)))
      (should (= 3 (plist-get report :ahead)))
      (should-not (plist-get report :fits))
      (should (= 120 (plist-get report :shortfall)))
      ;; Whoever loses the last slot, something has to move.
      (should (string-match-p "does not fit" (org-queue-intake-core-line report 20260914))))))

(ert-deftest oqs/an-open-window-gives-an-eta ()
  (oqs-flat 120
    (let* ((tasks (list (oqs-task "a" :effort 60 :deadline 20260912)))
           (candidate (oqs-task "new" :effort 90))
           (report (org-queue-intake-core tasks candidate 20260914 oqs-today)))
      (should (plist-get report :fits))
      (should (plist-get report :eta))
      (should (<= oqs-today (plist-get report :eta) 20260914))
      (should (string-match-p "fits, first on" (org-queue-intake-core-line report 20260914))))))

(ert-deftest oqs/a-soft-deadline-has-nothing-to-say ()
  (oqs-flat 120
    (let ((report (org-queue-intake-core nil (oqs-task "new" :deadline-soft t) 20260914 oqs-today)))
      (should (plist-get report :soft))
      (should-not (plist-get report :fits))
      (should (string-match-p "soft" (org-queue-intake-core-line report 20260914))))))

(provide 'org-queue-season-test)
;;; org-queue-season-test.el ends here
