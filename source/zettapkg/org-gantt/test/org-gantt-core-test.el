;;; org-gantt-core-test.el --- Tests for org-gantt-core -*- lexical-binding: t; -*-

;;; Commentary:

;; Plists in, plists out, no Org and no files:
;;
;;   emacs -Q --batch -L source/zettapkg/org-gantt \
;;     -l source/zettapkg/org-gantt/test/org-gantt-core-test.el \
;;     -f ert-run-tests-batch-and-exit
;;
;; The clock is pinned and so is the zone.  Every fixture is written in
;; UTC, because a suite that passes in London and fails in Sydney tests
;; the machine rather than the arithmetic.

;;; Code:

(require 'ert)
(setenv "TZ" "UTC")
(set-time-zone-rule "UTC")
(require 'org-gantt-core)

(defun org-gantt-test--at (year month day hour minute)
  "Return epoch seconds for the given UTC wall time."
  (floor (float-time (encode-time (list 0 minute hour day month year nil nil 0)))))

;; 2026-09-08 is a Tuesday, the day the test corpus schedules against.
(defconst org-gantt-test--tue (org-gantt-test--at 2026 9 8 0 0))
(defconst org-gantt-test--wed (org-gantt-test--at 2026 9 9 0 0))

(defconst org-gantt-test--window
  '((t . ((480 . 720) (810 . 1020))))
  "08:00-12:00 and 13:30-17:00 every day, the shape G15's clipping case uses.")

(defun org-gantt-test--row (&rest overrides)
  "Return a row plist with OVERRIDES applied over sane defaults."
  (append overrides
          (list :id "fixture" :title "A task" :category "work"
                :intervals nil :plans nil)))


;;;; Intervals to segments

(ert-deftest org-gantt-core-test-agent-minutes-are-machine-not-worked ()
  "PROG 09:00-09:20, AGENT 09:20-23:40 (overnight, outside the window),
NEXT after: 20 worked minutes, 860 machine minutes, and the machine
segment is kept whole in :clipped."
  (let* ((row (org-gantt-test--row
               :intervals (list (list :state "PROG"
                                      :start (org-gantt-test--at 2026 9 8 9 0)
                                      :end (org-gantt-test--at 2026 9 8 9 20))
                                (list :state "AGENT"
                                      :start (org-gantt-test--at 2026 9 8 9 20)
                                      :end (org-gantt-test--at 2026 9 8 23 40))
                                (list :state "NEXT"
                                      :start (org-gantt-test--at 2026 9 8 23 40)
                                      :end (org-gantt-test--at 2026 9 9 8 0)))))
         (org-gantt-window org-gantt-test--window)
         (measured (car (org-gantt-core-summarize
                         (list row) (org-gantt-test--at 2026 9 9 9 0)))))
    (should (= 20 (plist-get measured :worked)))
    (should (= 860 (plist-get measured :machine)))
    (should (eq 'machine (org-gantt-core-class "AGENT")))
    (let ((machine (cl-find 'machine (plist-get measured :clipped)
                            :key (lambda (s) (plist-get s :class)))))
      (should machine)
      (should (= (org-gantt-test--at 2026 9 8 23 40) (plist-get machine :end))))))

(ert-deftest org-gantt-core-test-open-and-close ()
  "TODO -> PROG at 09:12 then PROG -> DONE at 10:40 is one 88-minute bar."
  (let* ((row (org-gantt-test--row
               :intervals (list (list :state "TODO"
                                      :start (org-gantt-test--at 2026 9 8 9 0)
                                      :end (org-gantt-test--at 2026 9 8 9 12))
                                (list :state "PROG"
                                      :start (org-gantt-test--at 2026 9 8 9 12)
                                      :end (org-gantt-test--at 2026 9 8 10 40))
                                (list :state "DONE"
                                      :start (org-gantt-test--at 2026 9 8 10 40)
                                      :end (org-gantt-test--at 2026 9 8 10 40)))))
         (org-gantt-window org-gantt-test--window)
         (measured (car (org-gantt-core-summarize
                         (list row) (org-gantt-test--at 2026 9 8 18 0)))))
    (should (= 88 (plist-get measured :worked)))
    (should (= 1 (plist-get measured :sessions)))
    (should-not (plist-get measured :open))
    ;; The DONE interval is not drawn: the bar ends where the work does.
    (should (= 2 (length (plist-get measured :segments))))))

(ert-deftest org-gantt-core-test-wait-closes-and-reopens ()
  "PROG -> WAIT closes an interval exactly as DONE would; WAIT -> PROG opens another."
  (let* ((row (org-gantt-test--row
               :intervals (list (list :state "PROG"
                                      :start (org-gantt-test--at 2026 9 8 9 0)
                                      :end (org-gantt-test--at 2026 9 8 10 0))
                                (list :state "WAIT"
                                      :start (org-gantt-test--at 2026 9 8 10 0)
                                      :end (org-gantt-test--at 2026 9 8 11 0))
                                (list :state "PROG"
                                      :start (org-gantt-test--at 2026 9 8 11 0)
                                      :end (org-gantt-test--at 2026 9 8 11 30)))))
         (org-gantt-window org-gantt-test--window)
         (measured (car (org-gantt-core-summarize
                         (list row) (org-gantt-test--at 2026 9 8 18 0)))))
    (should (= 90 (plist-get measured :worked)))
    (should (= 2 (plist-get measured :sessions)))
    ;; Waiting is elapsed but never worked.
    (should (= 150 (plist-get measured :elapsed)))))

(ert-deftest org-gantt-core-test-todo-to-done-is-zero ()
  "A task that went straight to DONE measures zero and draws no working bar."
  (let* ((row (org-gantt-test--row
               :intervals (list (list :state "TODO"
                                      :start (org-gantt-test--at 2026 9 8 9 0)
                                      :end (org-gantt-test--at 2026 9 8 9 30))
                                (list :state "DONE"
                                      :start (org-gantt-test--at 2026 9 8 9 30)
                                      :end (org-gantt-test--at 2026 9 8 9 30)))))
         (org-gantt-window org-gantt-test--window)
         (measured (car (org-gantt-core-summarize
                         (list row) (org-gantt-test--at 2026 9 8 18 0)))))
    (should (= 0 (plist-get measured :worked)))
    (should (= 0 (plist-get measured :sessions)))
    (should (null (plist-get measured :ratio)))))

(ert-deftest org-gantt-core-test-unestimated-has-no-ratio ()
  "An unestimated row reports its minutes and no ratio, rather than a ratio of zero."
  (let* ((row (org-gantt-test--row
               :effort nil
               :intervals (list (list :state "PROG"
                                      :start (org-gantt-test--at 2026 9 8 9 0)
                                      :end (org-gantt-test--at 2026 9 8 10 0)))))
         (org-gantt-window org-gantt-test--window)
         (measured (car (org-gantt-core-summarize
                         (list row) (org-gantt-test--at 2026 9 8 18 0)))))
    (should (= 60 (plist-get measured :worked)))
    (should (null (plist-get measured :ratio)))))


;;;; Clipping

(ert-deftest org-gantt-core-test-clip-across-midnight ()
  "16:00 Tuesday to 10:00 Wednesday clips to 60 + 120, with the raw span kept."
  (let* ((row (org-gantt-test--row
               :intervals (list (list :state "PROG"
                                      :start (org-gantt-test--at 2026 9 8 16 0)
                                      :end (org-gantt-test--at 2026 9 9 10 0)))))
         (org-gantt-window org-gantt-test--window)
         (measured (car (org-gantt-core-summarize
                         (list row) (org-gantt-test--at 2026 9 9 18 0)))))
    (should (= 180 (plist-get measured :worked)))
    ;; Elapsed is raw and stays raw: the task really was open all night.
    (should (= (* 18 60) (plist-get measured :elapsed)))
    (should (= 2 (length (plist-get measured :clipped))))))

(ert-deftest org-gantt-core-test-clip-drops-a-closed-day ()
  "A weekend with no window contributes nothing, and does not error."
  (let* ((org-gantt-window '((6 . nil) (0 . nil) (t . ((480 . 1080)))))
         ;; 2026-09-12 is a Saturday.
         (row (org-gantt-test--row
               :intervals (list (list :state "PROG"
                                      :start (org-gantt-test--at 2026 9 12 9 0)
                                      :end (org-gantt-test--at 2026 9 12 17 0)))))
         (measured (car (org-gantt-core-summarize
                         (list row) (org-gantt-test--at 2026 9 13 9 0)))))
    (should (= 0 (plist-get measured :worked)))
    (should (= 480 (plist-get measured :elapsed)))))

(ert-deftest org-gantt-core-test-clip-keeps-open-on-the-last-piece-only ()
  "Clipping an open interval leaves `:open' on the piece that reaches its end."
  (let* ((segments (list (list :state "PROG" :class 'working
                               :start (org-gantt-test--at 2026 9 8 16 0)
                               :end (org-gantt-test--at 2026 9 9 10 0)
                               :open t)))
         (org-gantt-window org-gantt-test--window)
         (clipped (org-gantt-core-clip
                   segments
                   (org-gantt-core-windows (org-gantt-test--at 2026 9 8 16 0)
                                           (org-gantt-test--at 2026 9 9 10 0)))))
    (should (= 2 (length clipped)))
    (should-not (plist-get (nth 0 clipped) :open))
    (should (plist-get (nth 1 clipped) :open))))


;;;; Overlap

(ert-deftest org-gantt-core-test-overlap-policies ()
  "Two rows working at once are credited by policy, not by accident."
  (let* ((org-gantt-window org-gantt-test--window)
         (rows (list (org-gantt-test--row
                      :id "a"
                      :intervals (list (list :state "PROG"
                                             :start (org-gantt-test--at 2026 9 8 9 0)
                                             :end (org-gantt-test--at 2026 9 8 10 0))))
                     (org-gantt-test--row
                      :id "b"
                      :intervals (list (list :state "PROG"
                                             :start (org-gantt-test--at 2026 9 8 9 30)
                                             :end (org-gantt-test--at 2026 9 8 10 0))))))
         (now (org-gantt-test--at 2026 9 8 18 0)))
    (let ((org-gantt-overlap 'wall))
      (let ((measured (org-gantt-core-summarize rows now)))
        (should (equal '(60 30) (mapcar (lambda (r) (plist-get r :worked)) measured)))))
    (let ((org-gantt-overlap 'share))
      (let ((measured (org-gantt-core-summarize rows now)))
        (should (equal '(45 15) (mapcar (lambda (r) (plist-get r :worked)) measured)))))
    (let ((org-gantt-overlap 'latest))
      (let ((measured (org-gantt-core-summarize rows now)))
        (should (equal '(30 30) (mapcar (lambda (r) (plist-get r :worked)) measured)))))))

(ert-deftest org-gantt-core-test-share-never-exceeds-the-clock ()
  "Under `share', three rows over one hour sum to one hour, not three."
  (let* ((org-gantt-window org-gantt-test--window)
         (org-gantt-overlap 'share)
         (rows (mapcar (lambda (id)
                         (org-gantt-test--row
                          :id id
                          :intervals (list (list :state "PROG"
                                                 :start (org-gantt-test--at 2026 9 8 9 0)
                                                 :end (org-gantt-test--at 2026 9 8 10 0)))))
                       '("a" "b" "c")))
         (measured (org-gantt-core-summarize rows (org-gantt-test--at 2026 9 8 18 0))))
    (should (= 60 (apply #'+ (mapcar (lambda (r) (plist-get r :worked)) measured))))))


;;;; Open and stale

(ert-deftest org-gantt-core-test-open-runs-to-now ()
  "An entry still in PROG measures to the pinned now and says it is open."
  (let* ((org-gantt-window org-gantt-test--window)
         (row (org-gantt-test--row
               :intervals (list (list :state "PROG"
                                      :start (org-gantt-test--at 2026 9 8 9 0)
                                      :end nil :open t))))
         (measured (car (org-gantt-core-summarize
                         (list row) (org-gantt-test--at 2026 9 8 10 30)))))
    (should (plist-get measured :open))
    (should (= 90 (plist-get measured :worked)))
    (should-not (plist-get measured :stale))))

(ert-deftest org-gantt-core-test-stale-reports-the-day-it-opened ()
  "A PROG left open from a previous day is stale, and names that day."
  (let* ((org-gantt-window org-gantt-test--window)
         (row (org-gantt-test--row
               :intervals (list (list :state "PROG"
                                      :start (org-gantt-test--at 2026 9 8 9 0)
                                      :end nil :open t))))
         (measured (car (org-gantt-core-summarize
                         (list row) (org-gantt-test--at 2026 9 9 10 0)))))
    (should (plist-get measured :open))
    (should (equal org-gantt-test--tue (plist-get measured :stale)))))


;;;; Plans

(ert-deftest org-gantt-core-test-fixed-plan-is-left-alone ()
  "A plan that already names an hour is never moved."
  (let* ((plan (list :kind 'schedule
                     :start (org-gantt-test--at 2026 9 8 14 0)
                     :end (org-gantt-test--at 2026 9 8 15 0)))
         (placed (car (org-gantt-core-place-plans
                       (list (org-gantt-test--row :plans (list plan)))
                       (list (cons (org-gantt-test--at 2026 9 8 8 0)
                                   (org-gantt-test--at 2026 9 8 17 0)))))))
    (should (equal plan (car (plist-get placed :plans))))))

(ert-deftest org-gantt-core-test-flowing-plans-lay-end-to-end ()
  "Two untimed plans fill the day in row order."
  (let* ((rows (list (org-gantt-test--row
                      :id "a"
                      :plans (list (list :kind 'queue :day org-gantt-test--tue :minutes 60)))
                     (org-gantt-test--row
                      :id "b"
                      :plans (list (list :kind 'queue :day org-gantt-test--tue :minutes 30)))))
         (placed (org-gantt-core-place-plans
                  rows (list (cons (org-gantt-test--at 2026 9 8 8 0)
                                   (org-gantt-test--at 2026 9 8 17 0)))))
         (first (car (plist-get (nth 0 placed) :plans)))
         (second (car (plist-get (nth 1 placed) :plans))))
    (should (equal (org-gantt-test--at 2026 9 8 8 0) (plist-get first :start)))
    (should (equal (org-gantt-test--at 2026 9 8 9 0) (plist-get first :end)))
    (should (equal (org-gantt-test--at 2026 9 8 9 0) (plist-get second :start)))
    (should (equal (org-gantt-test--at 2026 9 8 9 30) (plist-get second :end)))))

(ert-deftest org-gantt-core-test-flowing-plans-avoid-a-meeting ()
  "An untimed plan flows around an hour the calendar already owns."
  (let* ((rows (list (org-gantt-test--row
                      :id "meeting"
                      :plans (list (list :kind 'schedule
                                         :start (org-gantt-test--at 2026 9 8 8 0)
                                         :end (org-gantt-test--at 2026 9 8 9 0))))
                     (org-gantt-test--row
                      :id "work"
                      :plans (list (list :kind 'queue :day org-gantt-test--tue :minutes 60)))))
         (placed (org-gantt-core-place-plans
                  rows (list (cons (org-gantt-test--at 2026 9 8 8 0)
                                   (org-gantt-test--at 2026 9 8 17 0)))))
         (work (car (plist-get (nth 1 placed) :plans))))
    (should (equal (org-gantt-test--at 2026 9 8 9 0) (plist-get work :start)))))

(ert-deftest org-gantt-core-test-a-plan-that-will-not-fit-is-short-then-unplaced ()
  "Overcommitment draws as a short bar, then as nothing, and never as a lie."
  (let* ((rows (list (org-gantt-test--row
                      :id "a"
                      :plans (list (list :kind 'queue :day org-gantt-test--tue :minutes 240)))
                     (org-gantt-test--row
                      :id "b"
                      :plans (list (list :kind 'queue :day org-gantt-test--tue :minutes 240)))))
         (placed (org-gantt-core-place-plans
                  rows (list (cons (org-gantt-test--at 2026 9 8 8 0)
                                   (org-gantt-test--at 2026 9 8 11 0)))))
         (first (car (plist-get (nth 0 placed) :plans)))
         (second (car (plist-get (nth 1 placed) :plans))))
    (should (plist-get first :short))
    (should (equal (org-gantt-test--at 2026 9 8 11 0) (plist-get first :end)))
    (should (plist-get second :unplaced))))

(ert-deftest org-gantt-core-test-subtract ()
  "Removing a busy span splits the window it lands in the middle of."
  (should (equal '((0 . 10) (20 . 30))
                 (org-gantt-core-subtract '((0 . 30)) '((10 . 20)))))
  (should (equal '((0 . 30))
                 (org-gantt-core-subtract '((0 . 30)) '((40 . 50)))))
  (should (equal nil
                 (org-gantt-core-subtract '((0 . 30)) '((0 . 30))))))


;;;; Layout and axis

(ert-deftest org-gantt-core-test-layout-fractions ()
  "A bar's x coordinates are its share of the drawn span."
  (let* ((org-gantt-window org-gantt-test--window)
         (row (org-gantt-test--row
               :deadline (org-gantt-test--at 2026 9 9 0 0)
               :intervals (list (list :state "PROG"
                                      :start (org-gantt-test--at 2026 9 8 12 0)
                                      :end (org-gantt-test--at 2026 9 8 18 0)))))
         (chart (org-gantt-core-chart (list row)
                                      org-gantt-test--tue
                                      (org-gantt-test--at 2026 9 10 0 0)
                                      :now (org-gantt-test--at 2026 9 9 12 0)))
         (drawn (car (plist-get chart :rows)))
         (working (cl-find-if (lambda (bar) (eq (plist-get bar :class) 'working))
                              (plist-get drawn :bars))))
    (should (< (abs (- 0.25 (plist-get working :x0))) 0.001))
    (should (< (abs (- 0.375 (plist-get working :x1))) 0.001))
    (should (cl-find-if (lambda (mark) (eq (plist-get mark :kind) 'deadline))
                        (plist-get drawn :marks)))
    (should (< (abs (- 0.75 (plist-get chart :now-x))) 0.001))))

(ert-deftest org-gantt-core-test-layout-flags-a-bar-that-leaves-the-window ()
  "A row that started before the chart says so, rather than appearing to start at its edge."
  (let* ((org-gantt-window org-gantt-test--window)
         (row (org-gantt-test--row
               :intervals (list (list :state "PROG"
                                      :start (org-gantt-test--at 2026 9 1 9 0)
                                      :end (org-gantt-test--at 2026 9 9 10 0)))))
         (chart (org-gantt-core-chart (list row) org-gantt-test--tue
                                      (org-gantt-test--at 2026 9 10 0 0)
                                      :now (org-gantt-test--at 2026 9 10 0 0)))
         (span (cl-find-if (lambda (bar) (eq (plist-get bar :class) 'span))
                           (plist-get (car (plist-get chart :rows)) :bars))))
    (should (plist-get span :continues-left))
    (should-not (plist-get span :continues-right))
    (should (= 0.0 (plist-get span :x0)))))

(ert-deftest org-gantt-core-test-ticks-coarsen-with-the-span ()
  "The axis relabels itself rather than smearing day names across a quarter."
  (let ((day (* 60 60 24)))
    (should (cl-some (lambda (tick) (equal "10" (plist-get tick :label)))
                     (org-gantt-core-ticks org-gantt-test--tue
                                           (+ org-gantt-test--tue day))))
    (should (= 7 (length (org-gantt-core-ticks org-gantt-test--tue
                                               (+ org-gantt-test--tue (* 7 day))))))
    ;; A quarter gets one tick a week, not ninety.
    (should (< (length (org-gantt-core-ticks org-gantt-test--tue
                                             (+ org-gantt-test--tue (* 90 day))))
               20))
    ;; A year gets months.
    (should (equal "Jan" (plist-get (car (org-gantt-core-ticks
                                          (org-gantt-test--at 2026 12 20 0 0)
                                          (org-gantt-test--at 2027 12 20 0 0)))
                                    :label)))))


;;;; Totals and grouping

(ert-deftest org-gantt-core-test-groups-and-totals ()
  "Rows gather by category, and a group's span covers its members."
  (let* ((org-gantt-window org-gantt-test--window)
         (rows (list (org-gantt-test--row
                      :id "a" :category "work" :effort 60
                      :intervals (list (list :state "PROG"
                                             :start (org-gantt-test--at 2026 9 8 9 0)
                                             :end (org-gantt-test--at 2026 9 8 10 0))))
                     (org-gantt-test--row
                      :id "b" :category "home" :effort 30
                      :intervals (list (list :state "PROG"
                                             :start (org-gantt-test--at 2026 9 8 14 0)
                                             :end (org-gantt-test--at 2026 9 8 15 0))))))
         (chart (org-gantt-core-chart rows org-gantt-test--tue org-gantt-test--wed
                                      :now (org-gantt-test--at 2026 9 8 18 0)
                                      :group :category))
         (groups (plist-get chart :groups))
         (totals (plist-get chart :totals)))
    (should (= 2 (length groups)))
    (should (equal "home" (plist-get (car groups) :name)))
    (should (= 120 (plist-get totals :worked)))
    (should (= 90 (plist-get totals :effort)))
    ;; 120 worked against 90 estimated: the calibration finding, visible.
    (should (< (abs (- 1.333 (plist-get totals :ratio))) 0.01))))

(ert-deftest org-gantt-core-test-format-minutes ()
  (should (equal "2:10" (org-gantt-core-format-minutes 130)))
  (should (equal "0:05" (org-gantt-core-format-minutes 5)))
  (should (equal "-" (org-gantt-core-format-minutes nil)))
  (should (equal "45m" (org-gantt-core-format-span 45)))
  (should (equal "2.0h" (org-gantt-core-format-span 120)))
  (should (equal "1.5d" (org-gantt-core-format-span (* 36 60)))))

(ert-deftest org-gantt-core-test-stale-minutes-are-provisional ()
  "A row still in PROG since yesterday reports its minutes, and flags them.

The bar is honest -- it really has been in PROG since Tuesday -- but
the number is an upper bound, and calibrating against it silently would
teach the queue that everything takes days."
  (let* ((org-gantt-window org-gantt-test--window)
         (rows (list (org-gantt-test--row
                      :id "left-open"
                      :intervals (list (list :state "PROG"
                                             :start (org-gantt-test--at 2026 9 8 9 0)
                                             :end nil :open t)))
                     (org-gantt-test--row
                      :id "finished"
                      :intervals (list (list :state "PROG"
                                             :start (org-gantt-test--at 2026 9 9 9 0)
                                             :end (org-gantt-test--at 2026 9 9 10 0))))))
         (chart (org-gantt-core-chart rows
                                      (org-gantt-test--at 2026 9 8 0 0)
                                      (org-gantt-test--at 2026 9 10 0 0)
                                      :now (org-gantt-test--at 2026 9 9 10 0)))
         (totals (plist-get chart :totals))
         (open (cl-find "left-open" (plist-get chart :rows)
                        :key (lambda (r) (plist-get r :id)) :test #'equal))
         (done (cl-find "finished" (plist-get chart :rows)
                        :key (lambda (r) (plist-get r :id)) :test #'equal)))
    (should (plist-get open :provisional))
    (should-not (plist-get done :provisional))
    ;; Tuesday 09:00-12:00 and 13:30-17:00, then Wednesday 08:00-10:00:
    ;; 180 + 210 + 120.  Nothing marked the two nights, and nothing
    ;; pretends otherwise -- the number is flagged, not trimmed.
    (should (= 510 (plist-get open :worked)))
    (should (= 510 (plist-get totals :provisional)))
    ;; The finished row's hour overlaps the open one's, and under `wall'
    ;; both are credited in full.
    (should (= 570 (plist-get totals :worked)))))

(ert-deftest org-gantt-core-test-day-minutes-round-trip ()
  "The grid's coordinate and the core's second agree in both directions."
  (let ((at (org-gantt-test--at 2026 9 8 13 45)))
    (should (= at (org-gantt-core-from-day-minutes
                   (org-gantt-core-day-minutes at))))
    ;; A whole day is 1440 minutes apart, midnight to midnight.
    (should (= 1440 (- (org-gantt-core-day-minutes (org-gantt-test--at 2026 9 9 0 0))
                       (org-gantt-core-day-minutes (org-gantt-test--at 2026 9 8 0 0)))))
    (should (= (* 13 60) (% (org-gantt-core-day-minutes
                             (org-gantt-test--at 2026 9 8 13 0))
                            1440)))))

(provide 'org-gantt-core-test)
;;; org-gantt-core-test.el ends here
