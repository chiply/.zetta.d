;;; org-todo-schema.el --- Give the (todo) files metadata worth querying -*- lexical-binding: t; -*-

;; The (todo) files are not task files yet.  They are flat checkbox lists
;; -- `- [ ] tax return 25' -- and a census across the nine real files
;; found two SCHEDULED, six DEADLINE, one priority cookie and zero
;; :Effort:.  Everything the queue and the agenda do depends on metadata
;; that mostly does not exist, which makes migration a milestone rather
;; than an afterthought.
;;
;; Three tools, in the order you would use them:
;;
;;   `zetta-org-todo-census'          what each file has now
;;   `zetta-org-insert-todo-header'   the preamble that makes column view work
;;   `zetta-org-migrate-checkboxes'   `- [ ] x' -> `* TODO x', one file at a time
;;
;; ON DOING THIS SLOWLY.  The mechanical half is easy and this file does
;; it; the judgement half -- what deserves an estimate, a deadline, a
;; priority -- is not, and doing it for nine files in one sitting is how
;; the whole system dies.  Convert one file, live with it for a week, then
;; decide.  `zetta-org-migrate-checkboxes' therefore works on ONE buffer,
;; shows you what it is about to do, and asks.  There is deliberately no
;; command that converts them all.

(require 'cl-lib)
(require 'org)

;; Both defined in modules/org/org.el, which loads first.
(defvar zetta-org-todo-source)
(declare-function zetta-logseq-todo-files "org")

(defcustom zetta-org-todo-effort-values
  "0 0:05 0:10 0:15 0:20 0:30 0:45 1:00 1:30 2:00 3:00 4:00 5:00 6:00 7:00"
  "The Effort_ALL list written into (todo) file headers.
Matches `org-global-properties', so column view offers the same menu in
a file that has no header yet."
  :type 'string :group 'zetta)

(defcustom zetta-org-todo-columns
  (concat "%40ITEM(Task) %TODO %3PRIORITY(P) %17Effort(Estimate){:} "
          "%CLOCKSUM(Clocked) %DEADLINE %SCHEDULED %TAGS")
  "The #+COLUMNS line written into (todo) file headers."
  :type 'string :group 'zetta)

(defun zetta-org-todo-header (title category)
  "Return the preamble for a (todo) file called TITLE in CATEGORY.

#+CATEGORY carries more weight than it looks: it is what the agenda
groups by and what `org-queue' uses to stop one noisy file eating a
whole day."
  (format "#+TITLE: %s\n#+CATEGORY: %s\n#+PROPERTY: Effort_ALL %s\n#+COLUMNS: %s\n\n"
          title category zetta-org-todo-effort-values zetta-org-todo-columns))

(defun zetta-org-todo-file-category (file)
  "Guess a category from FILE, e.g. \"(todo) emacs.org\" -> \"emacs\"."
  (let ((base (file-name-base (or file "notes"))))
    (if (string-match "\\`(todo) \\(.+\\)\\'" base)
        (match-string 1 base)
      base)))

;;;###autoload
(defun zetta-org-insert-todo-header ()
  "Insert the (todo) file preamble at the top of this buffer.

Refuses if the buffer already has a #+COLUMNS line, so it is safe to run
over a directory of files that are half done."
  (interactive)
  (unless (derived-mode-p 'org-mode) (user-error "Not an Org buffer"))
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward "^#\\+COLUMNS:" nil t)
      (user-error "This file already has a #+COLUMNS line"))
    (goto-char (point-min))
    (let* ((category (zetta-org-todo-file-category (buffer-file-name)))
           (title (read-string "Title: " (capitalize category))))
      (insert (zetta-org-todo-header title category))))
  (message "Header inserted.  C-c C-x C-c now gives you column view."))


;;;; The census

(defun zetta-org-todo--file-stats (file)
  "Return a plist describing what metadata FILE actually carries."
  (with-current-buffer (find-file-noselect file)
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (let ((header (save-excursion
                        (re-search-forward "^#\\+COLUMNS:" nil t)))
              (checkboxes (count-matches "^[ \t]*- \\[[ X-]\\]" (point-min)
                                         (point-max)))
              (entries 0) (effort 0) (priority 0)
              (scheduled 0) (deadline 0) (created 0) (ids 0))
          (org-map-entries
           (lambda ()
             (when (org-get-todo-state)
               (cl-incf entries)
               (when (org-entry-get (point) "Effort") (cl-incf effort))
               (when (nth 3 (org-heading-components)) (cl-incf priority))
               (when (org-get-scheduled-time (point)) (cl-incf scheduled))
               (when (org-get-deadline-time (point)) (cl-incf deadline))
               (when (org-entry-get (point) "CREATED") (cl-incf created))
               (when (org-id-get) (cl-incf ids))))
           nil 'file)
          (list :file file :header (and header t) :checkboxes checkboxes
                :entries entries :effort effort :priority priority
                :scheduled scheduled :deadline deadline :created created
                :ids ids))))))

;;;###autoload
(defun zetta-org-todo-census ()
  "Report what metadata the active (todo) corpus actually has.

The same census the plan opened with, runnable rather than remembered --
which is what makes it possible to tell whether a migration is finished."
  (interactive)
  (let ((files (zetta-logseq-todo-files))
        (buffer (get-buffer-create "*org todo census*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (special-mode)
        (insert (format "%-24s %6s %6s %6s %6s %6s %6s %6s %6s\n"
                        (format "(todo) source: %s" zetta-org-todo-source)
                        "hdr" "boxes" "todos" "effort" "prio" "sched" "dl" "id"))
        (insert (make-string 88 ?-) "\n")
        (dolist (file files)
          (let ((stats (zetta-org-todo--file-stats file)))
            (insert (format "%-24s %6s %6d %6d %6d %6d %6d %6d %6d\n"
                            (truncate-string-to-width
                             (zetta-org-todo-file-category file) 24)
                            (if (plist-get stats :header) "yes" "--")
                            (plist-get stats :checkboxes)
                            (plist-get stats :entries)
                            (plist-get stats :effort)
                            (plist-get stats :priority)
                            (plist-get stats :scheduled)
                            (plist-get stats :deadline)
                            (plist-get stats :ids)))))
        (insert "\nboxes = checkbox items still to migrate"
                " (see `zetta-org-migrate-checkboxes').\n")
        (goto-char (point-min))))
    (pop-to-buffer buffer)))


;;;; Checkbox -> heading migration

(defconst zetta-org-todo--checkbox-re
  "^\\([ \t]*\\)- \\[\\([ Xx-]\\)\\][ \t]+\\(.*\\)$"
  "Matches a checkbox list item: indent, state character, text.")

(defcustom zetta-org-todo-checkbox-states
  '((?\s . "TODO") (?X . "DONE") (?x . "DONE") (?- . "PROG"))
  "TODO keyword each checkbox state becomes.

`[-]' is Org's partially-done marker, which on a task list means work
that was started and not finished -- PROG, exactly."
  :type '(alist :key-type character :value-type string)
  :group 'zetta)

(defun zetta-org-todo--in-block-p ()
  "Return non-nil if point is inside a #+begin_.../#+end_... block."
  (save-excursion
    (let ((case-fold-search t))
      (and (re-search-backward "^[ \t]*#\\+\\(begin\\|end\\)_" nil t)
           (string-equal (downcase (match-string 1)) "begin")))))

(defun zetta-org-todo--conversions (beginning end)
  "Return the conversions to make between BEGINNING and END.

Each element is (POSITION INDENT LEVEL STATE TEXT).  LEVEL comes from a
stack of indent columns rather than from a fixed indent step, so a file
that nests with two spaces and a file that nests with four both come out
with the nesting they look like they have."
  (save-excursion
    (goto-char beginning)
    (let (stack conversions)
      (while (re-search-forward zetta-org-todo--checkbox-re end t)
        (unless (zetta-org-todo--in-block-p)
          (let* ((indent (length (match-string 1)))
                 (state (aref (match-string 2) 0))
                 (text (match-string 3)))
            (while (and stack (>= (car stack) indent)) (pop stack))
            (push indent stack)
            (push (list (match-beginning 0) indent (length stack) state text)
                  conversions))))
      (nreverse conversions))))

;;;###autoload
(defun zetta-org-migrate-checkboxes (&optional dry-run)
  "Turn this buffer's checkbox items into TODO headings.

`- [ ] thing' becomes `* TODO thing', nested lists become nested
headings, and text indented under an item becomes that heading's body.
Nothing else is touched: no dates are invented, no estimates are
guessed, no :CREATED: is fabricated from today.

Shows what it will do and asks first.  With DRY-RUN (\\[universal-argument])
it only reports.  One buffer at a time, on purpose -- see the commentary."
  (interactive "P")
  (unless (derived-mode-p 'org-mode) (user-error "Not an Org buffer"))
  (let* ((region (use-region-p))
         (beginning (if region (region-beginning) (point-min)))
         (end (if region (region-end) (point-max)))
         (conversions (zetta-org-todo--conversions beginning end)))
    (cond
     ((null conversions) (message "No checkbox items here"))
     (dry-run
      (message "%d checkbox items, %d levels deep, states: %s"
               (length conversions)
               (apply #'max (mapcar (lambda (c) (nth 2 c)) conversions))
               (mapconcat #'identity
                          (delete-dups
                           (mapcar (lambda (c)
                                     (alist-get (nth 3 c)
                                                zetta-org-todo-checkbox-states
                                                "TODO"))
                                   conversions))
                          " ")))
     ((yes-or-no-p (format "Convert %d checkbox items in %s to headings? "
                           (length conversions)
                           (buffer-name)))
      (atomic-change-group
        ;; Backwards, so each edit leaves the positions of the ones still
        ;; to do untouched.  `reverse', not `nreverse': the count is
        ;; reported afterwards and a destructive reverse would leave
        ;; `conversions' pointing at the last cell alone.
        (dolist (conversion (reverse conversions))
          (pcase-let ((`(,position ,indent ,level ,state ,text) conversion))
            (goto-char position)
            (delete-region (line-beginning-position) (line-end-position))
            (insert (make-string level ?*) " "
                    (alist-get state zetta-org-todo-checkbox-states "TODO")
                    " " text)
            ;; Continuation lines belong to the heading now, and body text
            ;; under a heading is not indented.
            (forward-line)
            ;; The checkbox test comes first and uses `looking-at-p': a
            ;; failed `looking-at' leaves the match data undefined, and
            ;; `replace-match' below depends on it.
            (while (and (< (point) (point-max))
                        (not (looking-at-p zetta-org-todo--checkbox-re))
                        (looking-at (format "^[ \t]\\{%d,\\}\\(.*\\)$"
                                            (1+ indent))))
              (replace-match "\\1")
              (forward-line)))))
      (message "%d items converted.  Nothing else was changed."
               (length conversions))))))
;;; org-todo-schema.el ends here
