;;; org-knowledge-core.el --- Promote a note to a page, resurface an old one -- arithmetic -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: outlines, hypermedia

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The knowledge loop's arithmetic, no Org and no HyWiki in it: a
;; heading's title as a WikiWord, the page text a promotion writes, the
;; line it leaves at the source, and which pages have gone untouched
;; long enough to resurface.

;;; Code:

(require 'cl-lib)

(defgroup org-knowledge nil
  "Promote notes to HyWiki pages and resurface old ones."
  :group 'org
  :prefix "org-knowledge-")

(defcustom org-knowledge-resurface-days 30
  "Days a page must have gone untouched before it is resurfaced."
  :type 'integer
  :group 'org-knowledge)

(defun org-knowledge-core-wikiword (title)
  "Return TITLE as a WikiWord: capitalised words, letters and digits only.
\"the retrieval service\" is \"TheRetrievalService\"; a title that is
already a WikiWord is returned as it is."
  (let ((words (split-string (replace-regexp-in-string "[^[:alnum:] ]" " " (or title "")))))
    (if (and (= 1 (length words)) (org-knowledge-core-wikiword-p (car words)))
        (car words)
      (mapconcat (lambda (word) (concat (upcase (substring word 0 1)) (downcase (substring word 1))))
                 words ""))))

(defun org-knowledge-core-wikiword-p (word)
  "Return non-nil if WORD is shaped like a WikiWord.
A capitalised word, or several run together: HyWiki's own pages here
are Hyperbole, Python and Two, so one word is enough.  Case matters."
  (let ((case-fold-search nil))
    (and (stringp word)
         (string-match-p "\\`[A-Z][a-z0-9]+\\(?:[A-Z][a-z0-9]+\\)*\\'" word)
         t)))

(defun org-knowledge-core-page-text (word body &optional existing)
  "Return the text of page WORD holding BODY, verbatim.
With EXISTING, the page's current text, BODY is appended after it; the
title line is written once."
  (let ((body (string-trim-right (or body "") "\n+")))
    (if (and existing (not (string-empty-p existing)))
        (concat (string-trim-right existing "\n+") "\n\n" body "\n")
      (concat "#+title: " word "\n\n" body "\n"))))

(defun org-knowledge-core-source-line (word reason)
  "Return the line left at the source: the link, then the reason as a sentence.
The reason is the one thing typed, Luhmann's link context; empty is an
error, raised before anything is written."
  (let ((reason (string-trim (or reason ""))))
    (when (string-empty-p reason)
      (error "A link needs its reason: why does this belong on %s?" word))
    (format "[[hy:%s]] %s%s" word reason
            (if (string-match-p "[.!?]\\'" reason) "" "."))))

(defun org-knowledge-core-untouched (pages today &optional days)
  "Return the PAGES untouched for DAYS, oldest first.
PAGES are plists (:word :file :touched), `:touched' a YYYYMMDD integer."
  (let ((days (or days org-knowledge-resurface-days)))
    (sort (cl-remove-if-not
           (lambda (page)
             (and (plist-get page :touched)
                  (> (org-knowledge-core--days-between (plist-get page :touched) today) days)))
           (copy-sequence pages))
          (lambda (a b) (< (plist-get a :touched) (plist-get b :touched))))))

(defun org-knowledge-core--day-number (date)
  (let* ((y (/ date 10000)) (m (% (/ date 100) 100)) (d (% date 100))
         (y (if (<= m 2) (1- y) y))
         (era (/ (if (>= y 0) y (- y 399)) 400))
         (yoe (- y (* era 400)))
         (doy (+ (/ (+ (* 153 (+ m (if (> m 2) -3 9))) 2) 5) (1- d)))
         (doe (+ (* yoe 365) (/ yoe 4) (- (/ yoe 100)) doy)))
    (+ (* era 146097) doe -719468)))

(defun org-knowledge-core--days-between (from to)
  (- (org-knowledge-core--day-number to) (org-knowledge-core--day-number from)))

(defun org-knowledge-core--days-in-month (year month)
  (let ((next (if (= month 12) (+ (* (1+ year) 10000) 100 1)
                (+ (* year 10000) (* (1+ month) 100) 1))))
    (- (org-knowledge-core--day-number next)
       (org-knowledge-core--day-number (+ (* year 10000) (* month 100) 1)))))

(defun org-knowledge-core-on-this-day (today)
  "Return the two dates \"on this day\" looks at: a year and a month back.
The day is kept where the month has it, and clamped to the month's last
day where it does not: 31 January looks at 31 December and 31 January."
  (let* ((y (/ today 10000)) (m (% (/ today 100) 100)) (d (% today 100))
         (last-month (if (= m 1) (list (1- y) 12) (list y (1- m)))))
    (list (+ (* (1- y) 10000) (* m 100)
             (min d (org-knowledge-core--days-in-month (1- y) m)))
          (+ (* (nth 0 last-month) 10000) (* (nth 1 last-month) 100)
             (min d (org-knowledge-core--days-in-month (nth 0 last-month) (nth 1 last-month)))))))

(provide 'org-knowledge-core)
;;; org-knowledge-core.el ends here
