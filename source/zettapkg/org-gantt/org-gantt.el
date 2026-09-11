;;; org-gantt.el --- A Gantt chart and clock table over Org state transitions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org-ql "0.8") (org-queue "0.1.0"))
;; Keywords: convenience, calendar
;; URL: https://github.com/chiply/org-gantt

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; What happened, drawn against what was planned, from data you already
;; write down.  Nothing here clocks: time is the interval between two
;; TODO state transitions, both of them already stamped into the LOGBOOK
;; by the `!' and `@' flags in `org-todo-keywords'.
;;
;; `M-x org-gantt' opens the chart on the last week.  The chart is one
;; SVG; under it is the table it was drawn from, line for line, and TAB
;; on a row opens the transitions that produced its bar.  That pairing is
;; the point: a bar whose numbers you cannot read is a decoration, and a
;; number you cannot see the shape of is a spreadsheet.
;;
;; The parts:
;;
;;   org-gantt-core      the arithmetic; no Org, no SVG, tested in batch
;;   org-gantt-harvest   org-ql and the LOGBOOK in, rows out
;;   org-gantt-svg       rows in, an image out
;;   org-gantt-timegrid  the same rows as a week grid, through org-timegrid
;;   org-gantt           this file: the buffer, the keys, the table
;;
;; See the README for the seams, and `org-gantt-core' for what a row is.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-gantt-core)
(require 'org-gantt-harvest)
(require 'org-gantt-svg)

(defcustom org-gantt-buffer-name "*Org Gantt*"
  "Name of the chart buffer."
  :type 'string :group 'org-gantt)

(defcustom org-gantt-default-days 7
  "Days the chart covers when it opens."
  :type 'integer :group 'org-gantt)

(defcustom org-gantt-group-by :category
  "Row property rows are gathered under, or nil for one flat list.

`:category' by default, because `#+CATEGORY' is already per-file in
this corpus and so the grouping costs nothing to maintain."
  :type '(choice (const :tag "Category" :category)
                 (const :tag "File" :file)
                 (const :tag "State" :state)
                 (const :tag "Flat" nil))
  :group 'org-gantt)

(defvar-local org-gantt--query nil)
(defvar-local org-gantt--from nil)
(defvar-local org-gantt--to nil)
(defvar-local org-gantt--now nil)
(defvar-local org-gantt--group nil)
(defvar-local org-gantt--chart nil)
(defvar-local org-gantt--lines nil)
(defvar-local org-gantt--cursor 0)
(defvar-local org-gantt--expanded nil
  "Ids whose transitions are shown under their table line.")
(defvar-local org-gantt--show-table t)


;;;; Faces used by the table

(defface org-gantt-table-header
  '((t :inherit default :weight bold))
  "The table's column headings."
  :group 'org-gantt)

(defface org-gantt-transition
  '((t :inherit shadow))
  "One state transition, under an expanded row."
  :group 'org-gantt)


;;;; Drawing

(defun org-gantt--refresh (&optional keep-point)
  "Rebuild the chart from the files and redraw the buffer.
With KEEP-POINT, leave point where it is instead of following the cursor."
  (let* ((now (or org-gantt--now (floor (float-time))))
         (rows (org-gantt-harvest :query org-gantt--query
                                  :from org-gantt--from
                                  :to org-gantt--to
                                  :now now)))
    (setq org-gantt--chart (org-gantt-core-chart rows org-gantt--from org-gantt--to
                                                 :now now
                                                 :group org-gantt--group)
          org-gantt--lines (org-gantt-core-lines org-gantt--chart))
    (setq org-gantt--cursor
          (max 0 (min org-gantt--cursor (1- (max 1 (length org-gantt--lines))))))
    (org-gantt--draw keep-point)))

(defun org-gantt--draw (&optional keep-point)
  "Redraw the buffer from the chart already computed."
  (let ((inhibit-read-only t)
        (position (point)))
    (erase-buffer)
    (setq header-line-format (org-gantt--header))
    ;; `insert-image' on a frame that cannot show one silently inserts a
    ;; space, so a terminal frame or an Emacs built without librsvg looks
    ;; exactly like a chart that failed to draw.  Say which it is.
    (if (org-gantt--can-draw-p)
        (insert-image (org-gantt-svg-render
                       org-gantt--chart
                       :width (max 400 (- (window-body-width nil t) 24))
                       :lines org-gantt--lines
                       :cursor org-gantt--cursor))
      (insert (propertize
               (if (display-graphic-p)
                   " The chart needs SVG support, which this Emacs was built without.\n The table below is the same data.\n"
                 " The chart needs a graphical frame; this one is a terminal.\n The table below is the same data.\n")
               'face 'org-gantt-table-header)))
    (insert "\n")
    (when org-gantt--show-table
      (insert "\n")
      (org-gantt--insert-table))
    (goto-char (if keep-point position (org-gantt--cursor-position)))))

(defun org-gantt--can-draw-p ()
  "Return non-nil when this frame can display the chart image."
  (and (display-graphic-p) (image-type-available-p 'svg)))

(defun org-gantt--header ()
  "Return the header line: what is drawn, over what, measured how."
  (let* ((totals (plist-get org-gantt--chart :totals))
         (provisional (plist-get totals :provisional)))
    (concat
     (format " %s  %s→%s  "
             (propertize (format "%s" (or org-gantt--query org-gantt-query))
                         'face 'org-gantt-table-header)
             (format-time-string "%-d %b" org-gantt--from)
             (format-time-string "%-d %b" org-gantt--to))
     (format "worked %s" (org-gantt-core-format-minutes (plist-get totals :worked)))
     (when (and provisional (> provisional 0))
       (format " (%s still open)" (org-gantt-core-format-minutes provisional)))
     (when (plist-get totals :effort)
       (format " · est %s" (org-gantt-core-format-minutes (plist-get totals :effort))))
     (format " · %d rows · overlap %s" (plist-get totals :count) org-gantt-overlap))))


;;;; The table under the chart

(defun org-gantt--insert-table ()
  "Insert the table the chart was drawn from, one line per chart line."
  (insert (propertize
           (format " %-6s %-44s %12s %6s %7s %5s\n"
                   "state" "task" "worked/est" "ratio" "open" "×")
           'face 'org-gantt-table-header))
  (cl-loop
   for line in org-gantt--lines
   for index from 0
   do (let ((start (point)))
        (pcase (plist-get line :kind)
          ('group
           (let ((group (plist-get line :group)))
             (insert (propertize
                      (format " %-51s %12s %6s %7s %5s\n"
                              (format "%s (%d)" (plist-get group :name)
                                      (plist-get group :count))
                              (concat (org-gantt-core-format-minutes
                                       (plist-get group :worked))
                                      (when (plist-get group :effort)
                                        (concat "/" (org-gantt-core-format-minutes
                                                     (plist-get group :effort))))
                                      (if (> (or (plist-get group :provisional) 0) 0)
                                          "~" ""))
                              (if (plist-get group :ratio)
                                  (format "%.2f" (plist-get group :ratio)) "")
                              (org-gantt-core-format-span (plist-get group :elapsed))
                              "")
                      'face 'org-gantt-group))))
          ('row
           (let* ((row (plist-get line :row))
                  (ratio (plist-get row :ratio)))
             (insert
              (format " %-6s %-44s %12s %6s %7s %5s\n"
                      (or (plist-get row :state) "")
                      (truncate-string-to-width (or (plist-get row :title) "?") 44)
                      (concat (org-gantt-core-format-minutes (plist-get row :worked))
                              (when (plist-get row :effort)
                                (concat "/" (org-gantt-core-format-minutes
                                             (plist-get row :effort))))
                              (if (plist-get row :provisional) "~" ""))
                      (if ratio (format "%.2f" ratio) "")
                      (org-gantt-core-format-span (plist-get row :lifetime))
                      (if (> (plist-get row :sessions) 0)
                          (number-to-string (plist-get row :sessions)) "")))
             (when (member (plist-get row :id) org-gantt--expanded)
               (org-gantt--insert-transitions row)))))
        (put-text-property start (point) 'org-gantt-line index)
        (when (eq index org-gantt--cursor)
          (add-face-text-property start (point) 'org-gantt-cursor t)))))

(defun org-gantt--insert-transitions (row)
  "Insert ROW's transitions, one line each: the evidence under the bar.

Every interval, not only the drawn ones.  A row that was finished this
week has no bar -- its one transition was into DONE, which the chart
correctly does not draw -- and TAB on it must still show why it is
here, or the expansion looks broken exactly where the reader is most
suspicious."
  (dolist (interval (plist-get row :intervals))
    (let* ((class (org-gantt-core-class (plist-get interval :state)))
           (terminal (eq class 'done)))
      (insert (propertize
               (format "        %-6s %s %s   %8s  %s\n"
                       (or (plist-get interval :state) "")
                       (format-time-string "%a %-d %b %H:%M" (plist-get interval :start))
                       (cond (terminal "            ")
                             ((plist-get interval :open) "→ now         ")
                             (t (format-time-string "→ %a %-d %b %H:%M"
                                                    (plist-get interval :end))))
                       (if terminal
                           ""
                         (org-gantt-core-format-minutes
                          (org-gantt-core-minutes (plist-get interval :start)
                                                  (plist-get interval :end))))
                       (pcase class
                         ('working (if (plist-get interval :open) "worked, open" "worked"))
                         ('waiting "blocked")
                         ('done "closed")
                         (_ "idle")))
               'face 'org-gantt-transition))))
  (when-let* ((plans (cl-remove-if-not (lambda (plan) (plist-get plan :start))
                                       (plist-get row :plans))))
    (dolist (plan plans)
      (insert (propertize
               (format "        %-6s %s → %s   %8s  %s\n"
                       (if (eq (plist-get plan :kind) 'queue) "plan" "sched")
                       (format-time-string "%a %-d %b %H:%M" (plist-get plan :start))
                       (format-time-string "%a %-d %b %H:%M" (plist-get plan :end))
                       (org-gantt-core-format-minutes
                        (org-gantt-core-minutes (plist-get plan :start)
                                                (plist-get plan :end)))
                       (if (plist-get plan :placed) "placed in the day" "fixed"))
               'face 'org-gantt-transition)))))

(defun org-gantt--cursor-position ()
  "Return the buffer position of the cursor's table line."
  (or (save-excursion
        (goto-char (point-min))
        (let (found)
          (while (and (not found) (not (eobp)))
            (when (eq (get-text-property (point) 'org-gantt-line) org-gantt--cursor)
              (setq found (point)))
            (forward-line 1))
          found))
      (point-min)))

(defun org-gantt--row-at-point ()
  "Return the row the cursor is on, or nil for a group line."
  (let ((line (nth org-gantt--cursor org-gantt--lines)))
    (and (eq (plist-get line :kind) 'row) (plist-get line :row))))


;;;; Commands

(defun org-gantt-next-line (&optional count)
  "Move the cursor down COUNT lines."
  (interactive "p")
  (setq org-gantt--cursor
        (max 0 (min (1- (length org-gantt--lines))
                    (+ org-gantt--cursor (or count 1)))))
  (org-gantt--draw))

(defun org-gantt-previous-line (&optional count)
  "Move the cursor up COUNT lines."
  (interactive "p")
  (org-gantt-next-line (- (or count 1))))

(defun org-gantt-refresh ()
  "Re-read the files and redraw."
  (interactive)
  (org-gantt--refresh))

(defun org-gantt-toggle-transitions ()
  "Show or hide the transitions that produced the current row's bar."
  (interactive)
  (if-let* ((row (org-gantt--row-at-point))
            (id (plist-get row :id)))
      (progn
        (setq org-gantt--expanded
              (if (member id org-gantt--expanded)
                  (delete id org-gantt--expanded)
                (cons id org-gantt--expanded)))
        (org-gantt--draw))
    (user-error "No task on this line")))

(defun org-gantt-visit ()
  "Visit the entry the cursor is on."
  (interactive)
  (if-let* ((row (org-gantt--row-at-point))
            (marker (plist-get row :marker))
            (buffer (marker-buffer marker)))
      (progn (pop-to-buffer buffer)
             (goto-char marker)
             (org-fold-show-context 'org-goto))
    (user-error "No task on this line")))

(defun org-gantt-shift (days)
  "Move the charted range DAYS days, keeping its length."
  (interactive "p")
  (let ((step (* days 60 60 24)))
    (setq org-gantt--from (+ org-gantt--from step)
          org-gantt--to (+ org-gantt--to step)))
  (org-gantt--refresh))

(defun org-gantt-forward ()
  "Move the range forward by its own length."
  (interactive)
  (let ((span (- org-gantt--to org-gantt--from)))
    (setq org-gantt--from (+ org-gantt--from span)
          org-gantt--to (+ org-gantt--to span)))
  (org-gantt--refresh))

(defun org-gantt-backward ()
  "Move the range back by its own length."
  (interactive)
  (let ((span (- org-gantt--to org-gantt--from)))
    (setq org-gantt--from (- org-gantt--from span)
          org-gantt--to (- org-gantt--to span)))
  (org-gantt--refresh))

(defun org-gantt-widen ()
  "Double the charted range, keeping its right edge."
  (interactive)
  (setq org-gantt--from (- org-gantt--to (* 2 (- org-gantt--to org-gantt--from))))
  (org-gantt--refresh))

(defun org-gantt-narrow ()
  "Halve the charted range, keeping its right edge."
  (interactive)
  (let ((span (max (* 60 60 6) (/ (- org-gantt--to org-gantt--from) 2))))
    (setq org-gantt--from (- org-gantt--to span)))
  (org-gantt--refresh))

(defun org-gantt-set-range (days)
  "Chart the last DAYS days."
  (interactive "nDays: ")
  (setq org-gantt--to (or org-gantt--now (floor (float-time)))
        org-gantt--from (- org-gantt--to (* days 60 60 24)))
  (org-gantt--refresh))

(defun org-gantt-set-scope (query)
  "Set the org-ql QUERY the chart draws.

Read as a sexp, so the whole language is available: `(and (tags
\"@deep\") (worked-on -7))' is a legal answer, and so is `(worked-on)'."
  (interactive
   (list (read (read-string "Query: " (format "%s" (or org-gantt--query
                                                       org-gantt-query))))))
  (setq org-gantt--query query)
  (org-gantt--refresh))

(defun org-gantt-set-group ()
  "Choose what rows are gathered under."
  (interactive)
  (let ((choice (completing-read "Group by: "
                                 '("category" "file" "state" "flat") nil t)))
    (setq org-gantt--group (pcase choice
                             ("category" :category)
                             ("file" :file)
                             ("state" :state)
                             (_ nil))))
  (org-gantt--refresh))

(defun org-gantt-cycle-overlap ()
  "Cycle how minutes are attributed when several entries are in PROG at once."
  (interactive)
  (setq org-gantt-overlap (pcase org-gantt-overlap
                            ('wall 'share)
                            ('share 'latest)
                            (_ 'wall)))
  (message "Overlap: %s" org-gantt-overlap)
  (org-gantt--refresh))

(defun org-gantt-toggle-table ()
  "Show or hide the table under the chart."
  (interactive)
  (if (and org-gantt--show-table (not (org-gantt--can-draw-p)))
      (user-error "The table is all this frame can show; the chart needs a graphical frame")
    (setq org-gantt--show-table (not org-gantt--show-table))
    (org-gantt--draw)))


;;;; The mode

(defvar org-gantt-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "n") #'org-gantt-next-line)
    (define-key map (kbd "p") #'org-gantt-previous-line)
    (define-key map (kbd "j") #'org-gantt-next-line)
    (define-key map (kbd "k") #'org-gantt-previous-line)
    (define-key map (kbd "f") #'org-gantt-forward)
    (define-key map (kbd "b") #'org-gantt-backward)
    (define-key map (kbd "F") #'org-gantt-shift)
    (define-key map (kbd "+") #'org-gantt-widen)
    (define-key map (kbd "-") #'org-gantt-narrow)
    (define-key map (kbd "r") #'org-gantt-set-range)
    (define-key map (kbd "s") #'org-gantt-set-scope)
    (define-key map (kbd "G") #'org-gantt-set-group)
    (define-key map (kbd "o") #'org-gantt-cycle-overlap)
    (define-key map (kbd "t") #'org-gantt-toggle-table)
    (define-key map (kbd "TAB") #'org-gantt-toggle-transitions)
    (define-key map (kbd "RET") #'org-gantt-visit)
    (define-key map (kbd "g") #'org-gantt-refresh)
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `org-gantt-mode'.")

(define-derived-mode org-gantt-mode special-mode "Gantt"
  "Major mode for the Gantt chart over Org state transitions."
  (setq truncate-lines t)
  (buffer-disable-undo))

;;;###autoload
(defun org-gantt (&optional days query)
  "Chart the last DAYS days, or `org-gantt-default-days'.

QUERY is an org-ql query; with a prefix argument it is read from the
minibuffer.  The chart opens on what was worked on: change the scope
with `s' once it is up, which is cheaper than deciding in advance."
  (interactive
   (list (when current-prefix-arg (read-number "Days: " org-gantt-default-days))
         (when current-prefix-arg
           (read (read-string "Query: " (format "%s" org-gantt-query))))))
  (let ((buffer (get-buffer-create org-gantt-buffer-name))
        (now (floor (float-time))))
    (with-current-buffer buffer
      (unless (derived-mode-p 'org-gantt-mode)
        (org-gantt-mode))
      (setq org-gantt--now nil
            org-gantt--to now
            org-gantt--from (- now (* (or days org-gantt-default-days) 60 60 24))
            org-gantt--query (or query org-gantt--query)
            org-gantt--group (or org-gantt--group org-gantt-group-by))
      (org-gantt--refresh))
    (pop-to-buffer buffer)))

;;;###autoload
(defun org-gantt-today ()
  "Chart today, hour by hour."
  (interactive)
  (org-gantt 1))


;;;; The dynamic block

;;;###autoload
(defun org-dblock-write:org-gantt-table (params)
  "Write the chart's table into an Org buffer.

  #+BEGIN: org-gantt-table :days 7 :group :category
  #+END:

The same numbers the chart draws, in a table a weekly review file can
keep -- so a review is assembled from the data rather than retyped."
  (let* ((now (floor (float-time)))
         (days (or (plist-get params :days) 7))
         (to (or (org-gantt-time (plist-get params :to)) now))
         (from (or (org-gantt-time (plist-get params :from))
                   (- to (* days 60 60 24))))
         (rows (org-gantt-harvest :query (plist-get params :query)
                                  :from from :to to :now now))
         (chart (org-gantt-core-chart rows from to :now now
                                      :group (or (plist-get params :group)
                                                 :category))))
    (insert (format "#+CAPTION: %s to %s, worked %s of %s estimated\n"
                    (format-time-string "%F" from)
                    (format-time-string "%F" to)
                    (org-gantt-core-format-minutes
                     (plist-get (plist-get chart :totals) :worked))
                    (org-gantt-core-format-minutes
                     (plist-get (plist-get chart :totals) :effort))))
    (insert "| Group | Task | State | Worked | Estimate | Ratio | Open | Sessions |\n|---|\n")
    (dolist (line (org-gantt-core-lines chart))
      (pcase (plist-get line :kind)
        ('group
         (let ((group (plist-get line :group)))
           (insert (format "| *%s* | | | *%s* | %s | %s | %s | |\n"
                           (plist-get group :name)
                           (org-gantt-core-format-minutes (plist-get group :worked))
                           (org-gantt-core-format-minutes (plist-get group :effort))
                           (if (plist-get group :ratio)
                               (format "%.2f" (plist-get group :ratio)) "")
                           (org-gantt-core-format-span (plist-get group :elapsed))))))
        ('row
         (let ((row (plist-get line :row)))
           (insert (format "| | %s | %s | %s | %s | %s | %s | %d |\n"
                           (plist-get row :title)
                           (or (plist-get row :state) "")
                           (concat (org-gantt-core-format-minutes (plist-get row :worked))
                                   (if (plist-get row :provisional) " (open)" ""))
                           (org-gantt-core-format-minutes (plist-get row :effort))
                           (if (plist-get row :ratio)
                               (format "%.2f" (plist-get row :ratio)) "")
                           (org-gantt-core-format-span (plist-get row :lifetime))
                           (plist-get row :sessions)))))))
    (org-table-align)))

(provide 'org-gantt)
;;; org-gantt.el ends here
