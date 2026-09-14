;;; org-queue-mail-test.el --- ERT tests for the sent-mail reader core -*- lexical-binding: t -*-

;;; Commentary:

;; Message plists shaped like a maildir thread, no mu, no Org.  Run with:
;;
;;   emacs -Q --batch -L source/zettapkg/org-queue \
;;     -l source/zettapkg/org-queue/test/org-queue-mail-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'org-queue-mail-core)

(defconst oqm-sent-question
  (list :msgid "q1@me" :subject "Re: the contract" :date 1789000000
        :from "me@example.com" :to '("legal@example.com") :to-name "Legal"
        :body "Thanks for the draft.\n\nCould you confirm the indemnity clause by Friday?\n\n-- \nCharlie\n> earlier\n"
        :flagged t :sent t :thread-last-mine t))

(defconst oqm-sent-statement
  (list :msgid "s1@me" :subject "Re: the invoice" :date 1789000100
        :from "me@example.com" :to '("vendor@example.com")
        :body "Paid today.\n" :flagged t :sent t :thread-last-mine t))

(defconst oqm-sent-answered
  (list :msgid "a1@me" :subject "Re: the dates" :date 1789000200
        :from "me@example.com" :to '("sam@example.com")
        :body "Which dates work for you?\n" :flagged t :sent t :thread-last-mine nil))

(defconst oqm-received
  (list :msgid "r1@them" :subject "Please review the deck" :date 1789000300
        :from "priya@example.com" :from-name "Priya" :to '("me@example.com")
        :body "Can you look at this?\n" :flagged t :sent nil))

(defconst oqm-unflagged
  (list :msgid "u1@me" :subject "Re: lunch" :date 1789000400
        :from "me@example.com" :to '("sam@example.com")
        :body "Tuesday?\n" :flagged nil :sent t :thread-last-mine t))

(ert-deftest oqm/the-last-line-skips-quotes-and-the-signature ()
  (should (equal "Could you confirm the indemnity clause by Friday?"
                 (org-queue-mail-core-last-line (plist-get oqm-sent-question :body))))
  (should (org-queue-mail-core-question-p (plist-get oqm-sent-question :body)))
  (should-not (org-queue-mail-core-question-p "Paid today.\n\n> did you pay?\n")))

(ert-deftest oqm/a-flagged-sent-message-ending-in-a-question-is-a-wait-on-the-recipient ()
  (let ((candidate (org-queue-mail-core-candidate oqm-sent-question)))
    (should (equal "WAIT" (plist-get candidate :state)))
    (should (equal "Legal" (plist-get candidate :waiting-on)))
    (should (equal "q1@me" (plist-get candidate :msgid)))))

(ert-deftest oqm/a-flagged-received-message-is-a-next ()
  (let ((candidate (org-queue-mail-core-candidate oqm-received)))
    (should (equal "NEXT" (plist-get candidate :state)))
    (should (equal "Priya" (plist-get candidate :from)))))

(ert-deftest oqm/a-statement-an-answered-thread-and-an-unflagged-message-yield-nothing ()
  (should-not (org-queue-mail-core-candidate oqm-sent-statement))
  (should-not (org-queue-mail-core-candidate oqm-sent-answered))
  (should-not (org-queue-mail-core-candidate oqm-unflagged)))

(ert-deftest oqm/known-message-ids-are-skipped ()
  (let ((candidates (org-queue-mail-core-candidates
                     (list oqm-sent-question oqm-received oqm-sent-statement)
                     '("q1@me"))))
    (should (equal '("r1@them") (mapcar (lambda (c) (plist-get c :msgid)) candidates)))))

(ert-deftest oqm/the-entry-carries-the-link-the-property-and-the-recipient ()
  (let ((text (org-queue-mail-core-entry (org-queue-mail-core-candidate oqm-sent-question))))
    (should (string-prefix-p "* WAIT Re: the contract\n" text))
    (should (string-match-p "^:MSGID:    q1@me$" text))
    (should (string-match-p "^:WAITING_ON: Legal$" text))
    (should (string-match-p "\\[\\[mu4e:msgid:q1@me\\]\\[Re: the contract\\]\\]" text))))

(provide 'org-queue-mail-test)
;;; org-queue-mail-test.el ends here
