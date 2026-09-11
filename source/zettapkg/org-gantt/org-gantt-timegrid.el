;;; org-gantt-timegrid.el --- The derived clock as an org-timegrid week -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org-timegrid "0.1.0"))
;; Keywords: convenience, calendar

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; The same rows the Gantt draws, seen as a week instead of as a
;; timeline -- because the two questions are different.  The Gantt asks
;; how long a task was open; the grid asks where a Tuesday went.
;;
;; This is a BACKEND, not a fork.  `org-timegrid' takes its events from
;; a struct of functions (`org-timegrid-backend-create' in
;; org-timegrid-model.el, a file with no Org in it), and every mutation
;; function may be nil.  So a read-only source of derived events is
;; about a hundred lines and inherits the whole renderer: the SVG, the
;; cursor, isearch, the theme handling and the day/week navigation.
;;
;; THREE VIEWS, ONE BACKEND SHAPE:
;;
;;   spent      working intervals, clipped to `org-gantt-window'
;;   planned    the queue's committed days and SCHEDULED stamps
;;   composite  both at once, which is the one worth opening
;;
;; The composite draws plan and actual in the SAME day column and lets
;; the renderer's own overlap lanes put them side by side, so the
;; comparison happens where the eye already is rather than across a
;; window edge.  What tells them apart is the ink: the plan sits at the
;; bottom of the prominence ladder and carries a marker in its title,
;; the actual sits at the top.  Position cannot carry that distinction,
;; because lanes are assigned by overlap and a third block moves the
;; other two.
;;
;; WHY THE GRID CLIPS AND THE GANTT DOES NOT.  A PROG left open
;; overnight is eighteen hours of wall time.  Drawn raw on a week grid
;; that is a solid column through the night, which is a lie about the
;; day; drawn raw on a Gantt it is the truth about the task.  So the
;; grid reads `:clipped' and the Gantt reads `:segments', and neither
;; number is a correction of the other.  See `org-gantt-core'.

;;; Code:

(require 'cl-lib)
(require 'calendar)
(require 'org-timegrid-model)
(require 'org-gantt-core)
(require 'org-gantt-harvest)

(declare-function org-timegrid-open "org-timegrid" (backend &optional absolute-date))
(defvar org-timegrid-buffer-name)
(defvar org-timegrid-data-refresh-seconds)

(defcustom org-gantt-timegrid-rungs
  '((working . red)
    (waiting . brown)
    (queue . teal)
    (schedule . graphite))
  "Which `org-timegrid-colors' name each kind of block is drawn in.

Names, not colours: the config maps every name to a rung on the ink
ladder (see `zetta-org-timegrid-palette-rungs'), so what survives a
theme change is prominence.  Work is loudest, waiting a rung down, and
both plan kinds sit at the quiet end where an outline would be if the
renderer drew outlines."
  :type '(alist :key-type symbol :value-type symbol)
  :group 'org-gantt)

(defcustom org-gantt-timegrid-plan-prefix "▫ "
  "Marker put in front of a planned block's title.

Belt and braces with the rung: two blocks in one column need to be
told apart at a glance, and a marker in the title survives a theme
that flattens the ladder."
  :type 'string :group 'org-gantt)

(defcustom org-gantt-timegrid-stale-prefix "⋯ "
  "Marker put in front of a block derived from a still-open PROG.

An entry left in PROG on Monday accrues every working hour since, so
one forgotten transition can fill three days of the grid.  That is the
honest reading and the grid keeps it -- but it says which blocks are
the accrual, so a full week is read as a missing transition rather
than as a heroic Tuesday."
  :type 'string :group 'org-gantt)

(defcustom org-gantt-timegrid-refresh-seconds 900
  "How often a derived grid re-reads the files.

Longer than org-timegrid's own 300: every refresh is an org-ql query
across the corpus plus a LOGBOOK parse per hit, and a grid of
yesterday's work does not go stale in five minutes."
  :type 'integer :group 'org-gantt)


;;;; Units

;; org-timegrid counts in minutes since the Gregorian epoch that
;; `calendar-absolute-from-gregorian' defines; the core counts in epoch
;; seconds.  The conversion pair lives in the core, where it is a round
;; trip a batch test can drive; these are the names this file reads by.

(defalias 'org-gantt-timegrid--to-minutes #'org-gantt-core-day-minutes)
(defalias 'org-gantt-timegrid--to-seconds #'org-gantt-core-from-day-minutes)


;;;; Events

(defun org-gantt-timegrid--event (row kind start end index)
  "Return one org-timegrid event for ROW's KIND block from START to END."
  (org-timegrid-event-create
   :id (format "%s/%s/%d" (plist-get row :id) kind index)
   :title (concat (when (memq kind '(queue schedule)) org-gantt-timegrid-plan-prefix)
                  (when (and (plist-get row :stale)
                             (memq kind '(working waiting)))
                    org-gantt-timegrid-stale-prefix)
                  (or (plist-get row :title) "?"))
   :start (org-gantt-timegrid--to-minutes start)
   :end (org-gantt-timegrid--to-minutes end)
   :all-day nil
   :tags (cons (symbol-name kind) (plist-get row :tags))
   :state nil
   :color (or (cdr (assq kind org-gantt-timegrid-rungs)) 'graphite)
   :source (plist-get row :marker)
   :metadata (list :kind kind
                   :category (plist-get row :category)
                   :effort (plist-get row :effort))))

(defun org-gantt-timegrid--rows (from to)
  "Return measured, placed rows across FROM..TO in epoch seconds."
  (let* ((now (floor (float-time)))
         (rows (org-gantt-harvest :from from :to to :now now
                                  :query org-gantt-query)))
    (org-gantt-core-place-plans (org-gantt-core-summarize rows now))))

(defun org-gantt-timegrid--events (from to kinds)
  "Return events between absolute minutes FROM and TO for KINDS."
  (let* ((start (org-gantt-timegrid--to-seconds from))
         (end (org-gantt-timegrid--to-seconds to))
         (rows (org-gantt-timegrid--rows start end))
         events)
    (dolist (row rows)
      (let ((index 0))
        ;; Actuals come from `:clipped', never from `:segments': the grid
        ;; must not paint the night.
        (when (memq 'actual kinds)
          (dolist (segment (plist-get row :clipped))
            (when (memq (plist-get segment :class) '(working waiting))
              (push (org-gantt-timegrid--event
                     row (plist-get segment :class)
                     (plist-get segment :start) (plist-get segment :end)
                     (cl-incf index))
                    events))))
        (when (memq 'plan kinds)
          (dolist (plan (plist-get row :plans))
            (when (and (plist-get plan :start) (plist-get plan :end))
              (push (org-gantt-timegrid--event
                     row (or (plist-get plan :kind) 'schedule)
                     (plist-get plan :start) (plist-get plan :end)
                     (cl-incf index))
                    events))))))
    (nreverse events)))

(defun org-gantt-timegrid--visit (event)
  "Jump to the entry EVENT was derived from."
  (if-let* ((marker (org-timegrid-event-source event))
            (buffer (and (markerp marker) (marker-buffer marker))))
      (progn (pop-to-buffer buffer)
             (goto-char marker)
             (org-fold-show-context 'org-goto))
    (message "This block has no entry to visit")))


;;;; Backends

;; Every mutation slot is left nil, and that is a decision rather than
;; an omission.  These blocks are DERIVED: dragging one would have to
;; rewrite a LOGBOOK stamp to move the work that happened, which is
;; falsifying the record, and the renderer already refuses gracefully
;; ("This backend cannot move or resize calendar entries").  Time
;; blocking stays where it belongs, on the writable Org grid.

(defun org-gantt-timegrid-backend (name kinds)
  "Return a read-only org-timegrid backend called NAME listing KINDS."
  (org-timegrid-backend-create
   :name name
   :list-function (lambda (from to) (org-gantt-timegrid--events from to kinds))
   :visit-function #'org-gantt-timegrid--visit))

(defun org-gantt-timegrid--open (name kinds)
  "Open a derived grid called NAME showing KINDS in its own buffer."
  (require 'org-timegrid)
  (let ((org-timegrid-buffer-name (format "*Time %s*" name))
        (org-timegrid-data-refresh-seconds org-gantt-timegrid-refresh-seconds))
    (org-timegrid-open (org-gantt-timegrid-backend name kinds))))

;;;###autoload
(defun org-gantt-timegrid-spent ()
  "Open a week grid of the time actually spent."
  (interactive)
  (org-gantt-timegrid--open "spent" '(actual)))

;;;###autoload
(defun org-gantt-timegrid-planned ()
  "Open a week grid of what was planned."
  (interactive)
  (org-gantt-timegrid--open "planned" '(plan)))

;;;###autoload
(defun org-gantt-timegrid-composite ()
  "Open a week grid of the plan and the actual, side by side in each day."
  (interactive)
  (org-gantt-timegrid--open "planned vs spent" '(plan actual)))

(provide 'org-gantt-timegrid)
;;; org-gantt-timegrid.el ends here
