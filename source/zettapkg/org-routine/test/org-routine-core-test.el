;;; org-routine-core-test.el --- ERT tests for org-routine-core -*- lexical-binding: t -*-

;;; Commentary:

;; A copy of schedule.org's table made machine-readable, and the questions
;; the rest of the config asks of it.  No Org.  Run with:
;;
;;   emacs -Q --batch -L source/zettapkg/org-routine \
;;     -l source/zettapkg/org-routine/test/org-routine-core-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'org-routine-core)

(defconst ort-table
  "| Time        | Activity               | Notes                  | kind  | days     | bucket       | habit |
|-------------+------------------------+------------------------+-------+----------+--------------+-------|
| 05:00–05:30 | Clean apartment        | dishes, laundry        | fixed |          | housekeeping | yes   |
| 05:30–06:00 | Plan the day           |                        | fixed |          |              |       |
| 06:00–07:00 | Lift weights           | toughest workout       | fixed | Mon-Sat  | body         | yes   |
| 07:00–07:30 | Get ready              |                        | fixed |          |              |       |
| 07:30–08:00 | Buffer                 | coffee                 | fixed |          |              |       |
| 08:00–12:00 | Focus block 1 (4h)     |                        | focus | weekdays | work         |       |
| 12:00–13:00 | Bike                   | midday reset           | fixed | Mon-Fri  | body         | yes   |
| 13:00–13:30 | Shower                 |                        | fixed | weekdays |              |       |
| 13:30–15:00 | Focus block 2, the dip | pomodoros              | dip   | weekdays | work         |       |
| 15:00–17:00 | Focus block 2, vague   |                        | focus | weekdays | work         |       |
| 17:00–18:00 | Dinner + walk          |                        | fixed |          |              |       |
| 18:00–20:00 | Free time / admin      | housekeeping, overflow | admin | weekdays |              |       |
| 20:00–21:00 | Read                   | no screens             | fixed |          | reading      | yes   |
| 09:00–12:00 | Weekend project block  |                        | focus | weekend  | work         |       |
| 13:00–13:30 | Laundry                |                        | fixed | Sat      | housekeeping | yes   |
| 13:30–15:00 | Weekend admin          |                        | admin | weekend  |              |       |"
  "schedule.org's table, with the three columns the code needs.")

(defconst ort-variants
  "| variant   | Time        | Activity          | kind | days |
|-----------+-------------+-------------------+------+------|
| interview | 08:00-12:00 | Interview morning | off  |      |")

(defun ort-routine (&optional variants)
  (org-routine-core-make (org-routine-core-parse ort-table "routine")
                         (and variants (org-routine-core-parse ort-variants "variants"))))

(defconst ort-mon 1)
(defconst ort-sat 6)
(defconst ort-sun 0)


;;;; Parsing

(ert-deftest ort/parse-yields-blocks-with-minutes ()
  (let ((blocks (org-routine-core-blocks (ort-routine) ort-mon)))
    (should (= 240 (plist-get (cl-find "Focus block 1 (4h)" blocks
                                       :key (lambda (b) (plist-get b :label))
                                       :test #'equal)
                              :minutes)))
    (should (equal '(fixed fixed fixed fixed fixed focus fixed fixed dip focus fixed admin fixed)
                   (mapcar (lambda (b) (plist-get b :kind)) blocks)))))

(ert-deftest ort/en-dash-and-hyphen-parse-alike ()
  (should (equal '(300 . 330) (org-routine-core-parse-range "05:00–05:30")))
  (should (equal '(300 . 330) (org-routine-core-parse-range "05:00-05:30")))
  (should (equal '(1260 . 1260) (org-routine-core-parse-range "21:00"))))

(ert-deftest ort/days-parse-in-every-form ()
  (should (equal '(1 2 3 4 5) (org-routine-core-parse-days "weekdays")))
  (should (equal '(1 2 3 4 5 6) (org-routine-core-parse-days "Mon-Sat")))
  (should (equal '(0 6) (org-routine-core-parse-days "Sat Sun")))
  (should (equal '(1 3) (org-routine-core-parse-days "Mon, Wed")))
  (should-not (org-routine-core-parse-days ""))
  (should-error (org-routine-core-parse-days "Mon Fnord")))

(ert-deftest ort/a-malformed-time-fails-with-its-line ()
  (let ((bad (replace-regexp-in-string "13:00–13:30 | Shower" "13:00–13:7x | Shower" ort-table)))
    (should (string-match-p "line 10" (cadr (should-error (org-routine-core-parse bad "routine")))))))

(ert-deftest ort/a-table-without-a-kind-column-fails-with-its-line ()
  (let ((bad "| Time | Activity |\n|---+---|\n| 08:00-12:00 | Focus |"))
    (should (string-match-p "line 1.*kind" (cadr (should-error (org-routine-core-parse bad "routine")))))))

(ert-deftest ort/an-unknown-kind-fails-with-its-line ()
  (let ((bad (replace-regexp-in-string "| admin | weekdays |" "| nap   | weekdays |"
                                       ort-table)))
    (should (string-match-p "line 14.*nap" (cadr (should-error (org-routine-core-parse bad "routine")))))))

(ert-deftest ort/overlapping-rows-on-a-shared-day-fail ()
  (let ((bad (concat ort-table "\n| 08:30–09:00 | Standup | | fixed | | | |")))
    (should-error (org-routine-core-make (org-routine-core-parse bad)))))

(ert-deftest ort/rows-on-different-days-may-share-a-time ()
  "The weekend block sits over the weekday one without complaint."
  (should (org-routine-core-make (org-routine-core-parse ort-table))))


;;;; Capacity

(ert-deftest ort/monday-discretionary-is-the-focus-and-admin-rows ()
  (should (= 570 (org-routine-core-discretionary (ort-routine) ort-mon))))

(ert-deftest ort/capacity-is-discretionary-less-slack ()
  (should (= 456 (org-routine-core-capacity (ort-routine) ort-mon 0.2))))

(ert-deftest ort/weekend-capacity-comes-from-the-weekend-rows ()
  (should (= 270 (org-routine-core-discretionary (ort-routine) ort-sat)))
  (should (= 216 (org-routine-core-capacity (ort-routine) ort-sun 0.2)))
  (should (equal '((0 . 216) (1 . 456) (2 . 456) (3 . 456) (4 . 456) (5 . 456) (6 . 216))
                 (org-routine-core-capacity-table (ort-routine) 0.2))))

(ert-deftest ort/no-two-blocks-overlap-and-each-starts-before-it-ends ()
  (dolist (weekday '(0 1 2 3 4 5 6))
    (let ((blocks (org-routine-core-active-blocks (ort-routine) weekday)))
      (cl-loop for (a b) on blocks while b
               do (should (<= (plist-get a :end) (plist-get b :start))))
      (dolist (block blocks)
        (should (< (plist-get block :start) (plist-get block :end)))))))


;;;; The dip, the fixed rows, the habits

(ert-deftest ort/the-dip-is-13-30-to-15-00-on-a-weekday ()
  (should (equal '((810 . 900)) (org-routine-core-dip (ort-routine) ort-mon)))
  (should (org-routine-core-in-dip-p (ort-routine) ort-mon 810))
  (should (org-routine-core-in-dip-p (ort-routine) ort-mon 870))
  (should-not (org-routine-core-in-dip-p (ort-routine) ort-mon 900))
  (should-not (org-routine-core-in-dip-p (ort-routine) ort-mon 660))
  (should-not (org-routine-core-in-dip-p (ort-routine) ort-mon 960)))

(ert-deftest ort/the-first-two-hours-are-a-dip-only-when-asked ()
  "Part 6 question 1: the default follows the principle, not the prose."
  (should-not (org-routine-core-in-dip-p (ort-routine) ort-mon 570))
  (let ((org-routine-dip-first-hours t))
    (should (org-routine-core-in-dip-p (ort-routine) ort-mon 570))
    (should-not (org-routine-core-in-dip-p (ort-routine) ort-mon 660))
    (should (equal '((480 . 600) (810 . 900)) (org-routine-core-dip (ort-routine) ort-mon)))))

(ert-deftest ort/a-fixed-row-appears-on-every-weekday-it-names ()
  (let ((lift (lambda (weekday)
                (cl-find "Lift weights" (org-routine-core-fixed (ort-routine) weekday)
                         :key (lambda (b) (plist-get b :label)) :test #'equal))))
    (dolist (weekday '(1 2 3 4 5 6)) (should (funcall lift weekday)))
    (should-not (funcall lift ort-sun))))

(ert-deftest ort/habit-entries-carry-minutes-and-days ()
  (let ((habits (org-routine-core-habit-entries (ort-routine))))
    (should (= 5 (length habits)))
    (should (equal '("Clean apartment" "Lift weights" "Bike" "Read" "Laundry")
                   (mapcar (lambda (h) (plist-get h :title)) habits)))
    (let ((lift (nth 1 habits)))
      (should (= 60 (plist-get lift :minutes)))
      (should (equal '(1 2 3 4 5 6) (plist-get lift :days)))
      (should (eq 'body (plist-get lift :bucket))))
    (should-not (plist-get (nth 0 habits) :days))
    (should (equal '(6) (plist-get (nth 4 habits) :days)))))


;;;; Variants

(ert-deftest ort/an-interview-variant-removes-the-focus-minutes-and-says-so ()
  (let* ((routine (ort-routine t))
         (blocks (org-routine-core-blocks routine ort-mon "interview"))
         (removed (cl-find-if (lambda (b) (plist-get b :removed-by)) blocks)))
    (should (equal "Focus block 1 (4h)" (plist-get removed :label)))
    (should (equal "interview" (plist-get removed :removed-by)))
    (should (= 330 (org-routine-core-discretionary routine ort-mon "interview")))
    (should (= 570 (org-routine-core-discretionary routine ort-mon)))
    (should (cl-some (lambda (line) (string-match-p "removed by interview" line))
                     (org-routine-core-report routine ort-mon 0.2 "interview")))))


;;;; Derived tables

(ert-deftest ort/the-derived-bucket-table-for-monday ()
  "Focus and dip are work, admin is housekeeping, habits have their own
bucket, and default is what is left."
  (let* ((org-routine-default-bucket-minutes 60)
         (buckets (org-routine-core-buckets (ort-routine) 0.2))
         (minutes (lambda (name weekday)
                    (alist-get weekday (plist-get (alist-get name buckets) :minutes)))))
    (should (= 450 (funcall minutes 'work ort-mon)))
    (should (= 150 (funcall minutes (quote housekeeping) ort-mon)))  ; admin 120 + the clean 30
    (should (= 120 (funcall minutes 'body ort-mon)))
    (should (= 60 (funcall minutes 'reading ort-mon)))
    (should (= 60 (plist-get (alist-get 'default buckets) :minutes)))
    ;; Saturday: the weekend block, the weekend admin, the lift, laundry and the clean.
    (should (= 180 (funcall minutes 'work ort-sat)))
    (should (= 150 (funcall minutes 'housekeeping ort-sat)))
    (should (= 60 (funcall minutes 'body ort-sat)))
    (should (= 0 (funcall minutes 'body ort-sun)))
    ;; The default bucket is last, so the first match rule still works.
    (should (eq 'default (car (car (last buckets)))))))

(ert-deftest ort/matches-are-attached-to-the-buckets-that-have-them ()
  (let ((buckets (org-routine-core-buckets
                  (ort-routine) 0.2 nil
                  '((work . (:category ("work" "emacs")))
                    (body . (:tags ("body")))))))
    (should (equal '(:category ("work" "emacs"))
                   (plist-get (alist-get 'work buckets) :match)))
    (should-not (plist-get (alist-get 'housekeeping buckets) :match))))


;;;; Windows for the chains

(ert-deftest ort/kick-review-and-quiet-windows-follow-the-blocks ()
  (let ((windows (org-routine-core-windows (ort-routine) ort-mon)))
    ;; Before the first fixed row (the clean at 05:00), and the start of
    ;; every focus and dip block.
    (should (equal '((290 . 300) (480 . 490) (810 . 820) (900 . 910))
                   (plist-get windows :kick)))
    (should (equal '((705 . 720) (885 . 900) (1005 . 1020))
                   (plist-get windows :review)))
    ;; Quiet is the middle of the focus blocks only; the dip is never quiet.
    (should (equal '((490 . 705) (910 . 1005)) (plist-get windows :quiet)))
    (should (org-routine-core-in-window-p (plist-get windows :quiet) 600))
    (should-not (org-routine-core-in-window-p (plist-get windows :quiet) 850))))

(ert-deftest ort/block-at-names-the-block-under-a-minute ()
  (should (equal "Bike" (plist-get (org-routine-core-block-at (ort-routine) ort-mon 730) :label)))
  (should-not (org-routine-core-block-at (ort-routine) ort-mon 1270)))

(provide 'org-routine-core-test)
;;; org-routine-core-test.el ends here
