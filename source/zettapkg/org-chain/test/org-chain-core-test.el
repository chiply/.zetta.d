;;; org-chain-core-test.el --- ERT tests for org-chain-core -*- lexical-binding: t -*-

;;; Commentary:

;; A landing log, entries in and out of AGENT, a transition fixture for
;; two chains, no Org.  Run with:
;;
;;   emacs -Q --batch -L source/zettapkg/org-chain \
;;     -l source/zettapkg/org-chain/test/org-chain-core-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'org-chain-core)

(defun oct-entry (id state &rest properties)
  (append properties (list :id id :title id :state state :body "do the thing")))

(defconst oct-entries
  (list (oct-entry "a" "AGENT" :agent-session "S-A")
        (oct-entry "b" "AGENT" :agent-session "S-B")
        (oct-entry "c" "NEXT" :agent-session "S-C")
        (oct-entry "d" "TODO")))

(defconst oct-log
  (list (list :session "S-A" :at 1000 :cwd "/r" :event 'stop)
        (list :session "S-B" :at 1100 :cwd "/r" :event 'question :text "which branch?")
        (list :session "S-C" :at 1200 :cwd "/r" :event 'stop)      ; not in AGENT
        (list :session "S-Z" :at 1300 :cwd "/r" :event 'stop)      ; nobody's
        (list :session "S-A" :at 1000 :cwd "/r" :event 'stop)))    ; repeated


;;;; Landing

(ert-deftest oct/a-landing-transitions-agent-to-next-or-ques-once ()
  (let* ((result (org-chain-core-land oct-log oct-entries nil))
         (actions (plist-get result :actions)))
    (should (= 2 (length actions)))
    (should (equal "NEXT" (plist-get (nth 0 actions) :to)))
    (should (equal "a" (plist-get (plist-get (nth 0 actions) :task) :id)))
    (should (equal "QUES" (plist-get (nth 1 actions) :to)))
    (should (equal "b" (plist-get (plist-get (nth 1 actions) :task) :id)))
    ;; A re-read of the same log applies nothing twice.
    (let ((again (org-chain-core-land oct-log oct-entries (plist-get result :applied))))
      (should-not (plist-get again :actions))
      (should-not (plist-get again :orphans)))))

(ert-deftest oct/a-landing-nobody-owns-is-an-orphan-and-changes-nothing ()
  (let* ((result (org-chain-core-land oct-log oct-entries nil))
         (orphans (plist-get result :orphans)))
    (should (equal '("S-C" "S-Z") (mapcar (lambda (l) (plist-get l :session)) orphans)))
    (should-not (cl-find "c" (plist-get result :actions)
                         :key (lambda (a) (plist-get (plist-get a :task) :id)) :test #'equal))
    ;; The inputs are untouched.
    (should (equal "NEXT" (plist-get (nth 2 oct-entries) :state)))))


;;;; Kicking

(ert-deftest oct/the-fourth-kick-is-refused-and-c-u-overrides ()
  (let ((org-chain-limit 3)
        (three (list (oct-entry "1" "AGENT") (oct-entry "2" "AGENT") (oct-entry "3" "AGENT")))
        (fresh (oct-entry "4" "TODO")))
    (should (org-chain-core-kick-check fresh three))
    (should-not (org-chain-core-kick-check fresh three t))
    (should-not (org-chain-core-kick-check fresh (cdr three)))))

(ert-deftest oct/the-prompt-is-the-prompt-heading-else-the-body-verbatim ()
  (should (equal "do the thing" (org-chain-core-prompt (oct-entry "x" "TODO"))))
  (should (equal "  exact\n  text  "
                 (org-chain-core-prompt
                  (oct-entry "x" "TODO" :body "notes" :children '(("Prompt" . "\n  exact\n  text  \n"))))))
  (should-not (org-chain-core-prompt (oct-entry "x" "TODO" :body "   ")))
  (should (string-match-p "no prompt" (org-chain-core-kick-check (oct-entry "x" "TODO" :body "") nil))))

(ert-deftest oct/an-entry-in-flight-is-not-kicked-again ()
  (should (equal "already in flight" (org-chain-core-kick-check (oct-entry "x" "AGENT") nil))))

(ert-deftest oct/a-kick-at-entry-runs-headless-only ()
  (let ((night (oct-entry "x" "TODO" :kick-at 240))
        (plain (oct-entry "y" "TODO")))
    (should (eq 'headless (org-chain-core-kick-mode night nil)))
    (should (stringp (org-chain-core-kick-mode night t)))
    (should (eq 'interactive (org-chain-core-kick-mode plain t)))
    (should (org-chain-core-kick-due-p night 250))
    (should-not (org-chain-core-kick-due-p night 230))
    (should-not (org-chain-core-kick-due-p (oct-entry "z" "TODO" :kick-at 600) 610))))

(ert-deftest oct/the-command-carries-the-prompt-untouched ()
  (should (equal '("claude" "--session-id" "U" "fix: the  thing\n")
                 (org-chain-core-command "fix: the  thing\n" "U")))
  (should (equal '("claude" "-p" "--session-id" "U" "p")
                 (org-chain-core-command "p" "U" t))))


;;;; Metrics

(defconst oct-chain
  ;; kicked at 0, landed at 15 min, reviewed at 25, re-kicked at 45,
  ;; landed at 65, reviewed at 70, done at 90.
  '(("PROG" . 0) ("AGENT" . 600) ("NEXT" . 1500) ("PROG" . 2100)
    ("AGENT" . 3300) ("NEXT" . 4500) ("PROG" . 4800) ("DONE" . 6000)))

(ert-deftest oct/latency-review-lag-and-iterations-from-a-transition-fixture ()
  (let ((m (org-chain-core-metrics oct-chain 6000)))
    (should (= 2 (plist-get m :iterations)))
    (should (= 35 (plist-get m :machine)))    ; 15 + 20
    (should (= 50 (plist-get m :human)))      ; 10 + 20 + 20
    (should (= 18 (plist-get m :latency)))    ; (15 + 20) / 2, rounded
    (should (= 8 (plist-get m :review-lag)))  ; (10 + 5) / 2, rounded
    (should-not (plist-get m :in-flight))))

(ert-deftest oct/the-landed-predicate ()
  (should (org-chain-core-landed-p '(("PROG" . 0) ("AGENT" . 1) ("NEXT" . 2))))
  (should-not (org-chain-core-landed-p '(("TODO" . 0) ("NEXT" . 2))))
  (should-not (org-chain-core-landed-p '(("AGENT" . 1) ("QUES" . 2))))
  (should-not (org-chain-core-landed-p nil)))


;;;; The morning line

(ert-deftest oct/three-chains-exceed-a-four-hour-block-two-do-not ()
  "Fifteen minutes of latency, a twenty-minute cycle of your own."
  (let ((three (org-chain-core-expected 3 15 20 240))
        (two (org-chain-core-expected 2 15 20 240)))
    (should (plist-get three :exceeds))
    (should (= 360 (plist-get three :review)))
    (should-not (plist-get two :exceeds))
    (should (= 240 (plist-get two :review)))
    (should (= 2 (plist-get three :enough)))
    (should (string-match-p "2 would do" (org-chain-core-morning-line 3 15 20 240)))
    (should (equal "no chains in flight" (org-chain-core-morning-line 0 15 20 240)))))

(provide 'org-chain-core-test)
;;; org-chain-core-test.el ends here
