;;; org-queue-daylog-test.el --- ERT tests for the day-log core -*- lexical-binding: t -*-

;;; Commentary:

;; Hand-built plists, no Org.  Run with:
;;
;;   emacs -Q --batch -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-queue/test/org-queue-daylog-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'org-queue-daylog-core)

(defconst oqd-day 1788000000)           ; an arbitrary midnight, in seconds

(defun oqd-at (hh mm) (+ oqd-day (* 3600 hh) (* 60 mm)))

(defconst oqd-blocks
  '((:start 480 :end 720 :kind focus :label "block 1")
    (:start 720 :end 780 :kind fixed :label "bike")
    (:start 810 :end 900 :kind dip :label "dip")))

(ert-deftest oqd/events-are-ordered-by-time-across-sources ()
  (let* ((log (org-queue-daylog-core-assemble
               :intervals (list (list :start (oqd-at 9 0) :end (oqd-at 9 40)
                                      :title "a" :id "a" :state "PROG" :working t))
               :captures (list (list :time (oqd-at 9 20) :kind 'capture :title "jot"))
               :journal (list (list :time (oqd-at 8 30) :kind 'journal :title "line"))
               :blocks oqd-blocks :day-start oqd-day))
         (events (plist-get log :events)))
    (should (equal '(journal interval-start capture interval-end)
                   (mapcar (lambda (e) (plist-get e :kind)) events)))
    (should (= 40 (plist-get (nth 3 events) :minutes)))))

(ert-deftest oqd/ties-are-broken-by-kind-and-nothing-appears-twice ()
  (let* ((events (org-queue-daylog-core-sort
                  (list (list :time (oqd-at 9 0) :kind 'interval-start :title "b" :id "b")
                        (list :time (oqd-at 9 0) :kind 'interval-end :title "a" :id "a")
                        (list :time (oqd-at 9 0) :kind 'transition :title "b" :id "b")
                        (list :time (oqd-at 9 0) :kind 'transition :title "b" :id "b")))))
    (should (= 3 (length events)))
    (should (equal '(interval-end transition interval-start)
                   (mapcar (lambda (e) (plist-get e :kind)) events)))))

(ert-deftest oqd/a-forty-minute-gap-in-a-focus-block-is-reported-a-five-minute-one-is-not ()
  (let* ((intervals (list (list :start (oqd-at 8 0) :end (oqd-at 9 0) :id "a" :working t)
                          (list :start (oqd-at 9 40) :end (oqd-at 12 0) :id "b" :working t)))
         (gaps (org-queue-daylog-core-gaps oqd-blocks intervals oqd-day 15))
         (in-block-1 (cl-remove-if-not (lambda (g) (equal "block 1" (plist-get g :block))) gaps)))
    ;; The dip has nothing in it and is a gap of its own; block 1 has one.
    (should (= 2 (length gaps)))
    (should (= 1 (length in-block-1)))
    (should (= 40 (plist-get (car in-block-1) :minutes)))
    (let ((short (list (list :start (oqd-at 8 0) :end (oqd-at 9 0) :id "a" :working t)
                       (list :start (oqd-at 9 5) :end (oqd-at 12 0) :id "b" :working t)
                       (list :start (oqd-at 13 30) :end (oqd-at 15 0) :id "c" :working t))))
      (should-not (org-queue-daylog-core-gaps oqd-blocks short oqd-day 15)))))

(ert-deftest oqd/an-empty-block-is-one-gap-and-a-fixed-block-is-never-examined ()
  (let ((gaps (org-queue-daylog-core-gaps oqd-blocks nil oqd-day 15)))
    (should (equal '("block 1" "dip") (mapcar (lambda (g) (plist-get g :block)) gaps)))
    (should (= 240 (plist-get (car gaps) :minutes)))))

(ert-deftest oqd/a-block-still-running-is-examined-only-up-to-now ()
  (let ((gaps (org-queue-daylog-core-gaps oqd-blocks nil oqd-day 15 (oqd-at 8 30))))
    (should (= 1 (length gaps)))
    (should (= 30 (plist-get (car gaps) :minutes)))))

(ert-deftest oqd/a-capture-inside-an-interval-is-joined-by-time-and-the-property-wins ()
  (let* ((intervals (list (list :start (oqd-at 9 0) :end (oqd-at 10 0) :id "a" :working t)))
         (joined (org-queue-daylog-core-join-captures
                  (list (list :time (oqd-at 9 30) :kind 'capture :title "x")
                        (list :time (oqd-at 9 30) :kind 'capture :title "y" :interrupted "z")
                        (list :time (oqd-at 11 0) :kind 'capture :title "w"))
                  intervals)))
    (should (equal "a" (plist-get (nth 0 joined) :interrupted)))
    (should (plist-get (nth 0 joined) :joined-by-time))
    (should (equal "z" (plist-get (nth 1 joined) :interrupted)))
    (should-not (plist-get (nth 2 joined) :interrupted))))

(ert-deftest oqd/interruptions-are-counted-per-block-internal-against-external ()
  (let ((counts (org-queue-daylog-core-interruptions
                 (list (list :time (oqd-at 9 0) :kind 'capture)
                       (list :time (oqd-at 9 5) :kind 'capture :backlink "mu4e:x")
                       (list :time (oqd-at 14 0) :kind 'capture))
                 oqd-blocks oqd-day)))
    (should (equal '(:block "block 1" :internal 1 :external 1) (nth 0 counts)))
    (should (equal '(:block "dip" :internal 1 :external 0) (nth 2 counts)))))

(ert-deftest oqd/the-date-regexp-matches-both-forms-and-not-the-sloppy-one ()
  (should (string-match-p org-queue-daylog-date-regexp "on 2026-09-09 we"))
  (should (string-match-p org-queue-daylog-date-regexp "[[Sep 9th, 2026]]"))
  (should (string-match-p org-queue-daylog-date-regexp "Sep 21st, 2026"))
  (should-not (string-match-p org-queue-daylog-date-regexp "2026-09-9"))
  (should-not (string-match-p org-queue-daylog-date-regexp "Sep 9, 2026"))
  (should (= 20260909 (org-queue-daylog-core-parse-date "2026-09-09")))
  (should (= 20260909 (org-queue-daylog-core-parse-date "Sep 9th, 2026")))
  (should (= 20261231 (org-queue-daylog-core-parse-date "Dec 31st, 2026")))
  (should-not (org-queue-daylog-core-parse-date "Foo 9th, 2026")))

(provide 'org-queue-daylog-test)
;;; org-queue-daylog-test.el ends here
