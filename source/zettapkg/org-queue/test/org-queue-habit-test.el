;;; org-queue-habit-test.el --- ERT tests for the habit strength core -*- lexical-binding: t -*-

;;; Commentary:

;; Hand-built series, no Org.  Run with:
;;
;;   emacs -Q --batch -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-queue/test/org-queue-habit-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'org-queue-habit-core)

(defun oqb-run (n mark &optional start)
  "A series of N days marked MARK from START."
  (let ((day (or start 20260801)) series)
    (dotimes (_ n)
      (push (cons day mark) series)
      (setq day (org-queue-habit-core--add-days day 1)))
    (nreverse series)))

(defun oqb-near (a b) (< (abs (- a b)) 0.005))

(ert-deftest oqb/thirty-sixty-and-ninety-consecutive-days ()
  (let ((org-queue-habit-half-life 13))
    (should (oqb-near 0.798 (plist-get (org-queue-habit-core-score (oqb-run 30 'done)) :score)))
    (should (oqb-near 0.959 (plist-get (org-queue-habit-core-score (oqb-run 60 'done)) :score)))
    (should (oqb-near 0.992 (plist-get (org-queue-habit-core-score (oqb-run 90 'done)) :score)))
    ;; The closed form agrees.
    (should (oqb-near (org-queue-habit-core-closed-form 30)
                      (plist-get (org-queue-habit-core-score (oqb-run 30 'done)) :score)))))

(ert-deftest oqb/one-miss-multiplies-by-m-and-raises-no-alert ()
  (let* ((thirty (plist-get (org-queue-habit-core-score (oqb-run 30 'done)) :score))
         (after (org-queue-habit-core-score (append (oqb-run 30 'done)
                                                    (list (cons 20260831 'miss))))))
    (should (oqb-near (* thirty (org-queue-habit-core-factor)) (plist-get after :score)))
    (should-not (plist-get after :alert))))

(ert-deftest oqb/two-consecutive-misses-alert-and-a-done-clears-it ()
  (let ((two (org-queue-habit-core-score (append (oqb-run 30 'done)
                                                 (list (cons 20260831 'miss) (cons 20260901 'miss)))))
        (repaired (org-queue-habit-core-score (append (oqb-run 30 'done)
                                                      (list (cons 20260831 'miss) (cons 20260901 'miss)
                                                            (cons 20260902 'done))))))
    (should (eq 'two-misses (plist-get two :alert)))
    (should (= 2 (plist-get two :misses)))
    (should-not (plist-get repaired :alert))))

(ert-deftest oqb/a-skip-leaves-the-score-and-is-not-a-miss ()
  (let ((base (plist-get (org-queue-habit-core-score (oqb-run 30 'done)) :score))
        (skipped (org-queue-habit-core-score (append (oqb-run 30 'done)
                                                     (list (cons 20260831 'skip) (cons 20260901 'miss))))))
    (should (oqb-near (* base (org-queue-habit-core-factor)) (plist-get skipped :score)))
    (should-not (plist-get skipped :alert))))

(ert-deftest oqb/the-score-stays-in-range ()
  (should (<= 0.0 (plist-get (org-queue-habit-core-score nil) :score) 1.0))
  (should (<= 0.0 (plist-get (org-queue-habit-core-score (oqb-run 400 'done)) :score) 1.0))
  (should (= 0.0 (plist-get (org-queue-habit-core-score (oqb-run 10 'miss)) :score))))

(ert-deftest oqb/a-three-a-week-habit-has-a-longer-half-life ()
  (should (> (org-queue-habit-core-factor (/ 3.0 7)) (org-queue-habit-core-factor 1))))

(ert-deftest oqb/the-series-is-built-from-ticks-over-the-days-the-habit-falls-on ()
  (let ((series (org-queue-habit-core-series
                 '(20260907 20260909) 20260907 20260913
                 (lambda (day) (/= 0 (mod (+ 4 (org-queue-habit-core--day-number day)) 7)))
                 '(20260910))))
    ;; Monday to Saturday, Sunday the 13th is not in it.
    (should (= 6 (length series)))
    (should (equal '(done miss done skip miss miss) (mapcar #'cdr series)))
    (should (eq 'two-misses (plist-get (org-queue-habit-core-score series) :alert)))))

(provide 'org-queue-habit-test)
;;; org-queue-habit-test.el ends here
