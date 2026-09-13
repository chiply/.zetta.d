;;; org-queue-daylog-core.el --- Assemble a day's evidence in time order -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The day log is a merge: state transitions, the intervals they open
;; and close, captures, journal lines and (later) commits, in time order,
;; each once.  Then the gaps: stretches inside a focus block with nothing
;; in PROG, longer than a threshold, reported as untracked time.  No Org
;; in here; the shell that reads the files is `org-queue-daylog'.
;;
;; An event is a plist:
;;
;;   (:time SECONDS :kind KIND :title STRING :id ID :state STATE
;;    :minutes N :file FILE :point POINT :backlink STRING)
;;
;; KIND is one of `interval-start', `interval-end', `transition',
;; `capture', `journal', `commit'.  Times are epoch seconds.  Blocks are
;; plists with `:start' and `:end' as minutes since midnight and a
;; `:kind', as org-routine produces them; DAY-START anchors them.

;;; Code:

(require 'cl-lib)

(defcustom org-queue-daylog-gap-threshold 15
  "Minutes a stretch with nothing in PROG must last to be reported."
  :type 'integer
  :group 'org-queue)

(defconst org-queue-daylog-core--kind-order
  '(interval-end transition interval-start capture journal commit)
  "Tie-break order for events sharing a timestamp: an end before a start.")

(defconst org-queue-daylog-date-regexp
  (concat "\\(?:\\b[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\b"
          "\\|\\b\\(?:Jan\\|Feb\\|Mar\\|Apr\\|May\\|Jun\\|Jul\\|Aug\\|Sep\\|Oct\\|Nov\\|Dec\\)"
          " [0-9]\\{1,2\\}\\(?:st\\|nd\\|rd\\|th\\), [0-9]\\{4\\}\\b\\)")
  "Matches the two forms this kb writes a day in: ISO, and the journal form.
\"2026-09-9\" is not a date here; neither is \"Sep 9, 2026\".")

(defun org-queue-daylog-core-parse-date (text)
  "Return TEXT, in either form, as a YYYYMMDD integer, or nil."
  (cond
   ((string-match "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)\\'" text)
    (+ (* 10000 (string-to-number (match-string 1 text)))
       (* 100 (string-to-number (match-string 2 text)))
       (string-to-number (match-string 3 text))))
   ((string-match "\\`\\([A-Z][a-z][a-z]\\) \\([0-9]\\{1,2\\}\\)\\(?:st\\|nd\\|rd\\|th\\), \\([0-9]\\{4\\}\\)\\'"
                  text)
    (let ((month (cl-position (match-string 1 text)
                              '("Jan" "Feb" "Mar" "Apr" "May" "Jun"
                                "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
                              :test #'equal)))
      (when month
        (+ (* 10000 (string-to-number (match-string 3 text)))
           (* 100 (1+ month))
           (string-to-number (match-string 2 text))))))))

(defun org-queue-daylog-core-sort (events)
  "Return EVENTS sorted by time, ties broken by kind, each once."
  (let ((seen (make-hash-table :test #'equal))
        unique)
    (dolist (event events)
      (let ((key (list (plist-get event :time) (plist-get event :kind)
                       (plist-get event :id) (plist-get event :title))))
        (unless (gethash key seen)
          (puthash key t seen)
          (push event unique))))
    (sort unique
          (lambda (a b)
            (let ((ta (plist-get a :time)) (tb (plist-get b :time)))
              (if (/= ta tb)
                  (< ta tb)
                (< (or (cl-position (plist-get a :kind) org-queue-daylog-core--kind-order) 99)
                   (or (cl-position (plist-get b :kind) org-queue-daylog-core--kind-order) 99))))))))

(defun org-queue-daylog-core-interval-events (intervals)
  "Turn INTERVALS -- plists of :start :end :title :id :state -- into events.
One `interval-start' and one `interval-end' each; an open interval has
no end event."
  (let (events)
    (dolist (interval intervals)
      (push (list :time (plist-get interval :start) :kind 'interval-start
                  :title (plist-get interval :title) :id (plist-get interval :id)
                  :state (plist-get interval :state)
                  :file (plist-get interval :file) :point (plist-get interval :point))
            events)
      (when (and (plist-get interval :end) (not (plist-get interval :open)))
        (push (list :time (plist-get interval :end) :kind 'interval-end
                    :title (plist-get interval :title) :id (plist-get interval :id)
                    :state (plist-get interval :state)
                    :minutes (floor (- (plist-get interval :end) (plist-get interval :start)) 60)
                    :file (plist-get interval :file) :point (plist-get interval :point))
              events)))
    events))

(defun org-queue-daylog-core-join-captures (captures intervals)
  "Give each of CAPTURES an `:interrupted' from INTERVALS when it has none.
A capture whose time falls inside a working interval interrupted that
interval's entry; a property already on the capture wins."
  (mapcar (lambda (capture)
            (if (plist-get capture :interrupted)
                capture
              (let ((hit (cl-find-if
                          (lambda (interval)
                            (and (plist-get interval :working)
                                 (<= (plist-get interval :start) (plist-get capture :time))
                                 (< (plist-get capture :time)
                                    (or (plist-get interval :end) most-positive-fixnum))))
                          intervals)))
                (if hit
                    (append (list :interrupted (plist-get hit :id) :joined-by-time t) capture)
                  capture))))
          captures))

(defun org-queue-daylog-core-gaps (blocks intervals day-start &optional threshold now)
  "Return the stretches inside working BLOCKS with nothing in PROG.

BLOCKS are routine blocks (minutes since midnight, with `:kind');
only focus and dip blocks are examined.  INTERVALS are the day's
working intervals in epoch seconds.  DAY-START is midnight in epoch
seconds.  Stretches shorter than THRESHOLD minutes are not reported;
a block still running at NOW is examined only up to NOW."
  (let ((threshold (or threshold org-queue-daylog-gap-threshold))
        gaps)
    (dolist (block blocks)
      (when (memq (plist-get block :kind) '(focus dip))
        (let* ((start (+ day-start (* 60 (plist-get block :start))))
               (end (+ day-start (* 60 (plist-get block :end))))
               (end (if now (min end now) end))
               (busy (sort (mapcar (lambda (interval)
                                     (cons (plist-get interval :start)
                                           (or (plist-get interval :end) most-positive-fixnum)))
                                   (cl-remove-if-not (lambda (i) (plist-get i :working)) intervals))
                           (lambda (a b) (< (car a) (car b)))))
               (cursor start))
          (dolist (span busy)
            (when (and (> (car span) cursor) (< cursor end))
              (let ((gap-end (min (car span) end)))
                (when (>= (- gap-end cursor) (* 60 threshold))
                  (push (list :start cursor :end gap-end
                              :minutes (floor (- gap-end cursor) 60)
                              :block (plist-get block :label))
                        gaps))))
            (setq cursor (max cursor (cdr span))))
          (when (and (< cursor end) (>= (- end cursor) (* 60 threshold)))
            (push (list :start cursor :end end :minutes (floor (- end cursor) 60)
                        :block (plist-get block :label))
                  gaps)))))
    (nreverse gaps)))

(defun org-queue-daylog-core-interruptions (captures blocks day-start)
  "Count CAPTURES per block: internal (no backlink) and external (with one).
Returns a list of (:block LABEL :internal N :external N)."
  (mapcar (lambda (block)
            (let* ((start (+ day-start (* 60 (plist-get block :start))))
                   (end (+ day-start (* 60 (plist-get block :end))))
                   (inside (cl-remove-if-not
                            (lambda (capture)
                              (and (<= start (plist-get capture :time))
                                   (< (plist-get capture :time) end)))
                            captures)))
              (list :block (plist-get block :label)
                    :internal (cl-count-if-not (lambda (c) (plist-get c :backlink)) inside)
                    :external (cl-count-if (lambda (c) (plist-get c :backlink)) inside))))
          blocks))

(cl-defun org-queue-daylog-core-assemble (&key intervals captures journal commits
                                              blocks day-start threshold now)
  "Assemble the day log.

INTERVALS, CAPTURES, JOURNAL and COMMITS are as documented above;
BLOCKS and DAY-START describe the routine.  Returns a plist:

  :events         every event, sorted, once
  :gaps           untracked stretches inside working blocks
  :interruptions  captures per block, internal against external"
  (let* ((captures (org-queue-daylog-core-join-captures captures intervals))
         (events (org-queue-daylog-core-sort
                  (append (org-queue-daylog-core-interval-events intervals)
                          captures journal commits))))
    (list :events events
          :gaps (org-queue-daylog-core-gaps blocks intervals day-start threshold now)
          :interruptions (org-queue-daylog-core-interruptions captures blocks day-start))))

(provide 'org-queue-daylog-core)
;;; org-queue-daylog-core.el ends here
