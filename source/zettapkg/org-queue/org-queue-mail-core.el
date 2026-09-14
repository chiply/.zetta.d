;;; org-queue-mail-core.el --- WAITING_ON from sent mail, arithmetic only -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, mail

;; This file is not part of GNU Emacs.

;;; Commentary:

;; A waiting-for is derived, not typed: the last message in a thread is
;; yours, it is flagged, and it ends in a question.  That is a WAIT with
;; WAITING_ON the recipient.  A flagged message someone sent you is a
;; NEXT.  A thread whose last message is theirs yields nothing: the
;; ball is with you, not them.  No mu and no Org in here: message
;; plists in, candidate plists out, and the entry text they become.
;;
;; A message plist:
;;
;;   (:msgid "..." :subject "..." :date SECONDS :from "a@b" :from-name "A"
;;    :to ("c@d") :body "..." :flagged t :sent t :thread ("msgid1" ...))
;;
;; `:thread' is the message IDs of the thread, and `:thread-last-mine'
;; whether the newest message in it is yours.

;;; Code:

(require 'cl-lib)

(defun org-queue-mail-core-last-line (body)
  "Return the last line of BODY that is neither blank, quoted nor a signature."
  (let ((lines (split-string (or body "") "\n"))
        last)
    (catch 'done
      (dolist (line lines)
        (let ((trimmed (string-trim line)))
          (cond
           ((string-match-p "\\`-- ?\\'" trimmed) (throw 'done nil))  ; the signature starts
           ((or (string-empty-p trimmed) (string-prefix-p ">" trimmed)
                (string-match-p "\\`On .* wrote:\\'" trimmed))
            nil)
           (t (setq last trimmed))))))
    last))

(defun org-queue-mail-core-question-p (body)
  "Return non-nil if BODY ends in a question."
  (when-let* ((line (org-queue-mail-core-last-line body)))
    (string-match-p "\\?[ \t]*\\'" line)))

(defun org-queue-mail-core-candidate (message)
  "Return what MESSAGE proposes, or nil.

A flagged sent message ending a thread with a question: a WAIT with
WAITING_ON its first recipient.  A flagged received message: a NEXT.
A sent message that does not ask, or a thread whose newest message is
theirs: nothing."
  (when (plist-get message :flagged)
    (cond
     ((and (plist-get message :sent)
           (plist-get message :thread-last-mine)
           (org-queue-mail-core-question-p (plist-get message :body)))
      (list :state "WAIT"
            :waiting-on (or (plist-get message :to-name) (car (plist-get message :to)))
            :subject (plist-get message :subject)
            :msgid (plist-get message :msgid)
            :date (plist-get message :date)))
     ((and (not (plist-get message :sent)))
      (list :state "NEXT"
            :subject (plist-get message :subject)
            :from (or (plist-get message :from-name) (plist-get message :from))
            :msgid (plist-get message :msgid)
            :date (plist-get message :date))))))

(defun org-queue-mail-core-candidates (messages &optional known)
  "Return the candidates MESSAGES propose, minus those whose msgid is in KNOWN."
  (delq nil
        (mapcar (lambda (message)
                  (unless (member (plist-get message :msgid) known)
                    (org-queue-mail-core-candidate message)))
                messages)))

(defun org-queue-mail-core-entry (candidate)
  "Return the Org entry text for CANDIDATE."
  (let ((date (plist-get candidate :date)))
    (concat
     (format "* %s %s\n" (plist-get candidate :state) (plist-get candidate :subject))
     ":PROPERTIES:\n"
     (format ":MSGID:    %s\n" (plist-get candidate :msgid))
     (when (plist-get candidate :waiting-on)
       (format ":WAITING_ON: %s\n" (plist-get candidate :waiting-on)))
     (format ":CREATED:  %s\n"
             (if date (format-time-string "[%Y-%m-%d %a %H:%M]" date) "[unknown]"))
     ":END:\n"
     (format "[[mu4e:msgid:%s][%s]]\n" (plist-get candidate :msgid) (plist-get candidate :subject))
     (if (plist-get candidate :from) (format "From %s.\n" (plist-get candidate :from)) ""))))

(provide 'org-queue-mail-core)
;;; org-queue-mail-core.el ends here
