;;; org-queue-season-core.el --- Horizons: the season, its missions, the orphans -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Above the week: a theme, one sentence, and at most three missions a
;; season.  A project serves a mission by carrying `:MISSION:' (the
;; mission's ID), inherited by its children; open work that reaches no
;; mission is an orphan.  No Org in here: the season's name from a
;; date, the check that refuses a fourth mission, the orphans, the
;; missions with no rock this week, the ones whose every project is
;; done, and whether a theme has gone stale.

;;; Code:

(require 'cl-lib)
(require 'org-queue-core)

(defcustom org-queue-mission-limit 3
  "How many missions a season may hold.  A fourth is refused with the rule."
  :type 'integer
  :group 'org-queue)

(defcustom org-queue-season-days 90
  "Days after which a theme is reported stale."
  :type 'integer
  :group 'org-queue)

(defun org-queue-season-core-name (date)
  "Return the season DATE, a YYYYMMDD integer, falls in: \"2026-Q3\"."
  (format "%d-Q%d" (/ date 10000) (1+ (/ (1- (% (/ date 100) 100)) 3))))

(defun org-queue-season-core-check (missions season)
  "Return nil when MISSIONS fit SEASON, else the refusal naming them.
MISSIONS are plists with `:title' and `:season'; a mission with no
season belongs to SEASON."
  (let ((active (cl-remove-if-not
                 (lambda (mission) (member (plist-get mission :season) (list nil season)))
                 missions)))
    (when (> (length active) org-queue-mission-limit)
      (format "%d missions in %s; the season holds %d: %s"
              (length active) season org-queue-mission-limit
              (mapconcat (lambda (m) (plist-get m :title)) active ", ")))))

(defun org-queue-season-core-orphans (tasks)
  "Return the open commitments in TASKS that reach no mission.
TODO, NEXT and PROG only: parked work is not an orphan, it is parked."
  (cl-remove-if-not
   (lambda (task)
     (and (member (plist-get task :state) '("TODO" "NEXT" "PROG"))
          (not (org-queue-core-habit-p task))
          (null (plist-get task :mission))))
   tasks))

(defun org-queue-season-core-rockless (missions tasks today &optional days)
  "Return the MISSIONS with no rock in the last DAYS: no NEXT, scheduled or PROG task.
A rock is a task serving the mission that is NEXT, in PROG, or
scheduled within the window."
  (let ((days (or days 7)))
    (cl-remove-if
     (lambda (mission)
       (cl-some (lambda (task)
                  (and (equal (plist-get task :mission) (plist-get mission :id))
                       (not (org-queue-core-done-p task))
                       (or (member (plist-get task :state) '("NEXT" "PROG"))
                           (and (plist-get task :scheduled)
                                (<= (abs (org-queue-core-days-between
                                          (plist-get task :scheduled) today))
                                    days)))))
                tasks))
     missions)))

(defun org-queue-season-core-finished (missions tasks)
  "Return the MISSIONS whose every linked task is done, and that have some."
  (cl-remove-if-not
   (lambda (mission)
     (let ((linked (cl-remove-if-not
                    (lambda (task) (equal (plist-get task :mission) (plist-get mission :id)))
                    tasks)))
       (and linked (cl-every #'org-queue-core-done-p linked))))
   missions))

(defun org-queue-season-core-stale-p (theme-date today &optional days)
  "Return non-nil if a theme written on THEME-DATE is older than DAYS on TODAY."
  (and theme-date
       (> (org-queue-core-days-between theme-date today) (or days org-queue-season-days))))

(provide 'org-queue-season-core)
;;; org-queue-season-core.el ends here
