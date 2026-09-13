;;; org-decorate-lists.el --- The closed lists, read from Org state -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, outlines

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Everything the model may choose among, read from where the config
;; already keeps it: keywords from `org-todo-keywords-1', categories from
;; the agenda files' #+CATEGORY lines, refile targets from
;; `org-refile-get-targets', the context and energy groups from
;; `org-tag-alist', the corpus's tags, Effort_ALL, IMPACT_ALL,
;; DEADLINE_TYPE_ALL, the live projects, the people WAITING_ON has
;; named, and the WikiWords with a page.  Plus the two readers that need
;; Org: an entry as a plist, and a date phrase resolved with
;; `org-read-date' against the entry's CREATED.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-id)
(require 'org-ql)
(require 'org-decorate-core)

(declare-function hywiki-get-wikiword-list "hywiki")
(declare-function org-queue-dormant-projects "org-queue-dormant" (&optional files))
(declare-function org-queue-harvest--timestamp-date "org-queue-harvest" (string))

(defcustom org-decorate-files nil
  "Files whose lists decoration draws on.  Nil means `org-agenda-files'."
  :type '(choice (const nil) (repeat file))
  :group 'org-decorate)

(defcustom org-decorate-skip-categories '("archive" "routine")
  "Categories never proposed as a home for an entry."
  :type '(repeat string)
  :group 'org-decorate)

(defcustom org-decorate-private-tag "private"
  "An entry carrying this tag is never sent anywhere."
  :type 'string
  :group 'org-decorate)

(defun org-decorate--files ()
  (or org-decorate-files (org-agenda-files)))

(defun org-decorate--global-property (name)
  "Return the values of the global property NAME, split on spaces."
  (when-let* ((raw (cdr (assoc name org-global-properties))))
    (split-string raw)))

(defun org-decorate-lists-keywords ()
  "Return the keywords a proposal may name."
  (cl-remove-if (lambda (keyword) (member keyword org-decorate-forbidden-keywords))
                (with-temp-buffer (org-mode) org-todo-keywords-1)))

(defun org-decorate-lists-categories ()
  "Return the #+CATEGORY of every agenda file, minus the skipped ones."
  (delete-dups
   (delq nil
         (mapcar (lambda (file)
                   (when (file-readable-p file)
                     (with-temp-buffer
                       (insert-file-contents file nil 0 4000)
                       (goto-char (point-min))
                       (when (re-search-forward "^#\\+CATEGORY:[ \t]*\\(.+?\\)[ \t]*$" nil t)
                         (let ((category (match-string 1)))
                           (unless (member category org-decorate-skip-categories)
                             category))))))
                 (org-decorate--files)))))

(defun org-decorate-lists-targets ()
  "Return the refile targets as \"file\" or \"file::*Heading\" strings.
The flat files first, then the project headings the check calls live."
  (let ((files (mapcar #'file-name-nondirectory (org-decorate--files)))
        headings)
    (when (fboundp 'org-queue-dormant-projects)
      (dolist (project (ignore-errors (org-queue-dormant-projects (org-decorate--files))))
        (when (eq (plist-get project :status) 'live)
          (let ((task (plist-get project :task)))
            (push (format "%s::*%s" (file-name-nondirectory (plist-get task :file))
                          (plist-get task :title))
                  headings)))))
    (append (cl-remove-if (lambda (file)
                            (cl-some (lambda (skip) (string-match-p skip file))
                                     org-decorate-skip-categories))
                          files)
            (nreverse headings))))

(defun org-decorate-lists--tag-groups ()
  "Return the tag groups of `org-tag-alist' as lists of tag names."
  (let (groups current in-group)
    (dolist (cell org-tag-alist)
      (pcase cell
        ('(:startgroup) (setq in-group t current nil))
        ('(:endgroup) (push (nreverse current) groups) (setq in-group nil))
        (`(,tag . ,_) (when (and in-group (stringp tag)) (push tag current)))
        (_ nil)))
    (nreverse groups)))

(defun org-decorate-lists-contexts ()
  "Return the context group: the first group of `org-tag-alist'."
  (or (nth 0 (org-decorate-lists--tag-groups))
      '("@deep" "@shallow" "@errand" "@call" "@meeting" "@travel" "@social")))

(defun org-decorate-lists-energies ()
  "Return the energy group: the second group of `org-tag-alist'."
  (or (nth 1 (org-decorate-lists--tag-groups)) '("@fresh" "@tired")))

(defun org-decorate-lists-tags ()
  "Return every tag in the corpus that is not a context or energy tag."
  (let ((groups (apply #'append (org-decorate-lists--tag-groups)))
        tags)
    (dolist (file (org-decorate--files))
      (when (file-readable-p file)
        (with-current-buffer (find-file-noselect file)
          (org-with-wide-buffer
           (goto-char (point-min))
           (while (re-search-forward org-tag-line-re nil t)
             (dolist (tag (split-string (match-string 2) ":" t))
               (unless (or (member tag groups) (member tag tags))
                 (push tag tags))))))))
    (sort tags #'string<)))

(defun org-decorate-lists-people ()
  "Return everyone WAITING_ON has named across the files."
  (delete-dups
   (delq nil (org-ql-select (org-decorate--files) '(property "WAITING_ON")
               :action (lambda () (org-entry-get (point) "WAITING_ON"))))))

(defvar org-decorate-problems-function nil
  "Function returning the favourite problems, a list of strings.
Set by the knowledge module; nil means none.")

(defun org-decorate-lists-problems ()
  "Return the favourite problems, when something answers for them."
  (and org-decorate-problems-function
       (ignore-errors (funcall org-decorate-problems-function))))

(defun org-decorate-lists-wikiwords ()
  "Return the WikiWords that have a page, when HyWiki is around."
  (when (fboundp 'hywiki-get-wikiword-list)
    (ignore-errors (hywiki-get-wikiword-list))))

(defun org-decorate-lists ()
  "Return the lists plist the core validates against."
  (list :keywords (org-decorate-lists-keywords)
        :categories (org-decorate-lists-categories)
        :targets (org-decorate-lists-targets)
        :contexts (org-decorate-lists-contexts)
        :energies (org-decorate-lists-energies)
        :tags (org-decorate-lists-tags)
        :efforts (or (org-decorate--global-property "Effort_ALL")
                     '("0" "0:05" "0:10" "0:15" "0:20" "0:30" "0:45" "1:00" "1:30" "2:00"
                       "3:00" "4:00" "5:00" "6:00" "7:00"))
        :impacts (mapcar #'string-to-number
                         (or (org-decorate--global-property "IMPACT_ALL") '("1" "2" "3" "4" "5")))
        :deadline-types (or (org-decorate--global-property "DEADLINE_TYPE_ALL") '("hard" "soft"))
        :people (org-decorate-lists-people)
        :wikiwords (org-decorate-lists-wikiwords)
        :problems (org-decorate-lists-problems)))


;;;; One entry as a plist

(defun org-decorate--date-of (string)
  "Return the YYYYMMDD of Org timestamp STRING, or nil."
  (when (and string (string-match "\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)" string))
    (+ (* 10000 (string-to-number (match-string 1 string)))
       (* 100 (string-to-number (match-string 2 string)))
       (string-to-number (match-string 3 string)))))

(defun org-decorate--body ()
  "Return the entry's body: everything under the heading, minus drawers."
  (save-excursion
    (org-back-to-heading t)
    (let ((end (save-excursion (outline-next-heading) (point)))
          lines)
      (forward-line 1)
      (while (< (point) end)
        (cond
         ((looking-at-p "^[ \t]*:\\(PROPERTIES\\|LOGBOOK\\):")
          (re-search-forward "^[ \t]*:END:" end t)
          (forward-line 1))
         ((looking-at-p "^[ \t]*\\(SCHEDULED\\|DEADLINE\\|CLOSED\\):")
          (forward-line 1))
         (t (push (buffer-substring-no-properties (point) (line-end-position)) lines)
            (forward-line 1))))
      (string-trim (string-join (nreverse lines) "\n")))))

(defun org-decorate--backlink ()
  "Return the first link in the body that came from a source, or nil."
  (save-excursion
    (org-back-to-heading t)
    (let ((end (save-excursion (outline-next-heading) (point))))
      (when (re-search-forward "\\[\\[\\(\\(?:mu4e\\|elfeed\\|https?\\|eww\\|file\\|info\\|docview\\):[^]]+\\)\\]" end t)
        (match-string-no-properties 1)))))

(defun org-decorate-entry-at-point ()
  "Return the entry at point as the plist the core takes."
  (save-excursion
    (org-back-to-heading t)
    (let* ((components (org-heading-components))
           (properties (cl-remove-if-not
                        (lambda (cell) (string-prefix-p "AI_" (car cell)))
                        (org-entry-properties nil 'standard)))
           (effort (org-entry-get (point) "Effort"))
           (impact (org-entry-get (point) "IMPACT")))
      (list :id (org-entry-get (point) "ID")
            :file (buffer-file-name (buffer-base-buffer))
            :point (point)
            :heading (org-get-heading t t t t)
            :title (org-get-heading t t t t)
            :body (org-decorate--body)
            :created (org-decorate--date-of (org-entry-get (point) "CREATED"))
            :state (nth 2 components)
            :tags (org-get-tags nil t)
            :effort (and effort (not (string-empty-p effort)) effort)
            :impact (and impact (not (string-empty-p impact)) impact)
            :scheduled (org-decorate--date-of (org-entry-get (point) "SCHEDULED"))
            :deadline (org-decorate--date-of (org-entry-get (point) "DEADLINE"))
            :waiting-on (org-entry-get (point) "WAITING_ON")
            :backlink (org-decorate--backlink)
            :private (and (or (member org-decorate-private-tag (org-get-tags))
                              (org-entry-get (point) "AI_SKIP"))
                          t)
            :properties (append properties
                                (when-let* ((d (org-entry-get (point) "DUPLICATE_OF")))
                                  (list (cons "DUPLICATE_OF" d))))))))


;;;; Dates

(defun org-decorate-resolve-date (phrase created)
  "Resolve PHRASE against CREATED, a YYYYMMDD integer, or today when nil.
`org-decorate-core-resolve-phrase' does the reading: \"tue\" written on
Thursday the 3rd means the 8th whatever day this runs."
  (org-decorate-core-resolve-phrase
   phrase
   (or created
       (let ((now (decode-time)))
         (+ (* 10000 (nth 5 now)) (* 100 (nth 4 now)) (nth 3 now))))))

(provide 'org-decorate-lists)
;;; org-decorate-lists.el ends here
