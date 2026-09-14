;;; org-queue-mail.el --- WAITING_ON from sent mail, through mu -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, mail

;; This file is not part of GNU Emacs.

;;; Commentary:

;; `org-queue-mail-waiting' asks mu for the flagged messages in the sent
;; folders and the inbox, reads each body from its file, and writes the
;; candidates `org-queue-mail-core' finds into an archive stub outside
;; the daily views -- one WAIT per question you asked, one NEXT per
;; flagged message you received -- once per message ID.  Mail bodies are
;; never copied into the kb; the entry holds the subject, the
;; correspondent and a mu4e link.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-queue-mail-core)

;; Under the Zetta config the kb root is `zetta-kb-dir'; standalone, ~/kb.
(defcustom org-queue-mail-stub
  (expand-file-name "todo/mail.org_archive" (or (bound-and-true-p zetta-kb-dir) "~/kb/"))
  "The archive stub the mail entries are written to.
An archive file: outside `org-agenda-files' and the refile targets,
found by text search through `org-agenda-text-search-extra-files'."
  :type 'file
  :group 'org-queue)

(defcustom org-queue-mail-sent-query "flag:flagged maildir:/\"Sent Mail\"/"
  "The mu query for flagged sent messages."
  :type 'string
  :group 'org-queue)

(defcustom org-queue-mail-received-query "flag:flagged maildir:/INBOX/"
  "The mu query for flagged received messages."
  :type 'string
  :group 'org-queue)

(defcustom org-queue-mail-addresses nil
  "Your addresses, to tell whose message ends a thread.
Nil means every address whose maildir is a sent folder."
  :type '(repeat string)
  :group 'org-queue)

(defun org-queue-mail--find (query)
  "Return mu's sexp records for QUERY, as plists."
  (with-temp-buffer
    (when (zerop (ignore-errors
                   (call-process "mu" nil t nil "find" "-o" "sexp" "--maxnum" "200" query)))
      (goto-char (point-min))
      (let (records)
        (while (not (eobp))
          (let ((form (ignore-errors (read (current-buffer)))))
            (when (and form (listp form) (keywordp (car form)))
              (push form records)))
          (skip-chars-forward " \t\n"))
        (nreverse records)))))

(defun org-queue-mail--body (path)
  "Return the text body of the message file PATH, best effort."
  (when (and path (file-readable-p path))
    (with-temp-buffer
      (insert-file-contents path nil 0 200000)
      (goto-char (point-min))
      (when (re-search-forward "^$" nil t)
        (let ((body (buffer-substring-no-properties (point) (point-max))))
          ;; A multipart message: keep the first text/plain part.
          (if (string-match "Content-Type: text/plain[^\n]*\n\\(?:[^\n]+\n\\)*\n" body)
              (let ((start (match-end 0)))
                (substring body start (or (string-match "^--" body start) (length body))))
            body))))))

(defun org-queue-mail--message (record sent)
  "Turn mu's RECORD into the plist the core reads; SENT says which folder."
  (let* ((from (car (plist-get record :from)))
         (to (plist-get record :to))
         (date (plist-get record :date))
         (msgid (plist-get record :message-id))
         (thread (and sent (org-queue-mail--find (format "-r msgid:%s" msgid)))))
    (list :msgid msgid
          :subject (or (plist-get record :subject) "(no subject)")
          :date (and date (+ (* 65536 (nth 0 date)) (nth 1 date)))
          :from (plist-get from :email) :from-name (plist-get from :name)
          :to (mapcar (lambda (r) (plist-get r :email)) to)
          :to-name (plist-get (car to) :name)
          :body (org-queue-mail--body (plist-get record :path))
          :flagged (and (memq 'flagged (plist-get record :flags)) t)
          :sent sent
          :thread-last-mine (org-queue-mail--last-mine-p thread (plist-get from :email)))))

(defun org-queue-mail--last-mine-p (thread me)
  "Return non-nil if the newest message in THREAD is from ME (or THREAD is empty)."
  (if (null thread)
      t
    (let ((newest (car (sort (copy-sequence thread)
                             (lambda (a b)
                               (let ((da (plist-get a :date)) (db (plist-get b :date)))
                                 (> (+ (* 65536 (nth 0 da)) (nth 1 da))
                                    (+ (* 65536 (nth 0 db)) (nth 1 db)))))))))
      (or (equal (plist-get (car (plist-get newest :from)) :email) me)
          (member (plist-get (car (plist-get newest :from)) :email) org-queue-mail-addresses)))))

(defun org-queue-mail--known ()
  "Return the message IDs already in the stub."
  (when (file-readable-p (expand-file-name org-queue-mail-stub))
    (with-temp-buffer
      (insert-file-contents (expand-file-name org-queue-mail-stub))
      (let (ids)
        (goto-char (point-min))
        (while (re-search-forward "^:MSGID:[ \t]+\\(\\S-+\\)" nil t)
          (push (match-string 1) ids))
        ids))))

;;;###autoload
(defun org-queue-mail-waiting ()
  "Write the waiting-fors and the flagged mail into the archive stub."
  (interactive)
  (unless (executable-find "mu") (user-error "mu is not installed"))
  (let* ((messages (append (mapcar (lambda (r) (org-queue-mail--message r t))
                                   (org-queue-mail--find org-queue-mail-sent-query))
                           (mapcar (lambda (r) (org-queue-mail--message r nil))
                                   (org-queue-mail--find org-queue-mail-received-query))))
         (candidates (org-queue-mail-core-candidates messages (org-queue-mail--known)))
         (stub (expand-file-name org-queue-mail-stub)))
    (if (null candidates)
        (message "Nothing new in the flagged mail")
      (with-temp-buffer
        (when (file-readable-p stub) (insert-file-contents stub))
        (goto-char (point-max))
        (unless (bolp) (insert "\n"))
        (when (= (point-min) (point-max))
          (insert "#+TITLE: From the mail\n#+CATEGORY: mail\n\n"))
        (dolist (candidate candidates)
          (insert (org-queue-mail-core-entry candidate) "\n"))
        (write-region (point-min) (point-max) stub))
      (message "%d entr%s written to %s" (length candidates)
               (if (= 1 (length candidates)) "y" "ies") (file-name-nondirectory stub)))
    candidates))

(provide 'org-queue-mail)
;;; org-queue-mail.el ends here
