;;; org-knowledge.el --- Promote a note to a HyWiki page, resurface an old one -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: outlines, hypermedia

;; This file is not part of GNU Emacs.

;;; Commentary:

;; HyWiki pages are the permanent layer.  Three commands:
;;
;;   `org-knowledge-promote'     the heading at point becomes (or extends)
;;                               a page named by a WikiWord; the body moves
;;                               verbatim; one link stays at the source with
;;                               the reason you type -- the one thing typed
;;   `org-knowledge-resurface'   a page untouched for a month, beside the
;;                               places that mention it
;;   `org-knowledge-on-this-day' the rolo for this day a year and a month ago
;;
;; No org-roam, no renaming: `WikiWord.org' under `org-knowledge-directory'
;; is the address.  The favourite problems are the headings of
;; `FavouriteProblems.org' in that directory; decoration scores each
;; capture against them as AI_PROBLEM.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-knowledge-core)

(declare-function hyrolo-grep "hyrolo")
(declare-function hyrolo-expand-path-list "hyrolo" (paths))
(declare-function zetta-hyrolo-day-for "org-daylog" (date))
(defvar hyrolo-file-list)
(defvar hywiki-directory)

(defcustom org-knowledge-directory nil
  "Where the pages live.  Nil means `hywiki-directory', else ~/kb/wiki."
  :type '(choice (const nil) directory)
  :group 'org-knowledge)

(defcustom org-knowledge-problems-file "FavouriteProblems.org"
  "The page whose headings are the favourite problems, in the directory."
  :type 'string
  :group 'org-knowledge)

(defun org-knowledge--directory ()
  (file-name-as-directory
   (expand-file-name (or org-knowledge-directory
                         (and (boundp 'hywiki-directory) hywiki-directory)
                         (expand-file-name "wiki" (or (bound-and-true-p zetta-kb-dir) "~/kb/"))))))

(defun org-knowledge-page-file (word)
  "Return the file of page WORD."
  (expand-file-name (concat word ".org") (org-knowledge--directory)))

(defun org-knowledge--body-bounds ()
  "Return (BEGIN . END) of the entry's body: after the meta data, before the next heading."
  (save-excursion
    (org-back-to-heading t)
    (org-end-of-meta-data t)
    (let ((begin (point))
          (end (save-excursion (or (outline-next-heading) (goto-char (point-max))) (point))))
      (cons begin end))))

;;;###autoload
(defun org-knowledge-promote (word reason)
  "Promote the heading at point to page WORD, leaving a link and REASON.

The body moves verbatim (the page is created, or extended when it
exists); the source keeps its heading and gains one line: the link,
then the reason as a sentence.  The reason is asked for before anything
is written, and an empty one aborts.  The source edit is one undo."
  (interactive
   (let* ((title (org-get-heading t t t t))
          (word (read-string "Page (WikiWord): " (org-knowledge-core-wikiword title))))
     (unless (org-knowledge-core-wikiword-p word)
       (user-error "%s is not a WikiWord" word))
     (list word (read-string (format "Why does this belong on %s? " word)))))
  (unless (derived-mode-p 'org-mode) (user-error "Not on an entry"))
  (let* ((line (org-knowledge-core-source-line word reason))   ; errors on an empty reason
         (bounds (org-knowledge--body-bounds))
         (body (buffer-substring-no-properties (car bounds) (cdr bounds)))
         (file (org-knowledge-page-file word))
         (existing (and (file-exists-p file)
                        (with-temp-buffer (insert-file-contents file) (buffer-string)))))
    (make-directory (org-knowledge--directory) t)
    (with-temp-file file
      (insert (org-knowledge-core-page-text word body existing)))
    (atomic-change-group
      (delete-region (car bounds) (cdr bounds))
      (goto-char (car bounds))
      (insert line "\n"))
    (message "%s: %s" (if existing "Extended" "Made") (file-name-nondirectory file))
    file))

(defun org-knowledge-pages ()
  "Return every page as (:word :file :touched)."
  (let ((directory (org-knowledge--directory)))
    (when (file-directory-p directory)
      (mapcar (lambda (file)
                (let ((decoded (decode-time (file-attribute-modification-time
                                             (file-attributes file)))))
                  (list :word (file-name-base file) :file file
                        :touched (+ (* 10000 (nth 5 decoded)) (* 100 (nth 4 decoded))
                                    (nth 3 decoded)))))
              (directory-files directory t "\\`[A-Z][A-Za-z0-9]*\\.org\\'")))))

(defun org-knowledge--today ()
  (let ((now (decode-time)))
    (+ (* 10000 (nth 5 now)) (* 100 (nth 4 now)) (nth 3 now))))

;;;###autoload
(defun org-knowledge-resurface ()
  "Open the page untouched longest, beside the places that mention it."
  (interactive)
  (let ((pages (org-knowledge-core-untouched (org-knowledge-pages) (org-knowledge--today))))
    (unless pages
      (user-error "No page untouched for %d days" org-knowledge-resurface-days))
    (let ((page (car pages)))
      (find-file (plist-get page :file))
      (when (and (require 'hyrolo nil t) (boundp 'hyrolo-file-list))
        (hyrolo-grep (regexp-quote (plist-get page :word)) nil
                     (hyrolo-expand-path-list hyrolo-file-list)))
      (message "%s: untouched since %s" (plist-get page :word)
               (let ((d (plist-get page :touched)))
                 (format "%d-%02d-%02d" (/ d 10000) (% (/ d 100) 100) (% d 100)))))))

;;;###autoload
(defun org-knowledge-on-this-day ()
  "The rolo for this day a year ago, and a month ago."
  (interactive)
  (unless (fboundp 'zetta-hyrolo-day-for)
    (user-error "zetta-hyrolo-day-for is not available"))
  (dolist (date (org-knowledge-core-on-this-day (org-knowledge--today)))
    (zetta-hyrolo-day-for date)))

(defun org-knowledge-problems ()
  "Return the favourite problems: the headings of the problems page."
  (let ((file (expand-file-name org-knowledge-problems-file (org-knowledge--directory))))
    (when (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (let (problems)
          (goto-char (point-min))
          (while (re-search-forward "^\\*+ +\\(.+?\\)[ \t]*$" nil t)
            (push (match-string 1) problems))
          (nreverse problems))))))

(provide 'org-knowledge)
;;; org-knowledge.el ends here
