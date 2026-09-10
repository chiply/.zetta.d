;;; org-queue-core-test.el --- ERT tests for org-queue-core -*- lexical-binding: t -*-

;;; Commentary:

;; Hand-built plists, no Org, no files.  Run with:
;;
;;   emacs -Q --batch -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-queue/test/org-queue-core-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'org-queue-core)

(defconst oqt-today 20260908)           ; a Tuesday

(defun oqt-task (title &rest properties)
  "Build a task plist named TITLE with PROPERTIES overriding the defaults."
  (append properties
          (list :id title :title title :file "test.org" :category "test"
                :state "TODO" :effort 60 :created 20260901)))

(defun oqt-titles (tasks)
  (mapcar (lambda (task) (plist-get task :title)) tasks))

(defun oqt-plan-titles (plan)
  (oqt-titles (plist-get plan :planned)))

(defun oqt-drop-reason (plan title)
  (cl-loop for (task . reason) in (append (plist-get plan :dropped)
                                          (plist-get plan :cut))
           when (equal (plist-get task :title) title) return reason))


;;;; Dates

(ert-deftest oqt/day-of-week ()
  (should (= 2 (org-queue-core-day-of-week 20260908)))   ; Tuesday
  (should (= 0 (org-queue-core-day-of-week 20260906)))   ; Sunday
  (should (= 4 (org-queue-core-day-of-week 19700101))))  ; Thursday

(ert-deftest oqt/days-between-crosses-boundaries ()
  (should (= 1 (org-queue-core-days-between 20260930 20261001)))
  (should (= 1 (org-queue-core-days-between 20261231 20270101)))
  (should (= 1 (org-queue-core-days-between 20240228 20240229)))  ; leap
  (should (= 1 (org-queue-core-days-between 20230228 20230301)))  ; non-leap
  (should (= -7 (org-queue-core-days-between 20260908 20260901))))

(ert-deftest oqt/capacity-varies-by-weekday ()
  (let ((org-queue-capacity '((0 . 0) (1 . 100) (2 . 200) (3 . 0)
                              (4 . 0) (5 . 0) (6 . 0))))
    (should (= 200 (org-queue-core-capacity 20260908)))    ; Tuesday
    (should (= 100 (org-queue-core-capacity 20260907)))))  ; Monday


;;;; Scoring

(ert-deftest oqt/overdue-beats-priority ()
  "An overdue C outranks an undated A."
  (let ((overdue (oqt-task "overdue" :priority ?C :deadline 20260901))
        (important (oqt-task "important" :priority ?A)))
    (should (> (org-queue-core-score overdue oqt-today)
               (org-queue-core-score important oqt-today)))))

(ert-deftest oqt/urgency-is-convex ()
  "Urgency is flat far out and steep in the last days, and pins when overdue."
  (let* ((u (lambda (deadline)
              (org-queue-core-urgency (oqt-task "t" :deadline deadline)
                                      oqt-today)))
         (d30 (funcall u 20261008))
         (d7 (funcall u 20260915))
         (d1 (funcall u 20260909)))
    (should (= 1.0 (funcall u 20260901)))          ; overdue: pinned
    (should (= 1.0 (funcall u oqt-today)))         ; due today: pinned
    (should (< d30 d7 d1))
    ;; The last day gains more than the three weeks before it.
    (should (> (- d1 d7) (- d7 d30)))))

(ert-deftest oqt/absent-priority-outranks-c ()
  "Untriaged is a real value between B and C, not the bottom of the pile."
  (let ((none (oqt-task "none"))
        (c (oqt-task "c" :priority ?C))
        (b (oqt-task "b" :priority ?B)))
    (should (> (org-queue-core-score none oqt-today)
               (org-queue-core-score c oqt-today)))
    (should (< (org-queue-core-score none oqt-today)
               (org-queue-core-score b oqt-today)))))

(ert-deftest oqt/prog-outranks-fresh-todo ()
  (should (> (org-queue-core-score (oqt-task "wip" :state "PROG") oqt-today)
             (org-queue-core-score (oqt-task "new") oqt-today))))

(ert-deftest oqt/ques-is-docked ()
  (should (< (org-queue-core-score (oqt-task "q" :state "QUES") oqt-today)
             (org-queue-core-score (oqt-task "t") oqt-today))))

(ert-deftest oqt/carry-over-outranks-an-equal-fresh-task ()
  (let ((carried (oqt-task "carried" :carried t))
        (fresh (oqt-task "fresh")))
    (should (> (org-queue-core-score carried oqt-today)
               (org-queue-core-score fresh oqt-today)))
    ;; And it wins the last slot in a plan that only has room for one.
    (let ((plan (org-queue-core-plan (list fresh carried) oqt-today 75)))
      (should (equal '("carried") (oqt-plan-titles plan))))))

(ert-deftest oqt/older-outranks-newer ()
  (should (> (org-queue-core-score (oqt-task "old" :created 20260101) oqt-today)
             (org-queue-core-score (oqt-task "new" :created 20260907) oqt-today))))


;;;; Filtering

(ert-deftest oqt/filter-drops-finished-and-parked-work ()
  (let* ((tasks (list (oqt-task "done" :state "DONE")
                      (oqt-task "cancelled" :state "NOPE")
                      (oqt-task "parked" :state "HOLD")
                      (oqt-task "someday" :state "IDEA")
                      (oqt-task "live")))
         (result (org-queue-core-filter tasks oqt-today)))
    (should (equal '("live") (oqt-titles (plist-get result :eligible))))
    (should (equal '(done done state state)
                   (mapcar #'cdr (plist-get result :dropped))))))

(ert-deftest oqt/filter-keeps-wait-only-inside-the-horizon ()
  (let* ((tasks (list (oqt-task "soon" :state "WAIT" :deadline 20260910)
                      (oqt-task "later" :state "WAIT" :deadline 20261115)
                      (oqt-task "never" :state "WAIT")))
         (result (org-queue-core-filter tasks oqt-today)))
    (should (equal '("soon") (oqt-titles (plist-get result :eligible))))
    (should (equal '(waiting waiting)
                   (mapcar #'cdr (plist-get result :dropped))))))

(ert-deftest oqt/filter-drops-blocked-tasks ()
  (let* ((blocker (oqt-task "blocker"))
         (blocked (oqt-task "blocked" :blocked-by '("blocker")))
         (result (org-queue-core-filter (list blocker blocked) oqt-today)))
    (should (equal '("blocker") (oqt-titles (plist-get result :eligible))))
    (should (eq 'blocked (cdar (plist-get result :dropped))))))

(ert-deftest oqt/filter-ignores-a-finished-blocker ()
  (let* ((blocker (oqt-task "blocker" :state "DONE"))
         (blocked (oqt-task "blocked" :blocked-by '("blocker")))
         (result (org-queue-core-filter (list blocker blocked) oqt-today)))
    (should (member "blocked" (oqt-titles (plist-get result :eligible))))))

(ert-deftest oqt/filter-ignores-an-unknown-blocker ()
  "A dangling reference must not hide work."
  (let* ((blocked (oqt-task "blocked" :blocked-by '("nowhere")))
         (result (org-queue-core-filter (list blocked) oqt-today)))
    (should (equal '("blocked") (oqt-titles (plist-get result :eligible))))))

(ert-deftest oqt/filter-defers-future-scheduled-work ()
  (let* ((tasks (list (oqt-task "next-week" :scheduled 20260915)
                      (oqt-task "today" :scheduled oqt-today)
                      (oqt-task "overdue-schedule" :scheduled 20260901)))
         (result (org-queue-core-filter tasks oqt-today)))
    (should (equal '("next-week") (oqt-titles (plist-get result :deferred))))
    (should (equal '("today" "overdue-schedule")
                   (oqt-titles (plist-get result :eligible))))))


;;;; Committed versus scored

(ert-deftest oqt/committed-precedes-scored ()
  (let* ((committed (oqt-task "meeting" :scheduled oqt-today :priority ?C))
         (candidate (oqt-task "shiny" :priority ?A :created 20250101))
         (plan (org-queue-core-plan (list candidate committed) oqt-today 300)))
    (should (equal '("meeting" "shiny") (oqt-plan-titles plan)))
    (should (eq 'committed (plist-get (car (plist-get plan :planned))
                                      :queue-reason)))))

(ert-deftest oqt/what-counts-as-a-commitment ()
  (should (org-queue-core-committed-p (oqt-task "today" :scheduled oqt-today)
                                      oqt-today))
  (should (org-queue-core-committed-p (oqt-task "overdue" :deadline 20260901)
                                      oqt-today))
  (should (org-queue-core-committed-p (oqt-task "due" :deadline oqt-today)
                                      oqt-today))
  (should-not (org-queue-core-committed-p (oqt-task "later" :deadline 20260915)
                                          oqt-today))
  ;; The asymmetry: an expired deadline still binds, an expired schedule
  ;; does not, or every day is overcommitted before it starts.
  (should-not (org-queue-core-committed-p (oqt-task "stale" :scheduled 20260901)
                                          oqt-today)))

(ert-deftest oqt/a-stale-schedule-carries-over ()
  (let ((stale (oqt-task "stale" :scheduled 20260901))
        (fresh (oqt-task "fresh")))
    (should (org-queue-core-carried-p stale oqt-today))
    (should-not (org-queue-core-carried-p fresh oqt-today))
    (should (> (org-queue-core-score stale oqt-today)
               (org-queue-core-score fresh oqt-today)))
    ;; But it does not outrank a real commitment.
    (let ((plan (org-queue-core-plan
                 (list stale (oqt-task "due" :deadline oqt-today))
                 oqt-today 300)))
      (should (equal '("due" "stale") (oqt-plan-titles plan))))))


;;;; Packing

(ert-deftest oqt/capacity-is-never-exceeded ()
  (let* ((tasks (cl-loop for i from 1 to 20
                         collect (oqt-task (format "t%d" i) :effort 45)))
         (plan (org-queue-core-plan tasks oqt-today 300)))
    (should (<= (plist-get plan :minutes) (plist-get plan :usable)))
    (should (= 240 (plist-get plan :usable)))   ; 300 less 20% slack
    (should (= 5 (length (plist-get plan :planned))))
    ;; Nothing vanishes: everything is either planned or cut with a reason.
    (should (= 20 (+ (length (plist-get plan :planned))
                     (length (plist-get plan :cut)))))
    (should (cl-every (lambda (cell) (eq 'no-room (cdr cell)))
                      (plist-get plan :cut)))))

(ert-deftest oqt/an-unestimated-task-is-still-planned ()
  (let* ((plan (org-queue-core-plan (list (oqt-task "vague" :effort nil))
                                    oqt-today 300))
         (task (car (plist-get plan :planned))))
    (should (equal "vague" (plist-get task :title)))
    (should (plist-get task :queue-guessed))
    (should (= org-queue-default-effort (plist-get task :queue-minutes)))))

(ert-deftest oqt/overcommitment-is-reported-not-swallowed ()
  (let* ((tasks (list (oqt-task "big" :scheduled oqt-today :effort 240)
                      (oqt-task "bigger" :deadline 20260901 :effort 240)
                      (oqt-task "optional")))
         (plan (org-queue-core-plan tasks oqt-today 300)))
    (should (plist-get plan :overcommitted))
    ;; Both commitments survive -- the day is wrong, not the plan.
    (should (equal '("bigger" "big") (oqt-plan-titles plan)))
    (should (> (plist-get plan :minutes) (plist-get plan :usable)))
    (should (eq 'overcommitted (oqt-drop-reason plan "optional")))))

(ert-deftest oqt/glut-penalty-spreads-categories ()
  (let* ((tasks (append
                 (cl-loop for i from 1 to 3
                          collect (oqt-task (format "a%d" i)
                                            :category "a" :priority ?A))
                 (cl-loop for i from 1 to 3
                          collect (oqt-task (format "b%d" i)
                                            :category "b" :priority ?B))))
         (plan (org-queue-core-plan tasks oqt-today 300))
         (categories (mapcar (lambda (task) (plist-get task :category))
                             (plist-get plan :planned))))
    (should (= 4 (length categories)))
    ;; Without the penalty every A-priority "a" task would outrank every
    ;; "b", and the day would be all one category.
    (should (member "b" categories))
    (should (member "a" categories))))

(ert-deftest oqt/glut-penalty-can-be-turned-off ()
  (let* ((org-queue-weights (cons '(glut . 0.0) org-queue-weights))
         (tasks (append
                 (cl-loop for i from 1 to 3
                          collect (oqt-task (format "a%d" i)
                                            :category "a" :priority ?A))
                 (cl-loop for i from 1 to 3
                          collect (oqt-task (format "b%d" i)
                                            :category "b" :priority ?B))))
         (plan (org-queue-core-plan tasks oqt-today 300)))
    (should (equal '("a" "a" "a" "b")
                   (mapcar (lambda (task) (plist-get task :category))
                           (plist-get plan :planned))))))

(ert-deftest oqt/wip-limit-caps-work-in-progress ()
  (let* ((org-queue-wip-limit 2)
         (tasks (cl-loop for i from 1 to 5
                         collect (oqt-task (format "p%d" i)
                                           :state "PROG" :effort 30)))
         (plan (org-queue-core-plan tasks oqt-today 480)))
    (should (= 2 (length (plist-get plan :planned))))
    (should (eq 'wip-limit (cdar (plist-get plan :cut))))))

(ert-deftest oqt/committed-prog-counts-toward-wip-but-is-never-cut ()
  (let* ((org-queue-wip-limit 1)
         (tasks (list (oqt-task "committed" :state "PROG" :scheduled oqt-today)
                      (oqt-task "candidate" :state "PROG")))
         (plan (org-queue-core-plan tasks oqt-today 480)))
    (should (equal '("committed") (oqt-plan-titles plan)))
    (should (eq 'wip-limit (oqt-drop-reason plan "candidate")))))

(ert-deftest oqt/deferred-work-fills-an-underfull-day ()
  (let* ((tasks (list (oqt-task "today" :effort 30)
                      (oqt-task "next-week" :scheduled 20260915 :effort 30)))
         (plan (org-queue-core-plan tasks oqt-today 300)))
    (should (equal '("today" "next-week") (oqt-plan-titles plan)))
    (should (eq 'pulled-forward
                (plist-get (cadr (plist-get plan :planned)) :queue-reason)))
    (should-not (plist-get plan :deferred))))

(ert-deftest oqt/deferred-work-stays-deferred-on-a-full-day ()
  (let* ((tasks (list (oqt-task "today" :effort 240)
                      (oqt-task "next-week" :scheduled 20260915 :effort 240)))
         (plan (org-queue-core-plan tasks oqt-today 300)))
    (should (equal '("today") (oqt-plan-titles plan)))
    (should (equal '("next-week") (oqt-titles (plist-get plan :deferred))))))

(ert-deftest oqt/every-task-comes-back-out ()
  "Nothing handed to the planner disappears without a reason."
  (let* ((tasks (list (oqt-task "done" :state "DONE")
                      (oqt-task "held" :state "HOLD")
                      (oqt-task "waiting" :state "WAIT")
                      (oqt-task "later" :scheduled 20261115 :effort 600)
                      (oqt-task "big" :effort 600)
                      (oqt-task "planned" :effort 30)))
         (plan (org-queue-core-plan tasks oqt-today 120)))
    (should (= (length tasks)
               (+ (length (plist-get plan :planned))
                  (length (plist-get plan :cut))
                  (length (plist-get plan :dropped))
                  (length (plist-get plan :deferred)))))))

(ert-deftest oqt/planning-does-not-mutate-its-input ()
  (let* ((task (oqt-task "t"))
         (copy (copy-sequence task)))
    (org-queue-core-plan (list task) oqt-today 300)
    (should (equal copy task))))


;;;; Calibration

(ert-deftest oqt/calibration-learns-a-category-overrun ()
  (let* ((tasks (cl-loop for i from 1 to 3
                         collect (oqt-task (format "d%d" i) :state "DONE"
                                           :category "x" :effort 60
                                           :clocked 120)))
         (factors (org-queue-core-calibration tasks)))
    ;; raw 2.0 over three tasks, shrunk toward the global factor (1.5)
    ;; by three phantom observations.
    (should (= 1.5 (alist-get t factors)))
    (should (= 1.75 (alist-get "x" factors nil nil #'equal)))
    (should (= 105 (org-queue-core-minutes
                    (oqt-task "next" :category "x" :effort 60) factors)))))

(ert-deftest oqt/calibration-ignores-unclocked-and-unfinished-work ()
  (let* ((tasks (list (oqt-task "open" :effort 60 :clocked 600)
                      (oqt-task "unclocked" :state "DONE" :effort 60)))
         (factors (org-queue-core-calibration tasks)))
    (should (= 1.0 (alist-get t factors)))))

(ert-deftest oqt/calibration-is-clamped ()
  (let* ((org-queue-calibration-prior 0)
         (tasks (list (oqt-task "wild" :state "DONE" :effort 1 :clocked 6000)))
         (factors (org-queue-core-calibration tasks)))
    (should (= 4.0 (alist-get t factors)))))

(ert-deftest oqt/calibration-can-be-switched-off ()
  (let* ((org-queue-calibrate nil)
         (tasks (cl-loop for i from 1 to 3
                         collect (oqt-task (format "d%d" i) :state "DONE"
                                           :category "x" :effort 60
                                           :clocked 120)))
         (factors (org-queue-core-calibration tasks)))
    (should (= 1.0 (org-queue-core-factor factors "x")))
    (should (= 60 (org-queue-core-minutes
                   (oqt-task "next" :category "x" :effort 60) factors)))))

(ert-deftest oqt/calibration-shrinks-a-thin-sample ()
  "One overrunning task moves the factor a little, not all the way."
  (let* ((tasks (list (oqt-task "one" :state "DONE" :category "x"
                                :effort 60 :clocked 120)))
         (factors (org-queue-core-calibration tasks))
         (factor (org-queue-core-factor factors "x")))
    (should (< 1.0 factor 2.0))))

(ert-deftest oqt/calibration-report-carries-its-evidence ()
  (let* ((tasks (cl-loop for i from 1 to 3
                         collect (oqt-task (format "d%d" i) :state "DONE"
                                           :category "x" :effort 60
                                           :clocked 120)))
         (report (org-queue-core-calibration-report tasks))
         (row (cl-find "x" report
                       :key (lambda (r) (plist-get r :category))
                       :test #'equal)))
    (should (= 3 (plist-get row :n)))
    (should (= 2.0 (plist-get row :raw)))))


;;;; Presentation helpers

(ert-deftest oqt/format-minutes ()
  (should (equal "0:00" (org-queue-core-format-minutes 0)))
  (should (equal "1:05" (org-queue-core-format-minutes 65)))
  (should (equal "10:00" (org-queue-core-format-minutes 600))))


;;;; Appointments
;;
;; The calendar file is nothing but plain active timestamps, and it is the
;; file most able to eat a day, so these are not an edge case.

(ert-deftest oqt/an-appointment-today-is-committed ()
  (let* ((meeting (oqt-task "retro" :timestamp oqt-today :effort 60
                            :priority ?C))
         (plan (org-queue-core-plan (list meeting) oqt-today 300)))
    (should (equal '("retro") (oqt-plan-titles plan)))
    (should (eq 'committed (plist-get (car (plist-get plan :planned))
                                      :queue-reason)))))

(ert-deftest oqt/a-later-appointment-is-not-pulled-forward ()
  "Scheduled work can move to today; a meeting on Thursday cannot."
  (let* ((tasks (list (oqt-task "thursday" :timestamp 20260910 :effort 60)
                      (oqt-task "movable" :scheduled 20260910 :effort 60)))
         (plan (org-queue-core-plan tasks oqt-today 300)))
    (should (equal '("movable") (oqt-plan-titles plan)))
    (should (eq 'event-later (oqt-drop-reason plan "thursday")))))

(ert-deftest oqt/a-past-appointment-is-not-today-s-work ()
  (let* ((tasks (list (oqt-task "last-week" :timestamp nil
                                :timestamp-past 20260901)))
         (plan (org-queue-core-plan tasks oqt-today 300)))
    (should-not (plist-get plan :planned))
    (should (eq 'event-past (oqt-drop-reason plan "last-week")))))

(ert-deftest oqt/a-commitment-outranks-its-own-later-timestamp ()
  "A task both due today and stamped for Thursday is still due today."
  (let* ((task (oqt-task "both" :deadline oqt-today :timestamp 20260910))
         (plan (org-queue-core-plan (list task) oqt-today 300)))
    (should (equal '("both") (oqt-plan-titles plan)))))

;;;; Context and energy


(ert-deftest oqt/no-restriction-plans-everything ()
  "With no contexts set, context tags change nothing."
  (let* ((tasks (list (oqt-task "deep" :tags '("@deep"))
                      (oqt-task "errand" :tags '("@errand"))))
         (plan (org-queue-core-plan tasks oqt-today 300)))
    (should (equal '("deep" "errand") (sort (oqt-plan-titles plan) #'string<)))))

(ert-deftest oqt/a-restriction-drops-the-wrong-context ()
  (let* ((org-queue-contexts '("@deep"))
         (tasks (list (oqt-task "deep" :tags '("@deep"))
                      (oqt-task "errand" :tags '("@errand"))))
         (plan (org-queue-core-plan tasks oqt-today 300)))
    (should (equal '("deep") (oqt-plan-titles plan)))
    (should (eq 'context (oqt-drop-reason plan "errand")))))

(ert-deftest oqt/an-untagged-task-survives-every-restriction ()
  "The asymmetry that keeps an unmigrated corpus usable."
  (let* ((org-queue-contexts '("@call"))
         (tasks (list (oqt-task "untagged")
                      (oqt-task "errand" :tags '("@errand"))))
         (plan (org-queue-core-plan tasks oqt-today 300)))
    (should (equal '("untagged") (oqt-plan-titles plan)))))

(ert-deftest oqt/a-topic-tag-is-not-a-context ()
  "Only tags in `org-queue-context-tags' constrain anything."
  (let* ((org-queue-contexts '("@deep"))
         (tasks (list (oqt-task "topical" :tags '("release" "docs"))))
         (plan (org-queue-core-plan tasks oqt-today 300)))
    (should (equal '("topical") (oqt-plan-titles plan)))))

(ert-deftest oqt/energy-restricts-independently-of-context ()
  (let* ((org-queue-contexts '("@deep"))
         (org-queue-energy '("@tired"))
         (tasks (list (oqt-task "deep-fresh" :tags '("@deep" "@fresh"))
                      (oqt-task "deep-tired" :tags '("@deep" "@tired"))))
         (plan (org-queue-core-plan tasks oqt-today 300)))
    (should (equal '("deep-tired") (oqt-plan-titles plan)))
    (should (eq 'energy (oqt-drop-reason plan "deep-fresh")))))


;;;; Soft deadlines


(ert-deftest oqt/a-soft-deadline-pulls-less-than-a-hard-one ()
  (let ((hard (oqt-task "hard" :deadline 20260910))
        (soft (oqt-task "soft" :deadline 20260910 :deadline-soft t)))
    (should (< (org-queue-core-urgency soft oqt-today)
               (org-queue-core-urgency hard oqt-today)))
    (should (= (org-queue-core-urgency soft oqt-today)
               (* org-queue-soft-deadline-factor
                  (org-queue-core-urgency hard oqt-today))))))

(ert-deftest oqt/a-soft-deadline-still-pulls-something ()
  "Softening is not ignoring: it must still beat having no date."
  (let ((soft (oqt-task "soft" :deadline 20260910 :deadline-soft t))
        (none (oqt-task "none")))
    (should (> (org-queue-core-urgency soft oqt-today)
               (org-queue-core-urgency none oqt-today)))))

(ert-deftest oqt/a-hard-deadline-outranks-a-nearer-soft-one ()
  "The whole point: an intention must not displace a commitment."
  (let* ((tasks (list (oqt-task "soft-tomorrow" :deadline 20260909
                                :deadline-soft t :effort 120)
                      (oqt-task "hard-friday" :deadline 20260911 :effort 120)))
         ;; 200 less 20% slack is 160: room for one 120-minute task, not two.
         (plan (org-queue-core-plan tasks oqt-today 200)))
    (should (equal '("hard-friday") (oqt-plan-titles plan)))))


;;;; Impact


(ert-deftest oqt/unset-impact-is-exactly-neutral ()
  (should (= 0.0 (org-queue-core-impact-weight (oqt-task "none")))))

(ert-deftest oqt/impact-is-symmetric-about-neutral ()
  (let ((high (org-queue-core-impact-weight (oqt-task "high" :impact 5)))
        (low  (org-queue-core-impact-weight (oqt-task "low"  :impact 1))))
    (should (= 1.0 high))
    (should (= -1.0 low))
    (should (= 0.0 (+ high low)))))

(ert-deftest oqt/impact-breaks-a-tie ()
  "Two identical tasks, one marked important: that one goes first."
  (let* ((tasks (list (oqt-task "dull" :impact 1)
                      (oqt-task "vital" :impact 5)))
         ;; 100 less 20% slack is 80: one 60-minute task fits, two do not.
         (plan (org-queue-core-plan tasks oqt-today 100)))
    (should (equal '("vital") (oqt-plan-titles plan)))))


;;;; NEXT


(ert-deftest oqt/next-is-a-commitment-not-a-candidate ()
  "The manual override has to actually override, so it is never scored."
  (let ((task (oqt-task "pinned" :state "NEXT")))
    (should (org-queue-core-committed-p task oqt-today))
    (should-not (org-queue-core-done-p task))))

(ert-deftest oqt/next-survives-a-day-that-cannot-fit-it-otherwise ()
  "A NEXT task is planned even when a higher-scoring task exists."
  (let* ((tasks (list (oqt-task "pinned" :state "NEXT")
                      (oqt-task "urgent" :deadline 20260909 :priority ?A)))
         ;; 100 less 20% slack is 80: only one 60-minute task fits, and the
         ;; scorer would pick `urgent' every time.
         (plan (org-queue-core-plan tasks oqt-today 100)))
    (should (member "pinned" (oqt-plan-titles plan)))))

(ert-deftest oqt/too-many-next-tasks-overcommit-the-day ()
  "The symmetrical cost of NEXT being a fact: it is reported, not silently cut."
  (let* ((tasks (cl-loop for i from 1 to 6
                         collect (oqt-task (format "n%d" i) :state "NEXT")))
         (plan (org-queue-core-plan tasks oqt-today 100)))
    (should (plist-get plan :overcommitted))))

(provide 'org-queue-core-test)
;;; org-queue-core-test.el ends here
