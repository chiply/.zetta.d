;;; org-queue-review-test.el --- ERT tests for the review pack core -*- lexical-binding: t -*-

;;; Commentary:

;; Hand-built plists, no Org.  Run with:
;;
;;   emacs -Q --batch -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-queue/test/org-queue-review-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'org-queue-review-core)

(defconst oqv-today 20260914)           ; a Monday

(defun oqv-task (title &rest properties)
  (append properties
          (list :id title :title title :file "test.org" :category "test"
                :state "TODO" :effort 60 :created 20260801 :priority ?B
                :deadline 20261001)))

(defun oqv-titles (tasks) (mapcar (lambda (task) (plist-get task :title)) tasks))


;;;; Chase, stalled, moved, finished

(ert-deftest oqv/a-wait-untouched-for-eight-days-is-chased-and-one-touched-yesterday-is-not ()
  (let* ((old (oqv-task "old" :state "WAIT" :touched 20260906 :waiting-on "Sam"))
         (fresh (oqv-task "fresh" :state "WAIT" :touched 20260913))
         (pack (org-queue-review-core (list old fresh) oqv-today)))
    (should (equal '("old") (oqv-titles (plist-get pack :chase))))))

(ert-deftest oqv/every-open-item-lands-in-exactly-one-stalled-bucket ()
  (let* ((tasks (list (oqv-task "a" :touched 20260913)
                      (oqv-task "b" :touched 20260820)
                      (oqv-task "c" :touched 20260701)
                      (oqv-task "d" :touched 20260101)
                      (oqv-task "e")
                      (oqv-task "parked" :state "HOLD" :touched 20260913)
                      (oqv-task "done" :state "DONE" :touched 20260913)))
         (pack (org-queue-review-core tasks oqv-today))
         (stalled (plist-get pack :stalled)))
    (should (equal '(week month quarter longer never) (mapcar #'car stalled)))
    (should (equal '("a") (oqv-titles (alist-get 'week stalled))))
    (should (equal '("b") (oqv-titles (alist-get 'month stalled))))
    (should (equal '("c") (oqv-titles (alist-get 'quarter stalled))))
    (should (equal '("d") (oqv-titles (alist-get 'longer stalled))))
    (should (equal '("e") (oqv-titles (alist-get 'never stalled))))
    ;; Five open, unparked items; five placements.
    (should (= 5 (cl-reduce #'+ (mapcar (lambda (b) (length (cdr b))) stalled))))))

(ert-deftest oqv/moved-and-finished-follow-the-window ()
  (let* ((moved (oqv-task "moved" :transitions '(("PROG" . 20260910))))
         (older (oqv-task "older" :transitions '(("PROG" . 20260801))))
         (done (oqv-task "done" :state "DONE" :closed 20260911))
         (done-long-ago (oqv-task "old-done" :state "DONE" :closed 20260601))
         (pack (org-queue-review-core (list moved older done done-long-ago) oqv-today)))
    (should (equal '("moved") (oqv-titles (plist-get pack :moved))))
    (should (equal '("done") (oqv-titles (plist-get pack :finished))))))


;;;; Dormant, calibration, template, ROTTEN

(ert-deftest oqv/dormant-projects-come-from-the-check ()
  (let* ((dormant (list (list :task (oqv-task "p1") :status 'dormant)
                        (list :task (oqv-task "p2") :status 'live)
                        (list :task (oqv-task "p3") :status 'finished)))
         (pack (org-queue-review-core nil oqv-today :dormant dormant)))
    (should (= 1 (length (plist-get pack :dormant))))
    (should (= 1 (length (plist-get pack :finished-projects))))))

(ert-deftest oqv/the-calibration-block-needs-enough-finished-tasks ()
  (let* ((org-queue-calibration-prior 3)
         (rows '((:category "test" :n 2 :raw 1.1 :factor 1.05)))
         (few (list (oqv-task "d1" :state "DONE" :closed 20260911)))
         (enough (list (oqv-task "d1" :state "DONE" :closed 20260911)
                       (oqv-task "d2" :state "DONE" :closed 20260911)
                       (oqv-task "d3" :state "DONE" :closed 20260911))))
    (should-not (plist-get (org-queue-review-core few oqv-today :calibration rows) :calibration))
    (should (plist-get (org-queue-review-core enough oqv-today :calibration rows) :calibration))))

(ert-deftest oqv/the-rotten-count-is-the-sum-of-reschedule-lines ()
  (let* ((pack (org-queue-review-core (list (oqv-task "a" :rotten 3) (oqv-task "b" :rotten 1)
                                            (oqv-task "c"))
                                      oqv-today)))
    (should (= 4 (plist-get (plist-get pack :rotten) :count)))
    (should (equal '("a" "b") (oqv-titles (plist-get (plist-get pack :rotten) :tasks))))))

(ert-deftest oqv/the-template-rows-say-under-on-and-over ()
  (let ((rows (org-queue-review-core-template-rows
               '((work . 2000) (reading . 300) (body . 600))
               '((work . 800) (reading . 300) (body . 1000)))))
    (should (equal '(under on over) (mapcar (lambda (r) (plist-get r :verdict)) rows)))))

(ert-deftest oqv/floors-and-ceilings-in-hours ()
  (let ((rows (org-queue-review-core-floor-rows
               '(("emacs" 5 . 15) ("home" 2 . nil) ("learn" 3 . 6))
               '(("emacs" . 120) ("home" . 200) ("learn" . 400)))))
    (should (equal '(below within above) (mapcar (lambda (r) (plist-get r :verdict)) rows)))))

(ert-deftest oqv/the-sections-appear-in-a-fixed-order-empty-or-not ()
  (let ((keys (cl-loop for (key _value) on (org-queue-review-core nil oqv-today) by #'cddr
                       collect key)))
    (should (equal '(:date :window :questions :moved :finished :stalled :chase :parked-due
                     :untriaged :inbox :dormant :finished-projects :worth :calibration
                     :time :template :floors :rotten :chains)
                   keys))))


;;;; Still worth it?

(ert-deftest oqv/surfaced-three-times-is-proposed-two-is-not ()
  (let* ((org-queue-dismiss-after 3)
         (three (oqv-task "three" :state "HOLD" :surfaced 3))
         (two (oqv-task "two" :state "HOLD" :surfaced 2))
         (proposals (org-queue-review-core-proposals (list three two) nil oqv-today)))
    (should (equal '("three") (oqv-titles proposals)))
    (should (equal org-queue-review-forster-questions (plist-get (car proposals) :questions)))
    (should (= 3 (plist-get (plist-get (car proposals) :evidence) :surfaced)))))

(ert-deftest oqv/a-dismissed-item-is-never-proposed-again ()
  (let ((gone (oqv-task "gone" :state "NOPE" :surfaced 5 :dismissed 20260901))
        (still (oqv-task "still" :state "HOLD" :surfaced 5 :dismissed 20260901)))
    (should-not (org-queue-review-core-proposals (list gone still) nil oqv-today))))

(ert-deftest oqv/the-evidence-tuple ()
  (let* ((history (list (list :date 20260913 :ids '("t")) (list :date 20260912 :ids '("t"))))
         (evidence (org-queue-review-core-evidence
                    (oqv-task "t" :created 20260814 :touched 20260907 :surfaced 2 :rotten 1)
                    history oqv-today)))
    (should (= 31 (plist-get evidence :age)))
    (should (= 2 (plist-get evidence :carried)))
    (should (= 2 (plist-get evidence :surfaced)))
    (should (= 7 (plist-get evidence :touched)))
    (should (= 1 (plist-get evidence :rotten)))))

(ert-deftest oqv/a-review-on-that-arrives-raises-a-parked-item-once ()
  (let* ((due (oqv-task "due" :state "HOLD" :review-on 20260913))
         (kept (oqv-task "kept" :state "HOLD" :review-on 20260913 :kept 20260913))
         (later (oqv-task "later" :state "IDEA" :review-on 20261001))
         (pack (org-queue-review-core (list due kept later) oqv-today)))
    (should (equal '("due") (oqv-titles (plist-get pack :parked-due))))))

(ert-deftest oqv/a-recaptured-copy-of-a-finished-task-came-back ()
  (let* ((old (oqv-task "Buy dryer sheets" :state "DONE" :created 20260701))
         (new (oqv-task "buy dryer sheets " :created 20260910))
         (unrelated (oqv-task "Buy socks" :created 20260910)))
    (should (eq old (org-queue-review-core-came-back-p new (list old new unrelated))))
    (should-not (org-queue-review-core-came-back-p unrelated (list old new unrelated)))))

(provide 'org-queue-review-test)
;;; org-queue-review-test.el ends here
