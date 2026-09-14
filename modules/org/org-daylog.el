;;; org-daylog.el --- The interstitial line, the day log, the date button -*- lexical-binding: t; -*-

;; G9 and G13d of productivity.org.  Four small things, none of them a
;; package:
;;
;;   ,-o-o j    a journal line: `* HH:MM what I am doing', under today's
;;              [[Sep 12th, 2026]] heading in one journal file, carrying a
;;              link to the entry most recently moved to PROG so the line
;;              knows what it was between.
;;   ,-o-E      the day log (`org-queue-day-log'): transitions, intervals,
;;              captures, journal lines in time order, RET to jump, and
;;              the gaps inside a focus block with nothing in PROG.
;;   (hook)     a capture made while an entry is in PROG records that
;;              entry's ID as :INTERRUPTED:, so the close can count
;;              interruptions per PROG entry (Cirillo's dash, derived).
;;   (button)   any plain date -- 2026-09-12 or Sep 12th, 2026 -- is a
;;              Hyperbole implicit button opening that day in the rolo.
;;
;; The journal is one file so the rolo and irs already read it; there is
;; no page per day.  Nothing here prompts on a state change.

(require 'cl-lib)

(defvar org-capture-templates)
(defvar org-queue-journal-file)
(defvar org-queue-daylog-date-regexp)
(declare-function org-queue-daylog-core-parse-date "org-queue-daylog-core" (text))
(declare-function zetta-logseq--format-date "org" (time))
(declare-function zetta-hyrolo-day-regexp "hyperbole" (time))
(declare-function hyrolo-grep "hyrolo")
(declare-function org-id-get-create "org-id" (&optional force))
(declare-function org-get-heading "org" (&optional no-tags no-todo no-priority no-comment))
(declare-function org-entry-get "org" (epom property &optional inherit literal-nil))
(declare-function org-entry-put "org" (epom property value))
(declare-function org-capture-get "org-capture" (prop &optional local))
(declare-function org-at-timestamp-p "org" (&optional extended))
(declare-function org-end-of-subtree "org" (&optional invisible-ok to-heading))

(defcustom zetta-org-journal-file (zetta-kb-file "notes/journal.org")
  "The one journal file; a heading per day in the Logseq date form."
  :type 'file :group 'zetta)


;;;; The entry most recently moved to PROG

(defvar zetta-org-current-prog nil
  "(ID . TITLE) of the entry most recently moved to PROG in this session.")

(defun zetta-org-track-prog ()
  "Remember the entry entering PROG; forget it when it leaves."
  (cond
   ((equal org-state "PROG")
    (setq zetta-org-current-prog
          (cons (org-id-get-create) (org-get-heading t t t t))))
   ((and zetta-org-current-prog
         (equal (car zetta-org-current-prog) (org-entry-get (point) "ID")))
    (setq zetta-org-current-prog nil))))

(defvar org-state)
(with-eval-after-load 'org
  (add-hook 'org-after-todo-state-change-hook #'zetta-org-track-prog))

(defun zetta-org-prog-link ()
  "Return an Org link to the entry most recently moved to PROG, or \"\"."
  (if zetta-org-current-prog
      (format "[[id:%s][%s]]" (car zetta-org-current-prog) (cdr zetta-org-current-prog))
    ""))


;;;; Interruptions: what a capture interrupted

(defun zetta-org-capture-record-interruption ()
  "Write :INTERRUPTED: on the entry being captured, when something is in PROG.
Runs before finalize, in the capture buffer, so the property lands on
the entry itself.  A journal line is not an interruption."
  (when (and zetta-org-current-prog
             (not (equal (org-capture-get :key) "j"))
             (derived-mode-p 'org-mode)
             (not (org-entry-get (point) "INTERRUPTED")))
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward "^\\*+ " nil t)
        (org-entry-put (point) "INTERRUPTED" (car zetta-org-current-prog))))))

(with-eval-after-load 'org-capture
  (add-hook 'org-capture-before-finalize-hook #'zetta-org-capture-record-interruption))


;;;; The journal line

(defun zetta-org-journal-today ()
  "Move to today's heading in the journal file, creating it at the end."
  (let ((heading (zetta-logseq--format-date (current-time))))
    (goto-char (point-min))
    (unless (re-search-forward (concat "^\\* " (regexp-quote heading) "[ \t]*$") nil t)
      (goto-char (point-max))
      (unless (bolp) (insert "\n"))
      (insert "* " heading "\n")
      (forward-line -1))
    (beginning-of-line)))

(with-eval-after-load 'org-capture
  (add-to-list 'org-capture-templates
               `("j" "Journal line (what I am doing)"
                 entry
                 (file+function ,zetta-org-journal-file zetta-org-journal-today)
                 "* %<%H:%M> %?%(zetta-org-prog-link)"
                 :empty-lines 0)
               t))


;;;; The day log

(with-eval-after-load 'org-queue
  (setq org-queue-journal-file zetta-org-journal-file)
  (require 'org-queue-daylog))

(with-eval-after-load 'org-queue-daylog
  (general-define-key
   :keymaps 'menu-org-map
   "E" 'org-queue-day-log))


;;;; The date button

(defun zetta-org-date-at-point ()
  "Return (TEXT BEGIN END) of the date under point, in either form, or nil."
  (require 'org-queue-daylog-core)
  (save-excursion
    (let ((position (point))
          (eol (line-end-position))
          found)
      (beginning-of-line)
      (while (and (not found) (re-search-forward org-queue-daylog-date-regexp eol t))
        (when (and (<= (match-beginning 0) position) (<= position (match-end 0)))
          (setq found (list (match-string-no-properties 0)
                            (match-beginning 0) (match-end 0)))))
      found)))

(defun zetta-hyrolo-day-for (date)
  "Assemble every entry mentioning DATE, a YYYYMMDD integer, into `*HyRolo*'.
The wide search: the journal links live in the notes, not the todo files."
  (require 'hyrolo)
  (let* ((time (encode-time 0 0 12 (% date 100) (% (/ date 100) 100) (/ date 10000)))
         (files (hyrolo-expand-path-list hyrolo-file-list)))
    (hyrolo-grep (zetta-hyrolo-day-regexp time) nil files)))

(declare-function hyrolo-expand-path-list "hyrolo" (paths))
(defvar hyrolo-file-list)

(with-eval-after-load 'hyperbole
  ;; An implicit button type, not a `defil': a date has no delimiters.
  ;; Inside an Org timestamp the button declines, so `org-open-at-point'
  ;; keeps its behaviour there (smart-org delegates to it first anyway).
  (eval
   '(defib zetta-date ()
      "Open the HyRolo day for the ISO or journal-form date at point."
      (unless (and (derived-mode-p 'org-mode) (org-at-timestamp-p 'lax))
        (when-let* ((found (zetta-org-date-at-point))
                    (date (org-queue-daylog-core-parse-date (car found))))
          (ibut:label-set (car found) (nth 1 found) (nth 2 found))
          (hact 'zetta-hyrolo-day-for date))))
   t))
;;; org-daylog.el ends here
