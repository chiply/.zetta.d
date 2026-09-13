;;; org-queue-close-core.el --- Close the day, arithmetic only -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The close is a pure function of (corpus, today's plan, history, date).
;; It says what was planned and not finished (carried, with how many
;; times), what finished (once each, whether planned or not), what is
;; overdue and what is due tomorrow, what is still in PROG, what
;; tomorrow's routine holds, and a draft of tomorrow from the same packer
;; the morning uses -- so the draft respects tomorrow's capacity, not
;; today's.  It never mutates its inputs.  The buffer, the keys, the
;; history stamp and the phrase live in `org-queue-close'.

;;; Code:

(require 'cl-lib)
(require 'org-queue-core)

(defcustom org-queue-pick-limit 3
  "How many NEXT picks a day may carry.
The third `N' in the close is refused with this rule: the composite's
daily focus set is three, and a limit that never binds is not one."
  :type 'integer
  :group 'org-queue)

(defcustom org-queue-close-phrase "Schedule shutdown, complete."
  "Printed when the day is closed.  Printed, never asked."
  :type 'string
  :group 'org-queue)

(defun org-queue-close-core--done-today-p (task today)
  "Return non-nil if TASK finished on TODAY.
A CLOSED stamp on TODAY, or a last transition into a done state on
TODAY; both describe the same event, so a task counts once."
  (and (org-queue-core-done-p task)
       (or (eql (plist-get task :closed) today)
           (let ((last (plist-get task :last-transition)))
             (and last
                  (member (car last) org-queue-done-states)
                  (eql (cdr last) today))))))

(defun org-queue-close-core-carried-count (id history today)
  "Return how many plans before or on TODAY carried ID, from HISTORY.
HISTORY is the queue's plan history: plists of `:date' and `:ids'."
  (cl-count-if (lambda (entry)
                 (and (<= (plist-get entry :date) today)
                      (member id (plist-get entry :ids))))
               history))

(defun org-queue-close-core-pick-allowed-p (tasks &optional limit)
  "Return non-nil if another NEXT pick fits under LIMIT over TASKS."
  (< (cl-count-if (lambda (task)
                    (and (equal (plist-get task :state) "NEXT")
                         (not (org-queue-core-done-p task))))
                  tasks)
     (or limit org-queue-pick-limit)))

(cl-defun org-queue-close-core (tasks today &key plan-ids history inbox-count
                                      routine-tomorrow interruptions chains
                                      closed)
  "Close TODAY over TASKS.

PLAN-IDS are the IDs on today's plan; HISTORY the plan history;
INBOX-COUNT the captures not yet processed; ROUTINE-TOMORROW the fixed
rows tomorrow holds (strings); INTERRUPTIONS an alist of (ID . COUNT)
of captures made while each entry was in PROG; CHAINS a list of plists
\(:task :prompt) for entries in flight; CLOSED the stamp of an earlier
close of TODAY, or nil.

Returns a plist:

  :date :tomorrow      YYYYMMDD
  :already-closed      CLOSED, when the day was closed before
  :unfinished          planned, still open; each annotated `:carried-count'
  :done                finished today, planned or not; `:unplanned' set
                       on the ones the plan did not hold
  :overdue             open, hard deadline on or before today
  :due-tomorrow        open, due tomorrow, or soft deadline by tomorrow
  :prog                still in PROG, annotated `:interruptions'
  :appointments        appointments tomorrow
  :routine-tomorrow    ROUTINE-TOMORROW, as given
  :inbox-count         as given
  :chains              CHAINS split into `:primed' and `:unprimed'
  :draft               `org-queue-core-plan' for tomorrow over the open tasks
  :phrase              `org-queue-close-phrase'

Every planned task ends the close in exactly one of :done, :unfinished,
or -- when it left the corpus -- nowhere, which is reported in :missing."
  (let* ((tomorrow (org-queue-core-date-add today 1))
         (by-id (make-hash-table :test #'equal))
         done unfinished missing overdue due-tomorrow prog appointments)
    (dolist (task tasks)
      (when (plist-get task :id) (puthash (plist-get task :id) task by-id)))
    (dolist (task tasks)
      (cond
       ((org-queue-close-core--done-today-p task today)
        (push (org-queue-core--annotate
               task :unplanned (not (member (plist-get task :id) plan-ids)))
              done))
       ((org-queue-core-done-p task) nil)
       ((org-queue-core-habit-p task) nil)
       (t
        (when (equal (plist-get task :state) "PROG")
          (push (org-queue-core--annotate
                 task :interruptions
                 (or (alist-get (plist-get task :id) interruptions 0 nil #'equal) 0))
                prog))
        (let ((deadline (plist-get task :deadline))
              (soft (plist-get task :deadline-soft)))
          (cond
           ((and deadline (<= deadline today) (not soft)) (push task overdue))
           ((and deadline (or (= deadline tomorrow)
                              (and soft (<= deadline tomorrow))))
            (push task due-tomorrow))))
        (when (eql (plist-get task :timestamp) tomorrow)
          (push task appointments)))))
    (dolist (id plan-ids)
      (let ((task (gethash id by-id)))
        (cond
         ((null task) (push id missing))
         ((org-queue-close-core--done-today-p task today) nil)
         ((org-queue-core-done-p task) nil)
         (t (push (org-queue-core--annotate
                   task :carried-count
                   (org-queue-close-core-carried-count id history today))
                  unfinished)))))
    (let* ((open (cl-remove-if (lambda (task)
                                 (or (org-queue-core-done-p task)
                                     (equal (plist-get task :state) "PROG")))
                               tasks))
           ;; PROG entries are tomorrow's first commitments whatever the
           ;; packer thinks; the sweep is what decides otherwise.
           (draft (org-queue-core-plan
                   (append (cl-remove-if-not
                            (lambda (task) (equal (plist-get task :state) "PROG"))
                            tasks)
                           open)
                   tomorrow)))
      (list :date today
            :tomorrow tomorrow
            :already-closed closed
            :unfinished (nreverse unfinished)
            :missing (nreverse missing)
            :done (nreverse done)
            :overdue (sort overdue (lambda (a b) (< (plist-get a :deadline)
                                                    (plist-get b :deadline))))
            :due-tomorrow (nreverse due-tomorrow)
            :prog (nreverse prog)
            :appointments (nreverse appointments)
            :routine-tomorrow routine-tomorrow
            :inbox-count (or inbox-count 0)
            :chains (list :primed (cl-remove-if-not (lambda (c) (plist-get c :prompt)) chains)
                          :unprimed (cl-remove-if (lambda (c) (plist-get c :prompt)) chains))
            :draft draft
            :phrase org-queue-close-phrase))))

(defun org-queue-close-core-summary (close)
  "Return a one-line summary of CLOSE."
  (format "%d done, %d carried, %d overdue, %d in PROG, %d in the inbox; tomorrow %s"
          (length (plist-get close :done))
          (length (plist-get close :unfinished))
          (length (plist-get close :overdue))
          (length (plist-get close :prog))
          (plist-get close :inbox-count)
          (org-queue-core-summary (plist-get close :draft))))

(provide 'org-queue-close-core)
;;; org-queue-close-core.el ends here
