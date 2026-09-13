;;; org-queue-close-test.el --- ERT tests for the close-the-day core -*- lexical-binding: t -*-

;;; Commentary:

;; Hand-built plists, no Org.  Run with:
;;
;;   emacs -Q --batch -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-queue/test/org-queue-close-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'org-queue-close-core)

(defconst oqc-today 20260908)           ; a Tuesday
(defconst oqc-tomorrow 20260909)

(defun oqc-task (title &rest properties)
  (append properties
          (list :id title :title title :file "test.org" :category "test"
                :state "TODO" :effort 60 :created 20260901)))

(defun oqc-titles (tasks)
  (mapcar (lambda (task) (plist-get task :title)) tasks))

(defmacro oqc-flat (&rest forms)
  `(let ((org-queue-buckets nil)
         (org-queue-capacity '((0 . 60) (1 . 300) (2 . 300) (3 . 120) (4 . 300) (5 . 300) (6 . 60)))
         (org-queue-slack-fraction 0.0)
         (org-queue-calibrate nil))
     ,@forms))


(ert-deftest oqc/a-planned-task-not-done-is-carried-with-its-count ()
  (oqc-flat
    (let* ((history (list (list :date 20260908 :ids '("a" "b"))
                          (list :date 20260907 :ids '("a"))
                          (list :date 20260906 :ids '("a"))))
           (close (org-queue-close-core (list (oqc-task "a") (oqc-task "b"))
                                        oqc-today :plan-ids '("a" "b") :history history))
           (a (cl-find "a" (plist-get close :unfinished)
                       :key (lambda (task) (plist-get task :title)) :test #'equal)))
      (should (equal '("a" "b") (oqc-titles (plist-get close :unfinished))))
      (should (= 3 (plist-get a :carried-count)))
      (should (= 1 (plist-get (cl-find "b" (plist-get close :unfinished)
                                       :key (lambda (task) (plist-get task :title))
                                       :test #'equal)
                              :carried-count))))))

(ert-deftest oqc/a-task-done-today-appears-once ()
  "Even when its CLOSED stamp and its state line share the day."
  (oqc-flat
    (let* ((done (oqc-task "d" :state "DONE" :closed oqc-today
                           :last-transition (cons "DONE" oqc-today)))
           (old (oqc-task "old" :state "DONE" :closed 20260901
                          :last-transition (cons "DONE" 20260901)))
           (close (org-queue-close-core (list done old) oqc-today :plan-ids '("d"))))
      (should (equal '("d") (oqc-titles (plist-get close :done))))
      (should-not (plist-get (car (plist-get close :done)) :unplanned)))))

(ert-deftest oqc/a-task-finished-off-plan-is-marked-unplanned ()
  (oqc-flat
    (let* ((done (oqc-task "d" :state "NOPE" :last-transition (cons "NOPE" oqc-today)))
           (close (org-queue-close-core (list done) oqc-today :plan-ids nil)))
      (should (plist-get (car (plist-get close :done)) :unplanned)))))

(ert-deftest oqc/overdue-hard-deadlines-and-soft-ones-due-tomorrow ()
  (oqc-flat
    (let* ((hard (oqc-task "hard" :deadline 20260907))
           (soft (oqc-task "soft" :deadline 20260907 :deadline-soft t))
           (tomorrow (oqc-task "tomorrow" :deadline oqc-tomorrow))
           (later (oqc-task "later" :deadline 20260920))
           (close (org-queue-close-core (list hard soft tomorrow later) oqc-today)))
      (should (equal '("hard") (oqc-titles (plist-get close :overdue))))
      (should (equal '("soft" "tomorrow") (oqc-titles (plist-get close :due-tomorrow)))))))

(ert-deftest oqc/the-third-pick-is-refused ()
  (let ((org-queue-pick-limit 3)
        (two (list (oqc-task "a" :state "NEXT") (oqc-task "b" :state "NEXT") (oqc-task "c")))
        (three (list (oqc-task "a" :state "NEXT") (oqc-task "b" :state "NEXT")
                     (oqc-task "c" :state "NEXT") (oqc-task "d"))))
    (should (org-queue-close-core-pick-allowed-p two))
    (should-not (org-queue-close-core-pick-allowed-p three))
    ;; A finished NEXT no longer counts.
    (should (org-queue-close-core-pick-allowed-p
             (list (oqc-task "a" :state "NEXT") (oqc-task "b" :state "NEXT")
                   (oqc-task "c" :state "DONE"))))))

(ert-deftest oqc/closing-twice-reports-the-earlier-close ()
  (oqc-flat
    (let ((first (org-queue-close-core nil oqc-today))
          (second (org-queue-close-core nil oqc-today :closed "[2026-09-08 Tue 17:02]")))
      (should-not (plist-get first :already-closed))
      (should (equal "[2026-09-08 Tue 17:02]" (plist-get second :already-closed))))))

(ert-deftest oqc/prog-entries-are-listed-with-their-interruptions ()
  (oqc-flat
    (let* ((tasks (list (oqc-task "p" :state "PROG") (oqc-task "q" :state "PROG") (oqc-task "t")))
           (close (org-queue-close-core tasks oqc-today
                                        :interruptions '(("p" . 2)))))
      (should (equal '("p" "q") (oqc-titles (plist-get close :prog))))
      (should (= 2 (plist-get (nth 0 (plist-get close :prog)) :interruptions)))
      (should (= 0 (plist-get (nth 1 (plist-get close :prog)) :interruptions)))
      ;; The inputs are untouched: the corpus still says PROG.
      (should (equal "PROG" (plist-get (nth 0 tasks) :state))))))

(ert-deftest oqc/a-chain-with-no-next-prompt-is-listed-to-prime ()
  (oqc-flat
    (let* ((chains (list (list :task (oqc-task "c1" :state "AGENT") :prompt "do it")
                         (list :task (oqc-task "c2" :state "AGENT") :prompt nil)))
           (close (org-queue-close-core nil oqc-today :chains chains)))
      (should (equal "c1" (plist-get (plist-get (car (plist-get (plist-get close :chains) :primed)) :task) :title)))
      (should (equal "c2" (plist-get (plist-get (car (plist-get (plist-get close :chains) :unprimed)) :task) :title))))))

(ert-deftest oqc/the-draft-respects-tomorrows-capacity ()
  "Tuesday has 300 minutes, Wednesday 120: the draft for Wednesday packs 120."
  (oqc-flat
    (let* ((tasks (list (oqc-task "a") (oqc-task "b") (oqc-task "c") (oqc-task "d") (oqc-task "e")))
           (close (org-queue-close-core tasks oqc-today))
           (draft (plist-get close :draft)))
      (should (= oqc-tomorrow (plist-get draft :date)))
      (should (= 120 (plist-get draft :capacity)))
      (should (= 2 (length (plist-get draft :planned)))))))

(ert-deftest oqc/a-planned-id-that-left-the-corpus-is-reported-missing ()
  (oqc-flat
    (let ((close (org-queue-close-core (list (oqc-task "a")) oqc-today :plan-ids '("a" "gone"))))
      (should (equal '("gone") (plist-get close :missing)))
      (should (equal '("a") (oqc-titles (plist-get close :unfinished)))))))

(ert-deftest oqc/every-planned-task-ends-in-exactly-one-place ()
  (oqc-flat
    (let* ((tasks (list (oqc-task "a") (oqc-task "b" :state "DONE" :closed oqc-today)
                        (oqc-task "c" :state "PROG") (oqc-task "d" :state "DONE" :closed 20260901)))
           (close (org-queue-close-core tasks oqc-today :plan-ids '("a" "b" "c" "d" "x"))))
      (should (equal '("a" "c") (oqc-titles (plist-get close :unfinished))))
      (should (equal '("b") (oqc-titles (plist-get close :done))))
      (should (equal '("x") (plist-get close :missing)))
      (should (string-match-p "1 done, 2 carried" (org-queue-close-core-summary close))))))

(provide 'org-queue-close-test)
;;; org-queue-close-test.el ends here
