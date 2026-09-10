;;; org-gantt-svg.el --- Draw a Gantt chart of Org state transitions -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, calendar

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; One SVG for the whole chart, the way `org-timegrid' draws its week:
;; the alternative is a rectangle per bar as a separate image, and then
;; nothing can draw a rule down the chart or a marker between two rows.
;;
;; The geometry arrives already solved.  `org-gantt-core-chart' hands
;; over bars in fractions of the drawn span and ticks in the same units,
;; so everything below is a multiplication by a pixel width.  Nothing
;; here parses a date or measures a duration; if a bar is in the wrong
;; place the bug is in the core, and the core is tested in batch.
;;
;; TWO RAILS PER ROW.  The upper, thin rail is what was PLANNED; the
;; lower, thick one is what HAPPENED, cut into the states that were held.
;; Neither is filled in when it is missing: a row with no upper rail was
;; never planned and a row with no lower rail was never touched, and
;; both absences are findings that a chart which invented a bar would
;; hide.
;;
;; The palette is a prominence ladder rather than a code.  Work is the
;; most present thing on the row, waiting a rung down, idle time a rung
;; below that, and the plan is an outline rather than a fill -- so a row
;; reads as weight before it reads as colour, and it survives a theme
;; change and a black-and-white printer.

;;; Code:

(require 'svg)
(require 'cl-lib)
(require 'org-gantt-core)


;;;; Faces

;; Defaults that work in `emacs -Q'.  The module re-derives every one of
;; them from the brushup ink ladder on a theme change; nothing here knows
;; that, which is why the package can be dropped into another config.

(defface org-gantt-worked
  '((t :inherit default))
  "Time held in a working state -- the most present thing on a row."
  :group 'org-gantt)

(defface org-gantt-waiting
  '((t :inherit shadow))
  "Time held in a waiting state: blocked, not idle."
  :group 'org-gantt)

(defface org-gantt-idle
  '((t :inherit shadow))
  "Time the entry was open and in no particular state."
  :group 'org-gantt)

(defface org-gantt-span
  '((t :inherit shadow))
  "The hairline from an entry's first touch to its last."
  :group 'org-gantt)

(defface org-gantt-plan-queue
  '((t :inherit default))
  "A day the queue committed to: a solid outline."
  :group 'org-gantt)

(defface org-gantt-plan-schedule
  '((t :inherit shadow))
  "A SCHEDULED stamp with an estimate: a dashed outline."
  :group 'org-gantt)

(defface org-gantt-deadline
  '((t :inherit default :weight bold))
  "The deadline diamond."
  :group 'org-gantt)

(defface org-gantt-axis
  '((t :inherit shadow))
  "Axis labels and minor ticks."
  :group 'org-gantt)

(defface org-gantt-rule
  '((t :inherit shadow))
  "Major rules down the chart."
  :group 'org-gantt)

(defface org-gantt-label
  '((t :inherit default))
  "Row titles in the left gutter."
  :group 'org-gantt)

(defface org-gantt-number
  '((t :inherit shadow))
  "The measurements in the right gutter."
  :group 'org-gantt)

(defface org-gantt-group
  '((t :inherit default :weight bold))
  "A group heading and its summary bar."
  :group 'org-gantt)

(defface org-gantt-now
  '((t :inherit default))
  "The now marker."
  :group 'org-gantt)

(defface org-gantt-cursor
  '((t :inherit region))
  "The row the cursor is on."
  :group 'org-gantt)


;;;; Metrics

(defcustom org-gantt-row-height 26
  "Height of one entry row, in pixels.
Two rails and a gap have to fit; below about 20 the plan rail stops
being legible and the chart starts lying by omission."
  :type 'integer :group 'org-gantt)

(defcustom org-gantt-label-width 0.30
  "Width of the title gutter, as a fraction of the chart."
  :type 'number :group 'org-gantt)

(defcustom org-gantt-number-width 0.16
  "Width of the measurements gutter, as a fraction of the chart."
  :type 'number :group 'org-gantt)

(defun org-gantt-svg--color (face)
  "Return FACE's foreground as a colour string, falling back to the default's."
  (or (face-foreground face nil t)
      (face-foreground 'default nil t)
      "#000000"))

(defun org-gantt-svg--font-size ()
  "Return the pixel size to draw text at."
  (max 8 (round (* 0.74 (default-font-height)))))

(defun org-gantt-svg--char-width ()
  "Return an approximate character advance, for truncating labels."
  (max 5 (default-font-width)))

(defun org-gantt-svg--font-family ()
  "Return the family text is drawn in."
  (or (face-attribute 'default :family nil t) "sans-serif"))

(defun org-gantt-svg--truncate (string pixels)
  "Return STRING shortened to fit PIXELS, with an ellipsis if it was cut."
  (let ((columns (max 3 (floor pixels (org-gantt-svg--char-width)))))
    (if (<= (string-width string) columns)
        string
      (concat (truncate-string-to-width string (- columns 1)) "…"))))


;;;; Primitives

(defun org-gantt-svg--text (svg string x y face &optional anchor)
  "Draw STRING at X, Y in SVG using FACE, anchored ANCHOR."
  (svg-text svg string
            :x x :y y
            :fill (org-gantt-svg--color face)
            :font-family (org-gantt-svg--font-family)
            :font-size (org-gantt-svg--font-size)
            :font-weight (if (eq (face-attribute face :weight nil t) 'bold)
                             "bold" "normal")
            :text-anchor (or anchor "start")))

(defun org-gantt-svg--bar (svg x y width height face &optional opacity)
  "Draw a filled bar in SVG."
  (svg-rectangle svg x y (max 1.0 width) height
                 :fill (org-gantt-svg--color face)
                 :fill-opacity (or opacity 1.0)))

(defcustom org-gantt-plan-min-pixels 5
  "Narrowest a plan bar may be drawn, in pixels.

A fifteen-minute estimate on a seven-day axis is two pixels wide, which
is indistinguishable from nothing -- and \"nothing\" is what an
unplanned row deliberately looks like, so the two would be confused
exactly where it matters.  Below this the bar is drawn at this width
and reads as a tick: it says a plan existed and how long is in the
table."
  :type 'integer :group 'org-gantt)

(defun org-gantt-svg--outline (svg x y width height face &optional dashed)
  "Draw an outlined bar in SVG, DASHED when the plan is only a date."
  (apply #'svg-rectangle svg x y
         (max (float org-gantt-plan-min-pixels) width) height
         :fill "none"
         :stroke (org-gantt-svg--color face)
         :stroke-width 1
         :stroke-opacity 0.9
         (when dashed (list :stroke-dasharray "3,2"))))


;;;; The chart

(cl-defun org-gantt-svg-render (chart &key width lines cursor)
  "Return an image of CHART, WIDTH pixels across.

LINES is `org-gantt-core-lines' of the same chart -- passed in rather
than recomputed so the image and the table under it are drawing the
same list in the same order.  CURSOR is the index of the line to
highlight."
  (let* ((lines (or lines (org-gantt-core-lines chart)))
         (width (or width 900))
         (label-width (round (* width org-gantt-label-width)))
         (number-width (round (* width org-gantt-number-width)))
         (plot-x (+ label-width 8))
         (plot-width (max 60 (- width label-width number-width 16)))
         (font (org-gantt-svg--font-size))
         (axis-height (+ 6 (* 2 font)))
         (height (+ axis-height (* org-gantt-row-height (max 1 (length lines))) 6))
         (svg (svg-create width height)))
    (org-gantt-svg--axis svg chart plot-x plot-width axis-height height font)
    (cl-loop for line in lines
             for index from 0
             for top = (+ axis-height (* index org-gantt-row-height))
             do (org-gantt-svg--line svg line top
                                     :label-width label-width
                                     :plot-x plot-x
                                     :plot-width plot-width
                                     :number-x (+ plot-x plot-width 8)
                                     :width width
                                     :cursor (eq index cursor)))
    (org-gantt-svg--now svg chart plot-x plot-width axis-height height)
    (svg-image svg :scale 1 :ascent 'center)))

(defun org-gantt-svg--axis (svg chart x width axis-height height font)
  "Draw CHART's axis and its rules into SVG."
  (dolist (tick (plist-get chart :ticks))
    (let ((at (+ x (* width (plist-get tick :x)))))
      (when (plist-get tick :major)
        (svg-line svg at axis-height at height
                  :stroke (org-gantt-svg--color 'org-gantt-rule)
                  :stroke-width 1
                  :stroke-opacity 0.25))
      (svg-line svg at (- axis-height 4) at axis-height
                :stroke (org-gantt-svg--color 'org-gantt-axis)
                :stroke-width 1
                :stroke-opacity 0.6)
      (org-gantt-svg--text svg (plist-get tick :label) (+ at 3) (- axis-height 7)
                           'org-gantt-axis)))
  (svg-line svg x axis-height (+ x width) axis-height
            :stroke (org-gantt-svg--color 'org-gantt-axis)
            :stroke-width 1
            :stroke-opacity 0.6)
  ;; The window the chart covers, said once in words, because a reader
  ;; who has to infer the range from tick labels will infer it wrong.
  (org-gantt-svg--text
   svg
   (format "%s - %s"
           (format-time-string "%-d %b" (plist-get chart :from))
           (format-time-string "%-d %b" (plist-get chart :to)))
   4 (- axis-height 7) 'org-gantt-axis)
  (ignore font))

(defun org-gantt-svg--now (svg chart x width top bottom)
  "Draw the now marker down CHART, if now is on screen."
  (when-let* ((now-x (plist-get chart :now-x)))
    (let ((at (+ x (* width now-x))))
      (svg-line svg at top at bottom
                :stroke (org-gantt-svg--color 'org-gantt-now)
                :stroke-width 1
                :stroke-dasharray "2,3"
                :stroke-opacity 0.8))))

(cl-defun org-gantt-svg--line (svg line top &key label-width plot-x plot-width
                                   number-x width cursor)
  "Draw one display LINE into SVG with its top edge at TOP."
  (let* ((height org-gantt-row-height)
         (baseline (+ top (round (* height 0.62))))
         (row (plist-get line :row))
         (group (plist-get line :group)))
    (when cursor
      (svg-rectangle svg 0 top width height
                     :fill (or (face-background 'org-gantt-cursor nil t)
                               (face-background 'region nil t)
                               "#dddddd")
                     :fill-opacity 0.35))
    (pcase (plist-get line :kind)
      ('group
       (org-gantt-svg--text svg (org-gantt-svg--truncate
                                 (format "%s (%d)"
                                         (plist-get group :name)
                                         (plist-get group :count))
                                 (- label-width 8))
                            4 baseline 'org-gantt-group)
       ;; One bar for the group: its span, drawn faintly, so a collapsed
       ;; group still says when its work happened.
       (when-let* ((rows (plist-get group :rows)))
         (let ((left (cl-loop for r in rows
                              for bar = (cl-find-if
                                         (lambda (b) (eq (plist-get b :class) 'span))
                                         (plist-get r :bars))
                              when bar minimize (plist-get bar :x0)))
               (right (cl-loop for r in rows
                               for bar = (cl-find-if
                                          (lambda (b) (eq (plist-get b :class) 'span))
                                          (plist-get r :bars))
                               when bar maximize (plist-get bar :x1))))
           (when (and left right (> right left))
             (org-gantt-svg--bar svg (+ plot-x (* plot-width left))
                                 (+ top (round (* height 0.42)))
                                 (* plot-width (- right left))
                                 (max 2 (round (* height 0.16)))
                                 'org-gantt-group 0.35))))
       (org-gantt-svg--text svg (org-gantt-core-format-minutes
                                 (plist-get group :worked))
                            (- (+ number-x (round (* width org-gantt-number-width))) 12)
                            baseline 'org-gantt-group "end"))
      ('row
       (org-gantt-svg--text
        svg (org-gantt-svg--truncate (or (plist-get row :title) "?")
                                     (- label-width 20))
        16 baseline 'org-gantt-label)
       ;; A dot in the margin for a row nothing planned: the absence of
       ;; the upper rail is easy to miss on a busy chart.
       (unless (cl-find-if (lambda (bar) (eq (plist-get bar :rail) 'plan))
                           (plist-get row :bars))
         (svg-circle svg 7 (- baseline 4) 2
                     :fill (org-gantt-svg--color 'org-gantt-idle)
                     :fill-opacity 0.7))
       (org-gantt-svg--rails svg row top plot-x plot-width)
       (org-gantt-svg--marks svg row top plot-x plot-width)
       (org-gantt-svg--numbers svg row baseline number-x
                               (round (* width org-gantt-number-width)))))))

(defun org-gantt-svg--rails (svg row top x width)
  "Draw ROW's plan and actual rails into SVG."
  (let* ((height org-gantt-row-height)
         (plan-y (+ top (round (* height 0.16))))
         (plan-h (max 3 (round (* height 0.16))))
         (actual-y (+ top (round (* height 0.46))))
         (actual-h (max 5 (round (* height 0.30)))))
    (dolist (bar (plist-get row :bars))
      (let* ((left (+ x (* width (plist-get bar :x0))))
             (right (+ x (* width (plist-get bar :x1))))
             (span (- right left)))
        (pcase (list (plist-get bar :rail) (plist-get bar :class))
          (`(plan queue)
           (org-gantt-svg--outline svg left plan-y span plan-h 'org-gantt-plan-queue))
          (`(plan schedule)
           (org-gantt-svg--outline svg left plan-y span plan-h
                                   'org-gantt-plan-schedule t))
          (`(actual span)
           ;; The hairline: it says the entry was open across this stretch
           ;; even where no state segment covers it.
           (svg-line svg left (+ actual-y (/ actual-h 2.0))
                     right (+ actual-y (/ actual-h 2.0))
                     :stroke (org-gantt-svg--color 'org-gantt-span)
                     :stroke-width 1
                     :stroke-opacity 0.5)
           (when (plist-get bar :continues-left)
             (org-gantt-svg--text svg "‹" (- left 2) (+ actual-y actual-h)
                                  'org-gantt-span "end"))
           (when (plist-get bar :continues-right)
             (org-gantt-svg--text svg "›" (+ right 2) (+ actual-y actual-h)
                                  'org-gantt-span)))
          (`(actual working)
           (org-gantt-svg--bar svg left actual-y span actual-h 'org-gantt-worked 0.95))
          (`(actual waiting)
           (org-gantt-svg--bar svg left actual-y span actual-h 'org-gantt-waiting 0.45))
          (`(actual idle)
           (org-gantt-svg--bar svg left (+ actual-y (round (* actual-h 0.35)))
                               span (max 2 (round (* actual-h 0.3)))
                               'org-gantt-idle 0.35)))
        ;; A plan the day could not hold is drawn to the edge it ran out
        ;; at, then stopped with a stub, rather than silently shortened.
        (when (plist-get bar :short)
          (svg-line svg right plan-y right (+ plan-y plan-h)
                    :stroke (org-gantt-svg--color 'org-gantt-plan-queue)
                    :stroke-width 2))))))

(defun org-gantt-svg--marks (svg row top x width)
  "Draw ROW's deadline, close and open markers into SVG."
  (let* ((height org-gantt-row-height)
         (mid (+ top (round (* height 0.60)))))
    (dolist (mark (plist-get row :marks))
      (let ((at (+ x (* width (plist-get mark :x)))))
        (pcase (plist-get mark :kind)
          ('deadline
           (svg-polygon svg (list (cons at (- mid 5)) (cons (+ at 4) mid)
                                  (cons at (+ mid 5)) (cons (- at 4) mid))
                        :fill (org-gantt-svg--color 'org-gantt-deadline)
                        :fill-opacity 0.9))
          ('closed
           (svg-line svg at (- mid 6) at (+ mid 6)
                     :stroke (org-gantt-svg--color 'org-gantt-worked)
                     :stroke-width 2))
          ('open
           (svg-polygon svg (list (cons at (- mid 5)) (cons (+ at 6) mid)
                                  (cons at (+ mid 5)))
                        :fill (org-gantt-svg--color 'org-gantt-worked)
                        :fill-opacity 0.55)))))))

(defun org-gantt-svg--numbers (svg row baseline x width)
  "Draw ROW's measurements into SVG, right-aligned in a gutter of WIDTH."
  (let* ((worked (org-gantt-core-format-minutes (plist-get row :worked)))
         (effort (plist-get row :effort))
         (text (concat worked
                       (when effort
                         (concat " / " (org-gantt-core-format-minutes effort)))
                       (when (plist-get row :provisional) " ~")
                       (when (plist-get row :lifetime)
                         (concat "  " (org-gantt-core-format-span
                                       (plist-get row :lifetime)))))))
    (org-gantt-svg--text svg (org-gantt-svg--truncate text (- width 8))
                         (+ x width -12) baseline
                         (if (and (plist-get row :ratio)
                                  (> (plist-get row :ratio) 1.5))
                             'org-gantt-label
                           'org-gantt-number)
                         "end")))

(provide 'org-gantt-svg)
;;; org-gantt-svg.el ends here
