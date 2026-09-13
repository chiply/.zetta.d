;;; org-queue-season.el --- Horizons: the file, the check, the season command -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; One file, `org-queue-horizons-file', in the agenda:
;;
;;   * Theme
;;   :PROPERTIES:
;;   :SEASON: 2026-Q3
;;   :END:
;;   One sentence.
;;
;;   * MISSION Ship the retrieval service
;;   :PROPERTIES:
;;   :ID:     ...
;;   :SEASON: 2026-Q3
;;   :END:
;;
;;   * AREA emacs
;;   :PROPERTIES:
;;   :MIN_HOURS_WEEK: 5
;;   :MAX_HOURS_WEEK: 15
;;   :END:
;;
;; A project links to a mission with `:MISSION:' (the ID), inherited by
;; its children.  The daily plan never opens this file: only the review
;; pack (floors, ceilings, orphans) and the season command read it.
;; Saving the file with a fourth mission for the season is refused.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-id)
(require 'org-ql)
(require 'org-queue)
(require 'org-queue-season-core)

(declare-function org-queue-review-compute "org-queue-review" (&optional today))
(declare-function org-queue-review--draw "org-queue-review" (pack))
(declare-function org-queue-review-mode "org-queue-review")
(defvar org-queue-review-window)

(defcustom org-queue-horizons-file "~/kb/todo/(todo) horizons.org"
  "The theme, the missions and the areas' floors."
  :type 'file
  :group 'org-queue)

(defun org-queue-season--file ()
  (expand-file-name org-queue-horizons-file))

(defun org-queue-season-current ()
  "The current season's name."
  (org-queue-season-core-name (org-queue-core-today)))

(defun org-queue-season--read ()
  "Return (:theme :theme-date :season :missions :areas) from the file."
  (when (file-readable-p (org-queue-season--file))
    (with-current-buffer (find-file-noselect (org-queue-season--file))
      (org-with-wide-buffer
       (let (theme theme-date season missions areas)
         (org-map-entries
          (lambda ()
            (let ((title (org-get-heading t t t t))
                  (keyword (org-get-todo-state)))
              (cond
               ((equal keyword "MISSION")
                (push (list :id (org-entry-get (point) "ID") :title title
                            :season (org-entry-get (point) "SEASON"))
                      missions))
               ((string-match "\\`AREA[ \t]+\\(.+\\)\\'" title)
                ;; The name first: `org-entry-get' runs its own regexps
                ;; and would clobber the match data.
                (let* ((name (match-string 1 title))
                       (min (org-entry-get (point) "MIN_HOURS_WEEK"))
                       (max (org-entry-get (point) "MAX_HOURS_WEEK")))
                  (push (cons name (cons (and min (string-to-number min))
                                         (and max (string-to-number max))))
                        areas)))
               ((equal title "Theme")
                (setq theme (org-queue-season--body)
                      season (org-entry-get (point) "SEASON")
                      theme-date (org-queue-harvest--timestamp-date
                                  (org-entry-get (point) "CREATED")))))))
          nil 'file)
         (list :theme theme :theme-date theme-date :season season
               :missions (nreverse missions) :areas (nreverse areas)))))))

(defun org-queue-season--body ()
  "The entry's first body line."
  (save-excursion
    (org-end-of-meta-data t)
    (string-trim (buffer-substring-no-properties (point) (line-end-position)))))

(defun org-queue-season-floors ()
  "The areas' (CATEGORY MIN . MAX) hours a week, for the pack."
  (plist-get (org-queue-season--read) :areas))

(defun org-queue-season-missions ()
  "The missions, for the pack and the views."
  (plist-get (org-queue-season--read) :missions))


;;;; The check on save

(defun org-queue-season-check-missions ()
  "Refuse to save the horizons file with more missions than the season holds.
On `write-file-functions', not `before-save-hook': Emacs demotes an
error in the latter to a message and saves anyway.  Returns nil, so
the save goes on when the check passes."
  (when (and buffer-file-name
             (equal (expand-file-name buffer-file-name) (org-queue-season--file)))
    (let ((refusal (org-queue-season-core-check
                    (org-with-wide-buffer
                     (let (missions)
                       (org-map-entries
                        (lambda ()
                          (when (equal (org-get-todo-state) "MISSION")
                            (push (list :title (org-get-heading t t t t)
                                        :season (org-entry-get (point) "SEASON"))
                                  missions)))
                        nil 'file)
                       missions))
                    (org-queue-season-current))))
      (when refusal (user-error "%s" refusal))
      nil)))

(add-hook 'write-file-functions #'org-queue-season-check-missions)


;;;; Predicates and the harvest

(org-ql-defpred mission ()
  "Return non-nil if the entry serves a mission, by an inherited MISSION."
  :body (org-entry-get (point) "MISSION" t))

(org-ql-defpred orphan ()
  "Return non-nil if the entry is open work serving no mission."
  :body (and (member (org-get-todo-state) '("TODO" "NEXT" "PROG"))
             (not (equal (org-entry-get (point) "STYLE") "habit"))
             (not (org-entry-get (point) "MISSION" t))))


;;;; The season command

(defconst org-queue-season--template
  "#+TITLE: Horizons
#+CATEGORY: horizons
#+TODO: MISSION | DONE

* Theme
:PROPERTIES:
:SEASON:  %s
:CREATED: %s
:END:
One sentence: what this season is for.

* MISSION The first of at most three
:PROPERTIES:
:ID:       %s
:SEASON:   %s
:END:

* AREA emacs
:PROPERTIES:
:MIN_HOURS_WEEK: 2
:MAX_HOURS_WEEK: 10
:END:
"
  "What a new horizons file starts as.")

(defun org-queue-season--ensure-file ()
  "Create the horizons file from the template when it does not exist."
  (let ((file (org-queue-season--file)))
    (unless (file-exists-p file)
      (with-temp-file file
        (insert (format org-queue-season--template
                        (org-queue-season-current)
                        (format-time-string "[%Y-%m-%d %a]")
                        (org-id-uuid)
                        (org-queue-season-current)))))
    file))

;;;###autoload
(defun org-queue-season ()
  "The season: last season's walk beside the horizons file, to rewrite.
The walk is the review pack over twelve weeks; the file is where the
theme and the missions are typed."
  (interactive)
  (require 'org-queue-review)
  (let* ((today (org-queue-core-today))
         (read (org-queue-season--read))
         (org-queue-review-window 84)
         (pack (org-queue-review-compute today))
         (buffer (get-buffer-create "*org-queue season*")))
    (with-current-buffer buffer
      (org-queue-review-mode)
      (setq org-queue--columns (copy-sequence org-queue-columns))
      (org-queue-review--draw pack)
      (let ((inhibit-read-only t))
        (goto-char (point-min))
        (forward-line 1)
        (insert (propertize (format "Season %s%s\n" (org-queue-season-current)
                                    (cond ((null read) " -- no horizons file yet; one is being made")
                                          ((org-queue-season-core-stale-p (plist-get read :theme-date) today)
                                           " -- the theme is older than a season: stale")
                                          (t "")))
                            'face 'org-queue-section))
        (when read
          (insert (propertize (format "   theme: %s\n" (or (plist-get read :theme) "none"))
                              'face 'org-queue-detail))
          (dolist (mission (plist-get read :missions))
            (insert (propertize (format "   mission: %s%s\n" (plist-get mission :title)
                                        (if (member mission (org-queue-season-core-rockless
                                                             (plist-get read :missions)
                                                             (org-queue-harvest) today))
                                            "  (no rock this week)" ""))
                                'face 'org-queue-detail))))
        (goto-char (point-min))))
    (pop-to-buffer buffer)
    (find-file-other-window (org-queue-season--ensure-file))))

(provide 'org-queue-season)
;;; org-queue-season.el ends here
