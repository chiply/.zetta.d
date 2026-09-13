;;; org-decorate-core-test.el --- ERT tests for org-decorate-core -*- lexical-binding: t -*-

;;; Commentary:

;; No Org, no model: canned proposals against the closed lists.  Run with:
;;
;;   emacs -Q --batch -L source/zettapkg/org-decorate \
;;     -l source/zettapkg/org-decorate/test/org-decorate-core-test.el \
;;     -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(add-to-list 'load-path
             (file-name-directory
              (directory-file-name
               (file-name-directory
                (or load-file-name buffer-file-name)))))
(require 'org-decorate-core)

(defconst odt-lists
  '(:keywords ("TODO" "WAIT" "QUES" "HOLD" "IDEA")
    :categories ("emacs" "buy" "work" "home")
    :targets ("(todo) emacs.org" "(todo) buy.org" "(todo) work.org" "(todo) work.org::*Roadmap")
    :contexts ("@deep" "@shallow" "@errand" "@call" "@meeting" "@travel" "@social")
    :energies ("@fresh" "@tired")
    :tags ("perf" "household" "release")
    :efforts ("0" "0:05" "0:10" "0:15" "0:20" "0:30" "0:45" "1:00" "2:00")
    :impacts (1 2 3 4 5)
    :deadline-types ("hard" "soft")
    :people ("Sam" "legal")
    :wikiwords ("Hyperbole" "Python")))

(defun odt-entry (heading &rest properties)
  (append properties (list :id "E1" :heading heading :body "" :created 20260903)))

(defconst odt-good
  '(:kind "task" :keyword "TODO" :target "(todo) buy.org" :category "buy"
    :context "@errand" :effort "0:10" :why "a purchasable item"
    :confidence 0.88 :field_confidence ((kind . 0.95) (target . 0.9))))

(defun odt-resolver (phrase _created)
  "A stub resolver: a few fixed phrases."
  (pcase phrase
    ("tue" 20260908) ("tomorrow" 20260904) ("end of month" 20260930)
    ("next week" 20260907) ("yesterday" 20260902)
    ("thursday at 2pm" (cons 20260910 "14:00"))
    (_ nil)))


;;;; Validation

(ert-deftest odt/a-proposal-names-only-candidates-it-was-given ()
  (let ((v (org-decorate-core-validate
            (append '(:target "(todo) nowhere.org" :category "nope") odt-good) odt-lists)))
    (should-not (plist-get v :target))
    (should-not (plist-get v :category))
    (should (= 2 (length (plist-get v :drops))))
    (should (equal "task" (plist-get v :kind)))))

(ert-deftest odt/the-forbidden-keywords-are-rejected ()
  (dolist (keyword '("NEXT" "PROG" "DONE" "NOPE"))
    (let ((v (org-decorate-core-validate (list :kind "task" :keyword keyword) odt-lists)))
      (should-not (plist-get v :keyword))
      (should (equal "a decision, not a classification" (nth 2 (car (plist-get v :drops))))))))

(ert-deftest odt/two-contexts-keep-the-first-and-flag-it ()
  (let ((v (org-decorate-core-validate (list :kind "task" :context '("@deep" "@call")) odt-lists)))
    (should (equal "@deep" (plist-get v :context)))
    (should (plist-get v :context-flagged))
    (should (cl-some (lambda (d) (eq 'context (car d))) (plist-get v :drops)))))

(ert-deftest odt/unknown-tags-effort-impact-and-deadline-type-are-dropped ()
  (let ((v (org-decorate-core-validate
            (list :kind "task" :tags '("perf" "made-up") :effort "0:07" :impact 4
                  :deadline_type "maybe")
            odt-lists)))
    (should (equal '("perf") (plist-get v :tags)))
    (should-not (plist-get v :effort))
    (should-not (plist-get v :impact))
    (should-not (plist-get v :deadline-type))
    (should (equal '(tags effort impact deadline_type) (mapcar #'car (plist-get v :drops))))))

(ert-deftest odt/impact-needs-quoted-evidence ()
  (let ((with (org-decorate-core-validate
               (list :kind "task" :impact 4 :impact_evidence "asked me to confirm") odt-lists))
        (without (org-decorate-core-validate (list :kind "task" :impact 4) odt-lists)))
    (should (= 4 (plist-get with :impact)))
    (should-not (plist-get without :impact))))

(ert-deftest odt/more-than-three-tags-are-cut-to-three ()
  (let* ((org-decorate-max-tags 3)
         (lists (plist-put (copy-sequence odt-lists) :tags '("a" "b" "c" "d")))
         (v (org-decorate-core-validate (list :kind "note" :tags '("a" "b" "c" "d")) lists)))
    (should (equal '("a" "b" "c") (plist-get v :tags)))))

(ert-deftest odt/validation-is-total ()
  (should (plist-get (org-decorate-core-validate nil odt-lists) :drops))
  (should (plist-get (org-decorate-core-validate "garbage" odt-lists) :drops))
  (should (plist-get (org-decorate-core-validate '(1 2 3) odt-lists) :drops)))


;;;; Dates

(ert-deftest odt/phrases-resolve-against-created-not-now ()
  (let* ((v (org-decorate-core-validate
             (list :kind "task" :deadline_phrase "tue" :scheduled_phrase "tomorrow") odt-lists))
         (r (org-decorate-core-resolve-dates v #'odt-resolver 20260903)))
    (should (= 20260908 (plist-get r :deadline)))
    (should (= 20260904 (plist-get r :scheduled)))))

(ert-deftest odt/an-unparsable-phrase-is-dropped-with-a-reason ()
  (let* ((v (org-decorate-core-validate (list :kind "task" :deadline_phrase "whenever") odt-lists))
         (r (org-decorate-core-resolve-dates v #'odt-resolver 20260903)))
    (should-not (plist-get r :deadline))
    (should (equal "does not parse as a date" (nth 2 (car (plist-get r :drops)))))))

(ert-deftest odt/a-date-already-past-is-kept-and-marked-stale ()
  (let* ((v (org-decorate-core-validate (list :kind "task" :deadline_phrase "yesterday") odt-lists))
         (r (org-decorate-core-resolve-dates v #'odt-resolver 20260903 20260912)))
    (should (= 20260902 (plist-get r :deadline)))
    (should (plist-get r :date-stale))))


;;;; The resolver, against Thursday 2026-09-03

(ert-deftest odt/the-resolver-reads-the-catalogue-phrases ()
  (let ((base 20260903))
    (should (= 20260908 (org-decorate-core-resolve-phrase "tue" base)))
    (should (= 20260908 (org-decorate-core-resolve-phrase "next Tuesday" base)))
    (should (= 20260904 (org-decorate-core-resolve-phrase "tomorrow" base)))
    (should (= 20260930 (org-decorate-core-resolve-phrase "end of month" base)))
    (should (= 20260907 (org-decorate-core-resolve-phrase "next week" base)))
    (should (= 20260910 (org-decorate-core-resolve-phrase "thursday" base)))   ; strictly after
    (should (= 20260904 (org-decorate-core-resolve-phrase "by Friday" base)))
    (should (= 20260905 (org-decorate-core-resolve-phrase "+2d" base)))
    (should (= 20260924 (org-decorate-core-resolve-phrase "in 3 weeks" base)))
    (should (= 20261001 (org-decorate-core-resolve-phrase "2026-10-01" base)))
    (should (= 20260910 (org-decorate-core-resolve-phrase "Sep 10" base)))
    (should (= 20270110 (org-decorate-core-resolve-phrase "10 January" base)))
    (should (equal (cons 20260910 "14:00") (org-decorate-core-resolve-phrase "Thursday at 2pm" base)))
    (should (equal (cons 20260904 "09:30") (org-decorate-core-resolve-phrase "tomorrow 9:30am" base)))
    (should-not (org-decorate-core-resolve-phrase "whenever" base))
    (should-not (org-decorate-core-resolve-phrase "" base))))

;;;; Merge

(ert-deftest odt/the-merge-writes-ai-properties-and-never-a-canonical-one ()
  (let* ((entry (odt-entry "dryer sheets"))
         (writes (org-decorate-core-merge
                  entry (org-decorate-core-validate odt-good odt-lists) "[stamp] m prompt=1 schema=1")))
    (should (cl-every (lambda (cell) (string-prefix-p "AI_" (car cell))) writes))
    (should (equal "TODO" (cdr (assoc "AI_KEYWORD" writes))))
    (should (equal "(todo) buy.org" (cdr (assoc "AI_TARGET" writes))))
    (should (equal "0:10" (cdr (assoc "AI_EFFORT" writes))))
    (should (assoc "AI_HASH" writes))
    (should (string-match-p "kind=0.95" (cdr (assoc "AI_CONFIDENCE" writes))))))

(ert-deftest odt/a-canonical-field-present-is-recorded-but-named-in-why ()
  (let* ((entry (odt-entry "the recruiter: Re: loop" :state "TODO" :effort 30))
         (writes (org-decorate-core-merge
                  entry (org-decorate-core-validate (append '(:keyword "QUES" :effort "0:30") odt-good)
                                                    odt-lists)
                  "[stamp]")))
    (should (equal "QUES" (cdr (assoc "AI_KEYWORD" writes))))
    (should (string-match-p "keyword already set" (cdr (assoc "AI_WHY" writes))))
    (should (string-match-p "Effort already set" (cdr (assoc "AI_WHY" writes))))))

(ert-deftest odt/drops-are-written-into-why ()
  (let* ((writes (org-decorate-core-merge
                  (odt-entry "x")
                  (org-decorate-core-validate (append '(:category "nope") odt-good) odt-lists)
                  "[stamp]")))
    (should (string-match-p "dropped category \"nope\"" (cdr (assoc "AI_WHY" writes))))))


;;;; The plan and idempotence

(ert-deftest odt/a-fresh-entry-yields-an-empty-plan-a-changed-hash-a-full-one ()
  (let* ((entry (odt-entry "dryer sheets"))
         (writes (org-decorate-core-plan entry odt-good odt-lists "[s] m prompt=1 schema=1"))
         (decorated (plist-put (copy-sequence entry) :properties writes)))
    (should writes)
    (should-not (org-decorate-core-plan decorated odt-good odt-lists "[s] m prompt=1 schema=1"))
    (let ((edited (plist-put (copy-sequence decorated) :heading "dryer sheets, the good ones")))
      (should (org-decorate-core-plan edited odt-good odt-lists "[s] m prompt=1 schema=1")))))

(ert-deftest odt/a-rejection-under-the-same-prompt-is-not-re-proposed ()
  (let ((rejected (odt-entry "x" :properties '(("AI_REJECTED" . "[stamp] prompt=1")))))
    (should-not (org-decorate-core-stale-p rejected 1 1))
    (should (org-decorate-core-stale-p rejected 2 1))))

(ert-deftest odt/a-private-entry-yields-a-plan-that-sends-nothing ()
  (should-not (org-decorate-core-plan (odt-entry "secret" :private t) odt-good odt-lists "[s]")))

(ert-deftest odt/garbage-produces-no-writes-and-an-error-line ()
  (let ((plan (org-decorate-core-plan (odt-entry "x") "garbage" odt-lists "[s]")))
    (should (plist-get plan :error))
    (should-not (assoc "AI_HASH" plan)))
  (let ((plan (org-decorate-core-plan (odt-entry "x") '(:kind "nope" :keyword "DONE") odt-lists "[s]")))
    (should (plist-get plan :error))))


;;;; Accept and reject

(ert-deftest odt/accepting-writes-the-real-fields-and-strips-every-ai-property ()
  (let* ((entry (odt-entry "dryer sheets"
                           :properties '(("AI_KIND" . "task") ("AI_KEYWORD" . "TODO")
                                         ("AI_TARGET" . "(todo) buy.org") ("AI_CONTEXT" . "@errand")
                                         ("AI_EFFORT" . "0:10") ("AI_DEADLINE" . "2026-09-11")
                                         ("AI_DEADLINE_TYPE" . "soft") ("AI_RELATED" . "Hyperbole id:X")
                                         ("AI_WHY" . "w") ("AI_HASH" . "h") ("AI_STAMP" . "s"))))
         (actions (org-decorate-core-accept-actions entry))
         (kinds (mapcar (lambda (a) (plist-get a :action)) actions)))
    (should (equal '(state tag property deadline property body-line) (seq-take kinds 6)))
    (should (equal "TODO" (plist-get (nth 0 actions) :to)))
    (should (= 20260911 (plist-get (nth 3 actions) :to)))
    (should (equal "Related: [[hy:Hyperbole]] [[id:X]]" (plist-get (nth 5 actions) :text)))
    ;; Every AI_ property is stripped, and the refile comes last.
    (should (= 11 (cl-count-if (lambda (a) (and (eq (plist-get a :action) 'property)
                                                (null (plist-get a :value))))
                               actions)))
    (should (eq 'refile (plist-get (car (last actions)) :action)))
    (should (equal "(todo) buy.org" (plist-get (car (last actions)) :to)))))

(ert-deftest odt/a-heading-target-refiles-under-the-heading ()
  (let* ((entry (odt-entry "x" :properties '(("AI_TARGET" . "(todo) work.org::*Roadmap"))))
         (refile (car (last (org-decorate-core-accept-actions entry)))))
    (should (equal "(todo) work.org" (plist-get refile :to)))
    (should (equal "Roadmap" (plist-get refile :heading)))))

(ert-deftest odt/an-entry-with-a-real-field-never-gets-it-overwritten ()
  (let* ((entry (odt-entry "x" :state "TODO" :effort 30
                           :properties '(("AI_KEYWORD" . "QUES") ("AI_EFFORT" . "1:00"))))
         (actions (org-decorate-core-accept-actions entry)))
    (should-not (cl-find 'state actions :key (lambda (a) (plist-get a :action))))
    (should-not (cl-find "Effort" actions :key (lambda (a) (plist-get a :name)) :test #'equal))))

(ert-deftest odt/rejecting-strips-only ()
  (let ((actions (org-decorate-core-strip-actions
                  (odt-entry "x" :properties '(("AI_KIND" . "task") ("AI_HASH" . "h") ("Effort" . "0:10"))))))
    (should (= 2 (length actions)))
    (should (cl-every (lambda (a) (and (eq 'property (plist-get a :action)) (null (plist-get a :value))))
                      actions))))

(ert-deftest odt/accepting-one-field-promotes-that-field-and-strips-all ()
  (let* ((entry (odt-entry "x" :properties '(("AI_KEYWORD" . "TODO") ("AI_EFFORT" . "0:10") ("AI_HASH" . "h"))))
         (actions (org-decorate-core-accept-actions entry '("AI_EFFORT"))))
    (should (equal "Effort" (plist-get (car actions) :name)))
    (should-not (cl-find 'state actions :key (lambda (a) (plist-get a :action))))
    (should (= 3 (cl-count-if (lambda (a) (null (plist-get a :value))) actions)))))

(ert-deftest odt/a-correction-is-a-training-example ()
  (let* ((entry (odt-entry "x" :properties '(("AI_KIND" . "note") ("AI_EFFORT" . "0:10") ("AI_HASH" . "h"))))
         (corrections (org-decorate-core-corrections entry '(("AI_KIND" . "task") ("AI_EFFORT" . "0:10")))))
    (should (= 1 (length corrections)))
    (should (equal "note" (plist-get (car corrections) :proposed)))
    (should (equal "task" (plist-get (car corrections) :corrected)))))


;;;; Duplicates

(ert-deftest odt/a-duplicate-needs-two-signals ()
  (let ((entry (odt-entry "Buy dryer sheets" :backlink "mu4e:abc")))
    ;; Exact normalised text plus a high score.
    (should (org-decorate-core-duplicate
             entry (list (list :id "old" :title "buy dryer sheets." :score 0.9))))
    ;; The same backlink plus a high score.
    (should (org-decorate-core-duplicate
             entry (list (list :id "old" :title "different words" :score 0.9 :backlink "mu4e:abc"))))
    ;; A high score alone is related, not a duplicate.
    (should-not (org-decorate-core-duplicate
                 entry (list (list :id "old" :title "different words" :score 0.9))))
    ;; Shared words alone are nothing.
    (should-not (org-decorate-core-duplicate
                 entry (list (list :id "old" :title "buy dryer sheets" :score 0.4))))))

(ert-deftest odt/a-match-against-a-finished-entry-is-not-a-duplicate ()
  (should-not (org-decorate-core-duplicate
               (odt-entry "Buy dryer sheets")
               (list (list :id "old" :title "Buy dryer sheets" :score 0.95 :done t)))))

(ert-deftest odt/related-neighbours-are-sorted-and-exclude-the-duplicate ()
  (let* ((entry (odt-entry "x"))
         (related (org-decorate-core-related
                   entry (list (list :id "a" :title "x" :score 0.9)
                               (list :id "b" :title "y" :score 0.7)
                               (list :id "c" :title "z" :score 0.8)
                               (list :id "d" :title "w" :score 0.1)))))
    (should (equal '("c" "b") (mapcar (lambda (n) (plist-get n :id)) related)))))


;;;; Commit evidence

(ert-deftest odt/a-commit-naming-an-id-is-evidence-once ()
  (let* ((commits (list (list :sha "aaa" :message "fix: thing\n\nCloses ID-1")
                        (list :sha "bbb" :message "another mentioning ID-1")
                        (list :sha "ccc" :message "nothing")))
         (evidence (org-decorate-core-commit-evidence commits '("ID-1" "ID-2"))))
    (should (equal '(("ID-1" . "aaa")) evidence))
    (should (equal evidence (org-decorate-core-commit-evidence commits '("ID-1" "ID-2"))))))

(provide 'org-decorate-core-test)
;;; org-decorate-core-test.el ends here
