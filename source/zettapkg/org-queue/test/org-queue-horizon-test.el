;;; org-queue-horizon-test.el --- ERT tests for the horizon simulator -*- lexical-binding: t -*-

;;; Commentary:

;; Hand-built plists, no Org.  Run with:
;;
;;   emacs -Q --batch -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-queue/test/org-queue-horizon-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'org-queue-horizon)

(defconst oqz-tue 20260908)
(defconst oqz-wed 20260909)
(defconst oqz-thu 20260910)
(defconst oqz-fri 20260911)

(defun oqz-task (title &rest properties)
  (append properties
          (list :id title :title title :file "test.org" :category "test"
                :state "TODO" :effort 60 :created 20260901)))

(defmacro oqz-with-flat-days (minutes &rest forms)
  "Run FORMS with every weekday worth MINUTES, no slack, no calibration."
  (declare (indent 1))
  `(let ((org-queue-buckets nil)
         (org-queue-capacity (mapcar (lambda (d) (cons d ,minutes)) '(0 1 2 3 4 5 6)))
         (org-queue-slack-fraction 0.0)
         (org-queue-calibrate nil)
         (org-queue-history-file nil))
     ,@forms))

(defun oqz-placement (horizon title)
  (cdr (assoc title (plist-get horizon :placements))))

(defun oqz-day-titles (horizon n)
  (mapcar (lambda (task) (plist-get task :title))
          (plist-get (nth n (plist-get horizon :days)) :planned)))


(ert-deftest oqz/six-hours-due-friday-slices-across-three-days ()
  "Two free hours a day; 360 minutes due Friday lands 120 on Wed, Thu, Fri.
The deadline day counts: an Org deadline is inclusive, and the day view
already calls work on that day \"due today\".  Start-by is Wednesday, so
Tuesday is free for other things."
  (oqz-with-flat-days 120
    (let* ((big (oqz-task "big" :effort 360 :deadline oqz-fri))
           (horizon (org-queue-core-horizon (list big) oqz-tue oqz-fri))
           (placement (oqz-placement horizon "big")))
      (should (equal (list (cons oqz-wed 120) (cons oqz-thu 120) (cons oqz-fri 120))
                     (plist-get placement :days)))
      (should (plist-get placement :complete))
      (should-not (plist-get horizon :missed))
      (should-not (oqz-day-titles horizon 0))
      (should (eq 'committed
                  (plist-get (car (plist-get (nth 1 (plist-get horizon :days)) :planned))
                             :queue-reason))))))

(ert-deftest oqz/a-task-planned-today-is-gone-tomorrow ()
  (oqz-with-flat-days 120
    (let* ((a (oqz-task "a" :effort 60))
           (b (oqz-task "b" :effort 60))
           (c (oqz-task "c" :effort 60))
           (horizon (org-queue-core-horizon (list a b c) oqz-tue oqz-wed)))
      (should (= 2 (length (oqz-day-titles horizon 0))))
      (should (= 1 (length (oqz-day-titles horizon 1))))
      (should-not (cl-intersection (oqz-day-titles horizon 0)
                                   (oqz-day-titles horizon 1)
                                   :test #'equal)))))

(ert-deftest oqz/deferred-work-arrives-on-its-day ()
  (oqz-with-flat-days 120
    (let* ((later (oqz-task "later" :effort 60 :scheduled oqz-thu))
           (filler-1 (oqz-task "f1" :effort 120 :scheduled oqz-tue))
           (filler-2 (oqz-task "f2" :effort 120 :scheduled oqz-wed))
           (horizon (org-queue-core-horizon (list later filler-1 filler-2)
                                            oqz-tue oqz-thu)))
      (should (equal '("f1") (oqz-day-titles horizon 0)))
      (should (equal '("f2") (oqz-day-titles horizon 1)))
      (should (equal '("later") (oqz-day-titles horizon 2))))))

(ert-deftest oqz/a-missed-deadline-is-reported ()
  "A hard deadline inside the range that the days cannot cover."
  (oqz-with-flat-days 60
    (let* ((big (oqz-task "big" :effort 300 :deadline oqz-wed))
           (horizon (org-queue-core-horizon (list big) oqz-tue oqz-fri)))
      (should (= 1 (length (plist-get horizon :missed))))
      (should (equal "big" (plist-get (car (car (plist-get horizon :missed))) :title)))
      (should (> (cdr (car (plist-get horizon :missed))) 0)))))

(ert-deftest oqz/a-soft-deadline-gets-no-backpressure ()
  "No start-by, so nothing before its day; on its day it is due like any
deadline, and being late is not a miss."
  (oqz-with-flat-days 60
    (let* ((soft (oqz-task "soft" :effort 300 :deadline oqz-wed :deadline-soft t))
           (horizon (org-queue-core-horizon (list soft) oqz-tue oqz-fri)))
      (should-not (plist-get horizon :missed))
      (should-not (oqz-day-titles horizon 0))
      (should (equal '("soft") (oqz-day-titles horizon 1))))))

(ert-deftest oqz/backlog-run-stops-at-the-ceiling ()
  (oqz-with-flat-days 60
    (let* ((org-queue-horizon-max-days 3)
           (tasks (cl-loop for i from 1 to 10
                           collect (oqz-task (format "t%d" i) :effort 60)))
           (horizon (org-queue-core-horizon tasks oqz-tue 20261231)))
      (should (= 3 (length (plist-get horizon :days))))
      (should (= oqz-thu (plist-get horizon :to)))
      (should (= 7 (length (plist-get horizon :unplaced)))))))

(ert-deftest oqz/habits-are-reserved-on-every-day-they-fall ()
  (oqz-with-flat-days 120
    (let* ((lift (oqz-task "lift" :habit t :effort 60 :habit-days '(2 4)))  ; Tue Thu
           (a (oqz-task "a" :effort 120))
           (b (oqz-task "b" :effort 120))
           (horizon (org-queue-core-horizon (list lift a b) oqz-tue oqz-wed)))
      ;; Tuesday has 60 left after the lift, so nothing fits; Wednesday is open.
      (should-not (oqz-day-titles horizon 0))
      (should (= 1 (length (oqz-day-titles horizon 1))))
      (should (equal '("lift") (mapcar (lambda (h) (plist-get h :title))
                                       (plist-get (car (plist-get horizon :days)) :routine)))))))

(ert-deftest oqz/start-by-sees-what-is-already-committed ()
  "240 due Thursday with Thursday booked solid: Thursday has no free
minutes, so start-by walks back to Tuesday and the work is sliced over
Tuesday and Wednesday.  Thursday keeps its booking."
  (oqz-with-flat-days 120
    (let* ((booked (oqz-task "booked" :effort 120 :scheduled oqz-thu))
           (due (oqz-task "due" :effort 240 :deadline oqz-thu))
           (horizon (org-queue-core-horizon (list booked due) oqz-tue oqz-thu)))
      (should (equal (list (cons oqz-tue 120) (cons oqz-wed 120))
                     (plist-get (oqz-placement horizon "due") :days)))
      (should (equal '("booked") (oqz-day-titles horizon 2)))
      (should-not (plist-get horizon :missed)))))

(ert-deftest oqz/a-placed-schedule-may-move-only-while-proposing ()
  "Tuesday booked by hand, a deadline eating Wednesday, and a machine
placement on Wednesday: as a fact it stays put; as a proposal it moves
to Thursday."
  (oqz-with-flat-days 120
    (let* ((human (oqz-task "human" :effort 120 :scheduled oqz-tue))
           (urgent (oqz-task "urgent" :effort 120 :deadline oqz-wed))
           (placed (oqz-task "placed" :effort 120 :scheduled oqz-wed :placed t)))
      (should (org-queue-core-committed-p placed oqz-wed))
      (let* ((org-queue-core-placed-soft t)
             (horizon (org-queue-core-horizon (list human urgent placed) oqz-tue oqz-thu)))
        (should (equal '("human") (oqz-day-titles horizon 0)))
        (should (equal '("urgent") (oqz-day-titles horizon 1)))
        (should (equal '("placed") (oqz-day-titles horizon 2)))))))



;;;; Proposals

(defun oqz-proposal (tasks from to &optional rejected)
  (let ((org-queue-core-placed-soft t))
    (org-queue-core-proposal (org-queue-core-horizon tasks from to) tasks rejected)))

(defun oqz-actions (proposal kind)
  (cl-remove-if-not (lambda (item) (eq (plist-get item :action) kind)) proposal))

(ert-deftest oqz/proposal-schedules-the-undated-and-leaves-human-dates ()
  (oqz-with-flat-days 120
    (let* ((undated (oqz-task "undated" :effort 60))
           (human (oqz-task "human" :effort 60 :scheduled oqz-tue))
           (proposal (oqz-proposal (list undated human) oqz-tue oqz-wed)))
      (should (= 1 (length (oqz-actions proposal 'schedule))))
      (should (equal "undated" (plist-get (plist-get (car (oqz-actions proposal 'schedule)) :task) :title)))
      (should-not (cl-find "human" proposal
                           :key (lambda (item) (plist-get (plist-get item :task) :title))
                           :test #'equal)))))

(ert-deftest oqz/proposal-is-empty-once-accepted ()
  "Accepting is what a placed schedule on the proposed day looks like."
  (oqz-with-flat-days 120
    (let* ((first (oqz-proposal (list (oqz-task "a" :effort 60)) oqz-tue oqz-wed))
           (day (plist-get (car first) :to))
           (accepted (oqz-task "a" :effort 60 :scheduled day :placed t)))
      (should (= 1 (length first)))
      (should-not (oqz-proposal (list accepted) oqz-tue oqz-wed)))))

(ert-deftest oqz/proposal-moves-a-machine-placement-that-no-longer-fits ()
  (oqz-with-flat-days 120
    (let* ((human (oqz-task "human" :effort 120 :scheduled oqz-tue))
           (urgent (oqz-task "urgent" :effort 120 :deadline oqz-wed))
           (placed (oqz-task "placed" :effort 120 :scheduled oqz-wed :placed t))
           (proposal (oqz-proposal (list human urgent placed) oqz-tue oqz-thu))
           (move (car (oqz-actions proposal 'move))))
      (should move)
      (should (= oqz-wed (plist-get move :from)))
      (should (= oqz-thu (plist-get move :to)))
      ;; The hand-written Tuesday is never in the proposal.
      (should-not (cl-find "human" proposal
                           :key (lambda (item) (plist-get (plist-get item :task) :title))
                           :test #'equal)))))

(ert-deftest oqz/proposal-honours-rejections ()
  (oqz-with-flat-days 120
    (let* ((task (oqz-task "a" :effort 60))
           (first (oqz-proposal (list task) oqz-tue oqz-wed))
           (rejected (list (cons "a" (plist-get (car first) :to)))))
      (should-not (oqz-actions (oqz-proposal (list task) oqz-tue oqz-wed rejected)
                               'schedule)))))

(ert-deftest oqz/proposal-reports-a-missed-deadline-as-a-finding ()
  (oqz-with-flat-days 60
    (let* ((big (oqz-task "big" :effort 300 :deadline oqz-wed))
           (proposal (oqz-proposal (list big) oqz-tue oqz-fri))
           (finding (cl-find 'missed proposal :key (lambda (i) (plist-get i :finding)))))
      (should finding)
      (should (string-match-p "does not fit before 2026-09-09" (plist-get finding :text))))))

(ert-deftest oqz/proposal-unschedules-an-unused-placement ()
  "A machine placement on a day the simulation gives to a deadline, with
no other day in range to move it to."
  (oqz-with-flat-days 60
    (let* ((placed (oqz-task "placed" :effort 60 :scheduled oqz-tue :placed t
                             :state "WAIT"))
           (proposal (oqz-proposal (list placed) oqz-tue oqz-tue)))
      ;; WAIT with no deadline is dropped, so it is never placed: unschedule.
      (should (= 1 (length (oqz-actions proposal 'unschedule)))))))

(ert-deftest oqz/proposal-skips-what-a-date-already-fixes ()
  "An appointment on its day and a task on its deadline day need no
SCHEDULED; a start-by commitment does."
  (oqz-with-flat-days 120
    (let* ((meeting (oqz-task "meeting" :effort 30 :timestamp oqz-tue))
           (due (oqz-task "due" :effort 30 :deadline oqz-tue))
           (early (oqz-task "early" :effort 200 :deadline oqz-wed))   ; start-by Tue
           (proposal (oqz-proposal (list meeting due early) oqz-tue oqz-wed))
           (titles (mapcar (lambda (i) (plist-get (plist-get i :task) :title))
                           (oqz-actions proposal 'schedule))))
      (should (equal '("early") titles)))))

(provide 'org-queue-horizon-test)
;;; org-queue-horizon-test.el ends here
