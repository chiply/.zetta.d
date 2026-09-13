;;; org-decorate-core.el --- Validate, merge and promote inbox proposals -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, outlines

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Decoration is classification of a raw inbox entry against lists that
;; already exist in the config, plus what the text says (dates, people)
;; and what the kb already holds (neighbours, duplicates).  The person
;; writes the words and decides commitment or option; the model sorts
;; against a dozen known labels.  This file is the arithmetic of that
;; contract (productivity.org 3.6), with no Org and no model in it:
;;
;;   validate   a proposal against the closed lists; anything outside a
;;              list is dropped and the drop is recorded in AI_WHY
;;   merge      a validated proposal with the entry: AI_* property
;;              writes only, never a canonical field, never the heading
;;   accept     AI_* properties into apply-layer actions that write the
;;              real fields and strip the proposals in one transaction
;;   duplicate  the two-signal rule: a duplicate needs a high similarity
;;              AND (exact normalised text OR the same backlink)
;;   evidence   a commit message carrying an entry's ID
;;
;; An entry plist:
;;
;;   (:id "..." :heading "dryer sheets" :body "" :created 20260814
;;    :state nil :tags () :effort nil :impact nil :scheduled nil
;;    :deadline nil :deadline-type nil :waiting-on nil :backlink nil
;;    :private nil :properties (("AI_HASH" . "...") ...))
;;
;; A proposal plist, the model's answer after JSON decoding:
;;
;;   (:kind "task" :keyword "TODO" :target "(todo) buy.org"
;;    :category "buy" :context "@errand" :energy nil :tags ("household")
;;    :effort "0:10" :impact nil :impact_evidence nil
;;    :scheduled_phrase nil :deadline_phrase "by Friday"
;;    :deadline_type "hard" :timestamp_phrase nil :waiting_on nil
;;    :related ("WikiWord") :why "..." :confidence 0.88
;;    :field_confidence ((kind . 0.95) ...))
;;
;; The lists plist:
;;
;;   (:keywords ("TODO" "WAIT" "QUES" "HOLD" "IDEA") :categories (...)
;;    :targets ("(todo) buy.org" "(todo) emacs.org::*Project" ...)
;;    :contexts ("@deep" ...) :energies ("@fresh" "@tired") :tags (...)
;;    :efforts ("0 " "0:05" ...) :impacts (1 2 3 4 5)
;;    :deadline-types ("hard" "soft") :people (...) :wikiwords (...))

;;; Code:

(require 'cl-lib)

(defgroup org-decorate nil
  "AI decoration of the inbox."
  :group 'org
  :prefix "org-decorate-")

(defconst org-decorate-prompt-version 1
  "Bumped whenever prompt.org changes; part of the idempotence key.")

(defconst org-decorate-schema-version 1
  "Bumped whenever the response schema changes; part of the idempotence key.")

(defconst org-decorate-kinds
  '("task" "note" "question" "event" "reference" "habit-candidate" "waiting" "delegate")
  "What an entry can be.")

(defconst org-decorate-forbidden-keywords '("NEXT" "PROG" "DONE" "NOPE")
  "States a model may never propose: each is a decision a person makes.")

(defcustom org-decorate-max-tags 3
  "Most topical tags a proposal may carry."
  :type 'integer
  :group 'org-decorate)

(defcustom org-decorate-duplicate-threshold 0.85
  "Similarity above which a neighbour may be a duplicate, given a second signal."
  :type 'float
  :group 'org-decorate)

(defcustom org-decorate-related-threshold 0.6
  "Similarity above which a neighbour is worth listing as related."
  :type 'float
  :group 'org-decorate)

(defconst org-decorate-property-names
  '("AI_KIND" "AI_KEYWORD" "AI_TARGET" "AI_CATEGORY" "AI_CONTEXT" "AI_ENERGY"
    "AI_TAGS" "AI_EFFORT" "AI_IMPACT" "AI_SCHEDULED" "AI_DEADLINE"
    "AI_DEADLINE_TYPE" "AI_TIMESTAMP" "AI_WAITING_ON" "AI_RELATED"
    "AI_DUPLICATE_OF" "AI_WHY" "AI_CONFIDENCE" "AI_STAMP" "AI_HASH"
    "AI_DATE_STALE" "AI_REPO" "AI_REJECTED" "AI_PROBLEM")
  "Every property decoration may write.  Stripping removes exactly these.")


;;;; Hashing and idempotence

(defun org-decorate-core-hash (heading body)
  "Return the content hash of HEADING and BODY."
  (sha1 (concat (or heading "") "\n" (or body ""))))

(defun org-decorate-core-property (entry name)
  "Return ENTRY's property NAME, or nil."
  (cdr (assoc name (plist-get entry :properties))))

(defun org-decorate-core-stale-p (entry &optional prompt-version schema-version)
  "Return non-nil if ENTRY needs decorating.

Fresh when it carries AI_HASH equal to its content hash and a stamp
naming the current PROMPT-VERSION and SCHEMA-VERSION; also fresh when
AI_REJECTED names the current prompt version, so a rejection is not
re-proposed under the same prompt.  A private entry is never stale."
  (let* ((prompt (or prompt-version org-decorate-prompt-version))
         (schema (or schema-version org-decorate-schema-version))
         (hash (org-decorate-core-hash (plist-get entry :heading) (plist-get entry :body)))
         (stamp (or (org-decorate-core-property entry "AI_STAMP") ""))
         (rejected (org-decorate-core-property entry "AI_REJECTED")))
    (cond
     ((plist-get entry :private) nil)
     ((and rejected (string-match-p (format "prompt=%d\\b" prompt) rejected)) nil)
     ((and (equal hash (org-decorate-core-property entry "AI_HASH"))
           (string-match-p (format "prompt=%d\\b" prompt) stamp)
           (string-match-p (format "schema=%d\\b" schema) stamp))
      nil)
     (t t))))


;;;; Validation

(defun org-decorate-core--in (value list)
  "Return VALUE when it is in LIST (by `equal'), else nil."
  (and value (member value list) value))

(defun org-decorate-core--confidence (proposal field)
  "Return PROPOSAL's confidence in FIELD, 0.0 when unknown."
  (or (alist-get field (plist-get proposal :field_confidence)) 0.0))

(defun org-decorate-core-validate (proposal lists)
  "Return PROPOSAL checked against LISTS, with `:drops' naming what fell.

Total: no input signals.  A proposal that is not a plist yields a
proposal with nothing in it and one drop, `garbage'.  Each drop is
\(FIELD VALUE REASON)."
  (if (or (null proposal) (not (listp proposal)) (not (keywordp (car proposal))))
      (list :drops (list (list 'proposal proposal "not a proposal")))
    (let (drops out)
      (cl-flet ((keep (field value) (setq out (plist-put out field value)))
                (drop (field value why) (push (list field value why) drops)))
        ;; kind
        (let ((kind (plist-get proposal :kind)))
          (if (org-decorate-core--in kind org-decorate-kinds)
              (keep :kind kind)
            (when kind (drop 'kind kind "unknown kind"))))
        ;; keyword: from the closed list, never the forbidden four
        (let ((keyword (plist-get proposal :keyword)))
          (cond
           ((or (null keyword) (equal keyword "none")) nil)
           ((member keyword org-decorate-forbidden-keywords)
            (drop 'keyword keyword "a decision, not a classification"))
           ((org-decorate-core--in keyword (plist-get lists :keywords))
            (keep :keyword keyword))
           (t (drop 'keyword keyword "not a keyword in this config"))))
        ;; target and category
        (let ((target (plist-get proposal :target)))
          (when target
            (if (org-decorate-core--in target (plist-get lists :targets))
                (keep :target target)
              (drop 'target target "not a refile target"))))
        (let ((category (plist-get proposal :category)))
          (when category
            (if (org-decorate-core--in category (plist-get lists :categories))
                (keep :category category)
              (drop 'category category "not a category in the agenda files"))))
        ;; context: at most one from the group; two keep the more confident
        (let ((contexts (let ((raw (plist-get proposal :context)))
                          (cond ((null raw) nil)
                                ((equal raw "none") nil)
                                ((listp raw) raw)
                                (t (list raw))))))
          (let ((valid (cl-remove-if-not
                        (lambda (c) (member c (plist-get lists :contexts))) contexts)))
            (dolist (c contexts)
              (unless (member c valid) (drop 'context c "not a context tag")))
            (when (> (length valid) 1)
              (drop 'context (cdr valid) "more than one context; kept the first, flagged"))
            (when valid
              (keep :context (car valid))
              (when (> (length valid) 1) (keep :context-flagged t)))))
        ;; energy
        (let ((energy (plist-get proposal :energy)))
          (cond ((or (null energy) (equal energy "none")) nil)
                ((org-decorate-core--in energy (plist-get lists :energies))
                 (keep :energy energy))
                (t (drop 'energy energy "not an energy tag"))))
        ;; topical tags: must exist, at most N
        (let* ((tags (let ((raw (plist-get proposal :tags)))
                       (cond ((null raw) nil)
                             ((stringp raw) (split-string raw "[ ,]+" t))
                             (t raw))))
               (known (cl-remove-if-not
                       (lambda (tag) (member tag (plist-get lists :tags))) tags)))
          (dolist (tag tags)
            (unless (member tag known) (drop 'tags tag "not a tag in the corpus")))
          (when (> (length known) org-decorate-max-tags)
            (drop 'tags (nthcdr org-decorate-max-tags known)
                  (format "more than %d topical tags" org-decorate-max-tags))
            (setq known (seq-take known org-decorate-max-tags)))
          (when known (keep :tags known)))
        ;; effort: a rung of Effort_ALL
        (let ((effort (plist-get proposal :effort)))
          (when effort
            (if (org-decorate-core--in effort (plist-get lists :efforts))
                (keep :effort effort)
              (drop 'effort effort "not a rung of Effort_ALL"))))
        ;; impact: 1-5, only with evidence
        (let ((impact (plist-get proposal :impact))
              (evidence (plist-get proposal :impact_evidence)))
          (when impact
            (cond
             ((not (and (integerp impact) (<= 1 impact 5)))
              (drop 'impact impact "outside 1-5"))
             ((not (and (stringp evidence) (not (string-empty-p (string-trim evidence)))))
              (drop 'impact impact "no evidence quoted"))
             (t (keep :impact impact) (keep :impact-evidence evidence)))))
        ;; deadline type
        (let ((type (plist-get proposal :deadline_type)))
          (when type
            (if (org-decorate-core--in type (plist-get lists :deadline-types))
                (keep :deadline-type type)
              (drop 'deadline_type type "neither hard nor soft"))))
        ;; phrases, people and related: carried through for the shell
        (dolist (field '(:scheduled_phrase :deadline_phrase :timestamp_phrase))
          (when-let* ((phrase (plist-get proposal field)))
            (when (and (stringp phrase) (not (string-empty-p phrase)))
              (keep field phrase))))
        (when-let* ((who (plist-get proposal :waiting_on)))
          (when (and (stringp who) (not (string-empty-p who)))
            (keep :waiting-on who)))
        (let ((related (plist-get proposal :related)))
          (when related
            (keep :related (cl-remove-if-not
                            (lambda (r) (or (member r (plist-get lists :wikiwords))
                                            (string-match-p "\\`\\(id\\|file\\):" r)))
                            (if (stringp related) (list related) related)))))
        (when-let* ((repo (plist-get proposal :repo)))
          (keep :repo repo))
        (keep :why (or (plist-get proposal :why) ""))
        (keep :confidence (or (plist-get proposal :confidence) 0.0))
        (keep :field_confidence (plist-get proposal :field_confidence))
        (keep :drops (nreverse drops)))
      out)))


;;;; Dates
;;
;; `org-read-date' resolves a weekday name against the current date and
;; ignores the base time it is handed, and it does not read "tomorrow"
;; or "end of month" at all -- measured on Org 9.8, so the contract's
;; "pin whichever org-read-date gives" pins this instead: a small
;; resolver over the phrase forms the prompt allows, anchored on the
;; entry's CREATED, deterministic, and tested in batch.

(defconst org-decorate-core--weekdays
  '(("sun" . 0) ("mon" . 1) ("tue" . 2) ("wed" . 3) ("thu" . 4) ("fri" . 5) ("sat" . 6)))

(defconst org-decorate-core--months
  '(("jan" . 1) ("feb" . 2) ("mar" . 3) ("apr" . 4) ("may" . 5) ("jun" . 6)
    ("jul" . 7) ("aug" . 8) ("sep" . 9) ("oct" . 10) ("nov" . 11) ("dec" . 12)))

(defun org-decorate-core--day-number (date)
  "Days since the epoch for DATE, a YYYYMMDD integer (civil algorithm)."
  (let* ((y (/ date 10000)) (m (% (/ date 100) 100)) (d (% date 100))
         (y (if (<= m 2) (1- y) y))
         (era (/ (if (>= y 0) y (- y 399)) 400))
         (yoe (- y (* era 400)))
         (doy (+ (/ (+ (* 153 (+ m (if (> m 2) -3 9))) 2) 5) (1- d)))
         (doe (+ (* yoe 365) (/ yoe 4) (- (/ yoe 100)) doy)))
    (+ (* era 146097) doe -719468)))

(defun org-decorate-core--date-from-day-number (days)
  "The YYYYMMDD integer DAYS after the epoch."
  (let* ((z (+ days 719468))
         (era (/ (if (>= z 0) z (- z 146096)) 146097))
         (doe (- z (* era 146097)))
         (yoe (/ (- doe (/ doe 1460) (- (/ doe 36524)) (/ doe 146096)) 365))
         (y (+ yoe (* era 400)))
         (doy (- doe (- (+ (* 365 yoe) (/ yoe 4)) (/ yoe 100))))
         (mp (/ (+ (* 5 doy) 2) 153))
         (d (1+ (- doy (/ (+ (* 153 mp) 2) 5))))
         (m (if (< mp 10) (+ mp 3) (- mp 9)))
         (y (if (<= m 2) (1+ y) y)))
    (+ (* y 10000) (* m 100) d)))

(defun org-decorate-core--add-days (date days)
  (org-decorate-core--date-from-day-number (+ (org-decorate-core--day-number date) days)))

(defun org-decorate-core--weekday (date)
  (mod (+ 4 (org-decorate-core--day-number date)) 7))

(defun org-decorate-core--month-end (date)
  "The last day of DATE's month."
  (let* ((y (/ date 10000)) (m (% (/ date 100) 100))
         (next (if (= m 12) (+ (* (1+ y) 10000) 100 1) (+ (* y 10000) (* (1+ m) 100) 1))))
    (org-decorate-core--add-days next -1)))

(defun org-decorate-core--time-of-day (text)
  "Return (HH . MM) named in TEXT, or nil.  \"2pm\", \"14:00\", \"9:30am\"."
  (cond
   ((string-match "\\b\\([0-9]\\{1,2\\}\\)\\(?::\\([0-9]\\{2\\}\\)\\)?[ ]?\\([ap]\\)\\.?m\\b" text)
    (let ((h (string-to-number (match-string 1 text)))
          (m (if (match-string 2 text) (string-to-number (match-string 2 text)) 0))
          (pm (equal (match-string 3 text) "p")))
      (cons (cond ((and pm (< h 12)) (+ h 12)) ((and (not pm) (= h 12)) 0) (t h)) m)))
   ((string-match "\\b\\([0-9]\\{1,2\\}\\):\\([0-9]\\{2\\}\\)\\b" text)
    (cons (string-to-number (match-string 1 text)) (string-to-number (match-string 2 text))))))

(defun org-decorate-core-resolve-phrase (phrase base)
  "Resolve PHRASE, a date phrase, against BASE, a YYYYMMDD integer.

Returns a YYYYMMDD integer, (YYYYMMDD . \"HH:MM\") when the phrase
names a time, or nil when it does not parse.  A weekday name means
the next such day strictly after BASE, as Org reads it; \"next
week\" is the coming Monday; \"end of month\" the last day of BASE's
month; \"+2d\", \"in 3 weeks\", \"tomorrow\", \"today\", ISO dates and
\"Sep 10\" / \"10 September\" as written."
  (when (and (stringp phrase) base)
    (let* ((text (downcase (string-trim phrase)))
           (text (replace-regexp-in-string
                  "\\`\\(by\\|on\\|before\\|until\\|due\\|around\\|for\\)[ \\t]+" "" text))
           (time (org-decorate-core--time-of-day text))
           (text (replace-regexp-in-string
                  "\\(?:[ ,]*\\bat\\)?[ ]*\\b[0-9]\\{1,2\\}\\(?::[0-9]\\{2\\}\\)?[ ]?[ap]\\.?m\\b" "" text))
           (text (replace-regexp-in-string
                  "\\(?:[ ,]*\\bat\\)?[ ]*\\b[0-9]\\{1,2\\}:[0-9]\\{2\\}\\b" "" text))
           (text (string-trim (replace-regexp-in-string "[ ,]+\\'" "" text)))
           (date
            (cond
             ((member text '("today" "now")) base)
             ((equal text "tomorrow") (org-decorate-core--add-days base 1))
             ((equal text "yesterday") (org-decorate-core--add-days base -1))
             ((member text '("end of month" "end of the month" "month end"))
              (org-decorate-core--month-end base))
             ((member text '("next week" "week"))
              (org-decorate-core--add-days base (- 8 (let ((w (org-decorate-core--weekday base)))
                                                        (if (= w 0) 7 w)))))
             ((string-match "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)" text)
              (+ (* 10000 (string-to-number (match-string 1 text)))
                 (* 100 (string-to-number (match-string 2 text)))
                 (string-to-number (match-string 3 text))))
             ((string-match "\\`\\(?:next[ ]+\\)?\\([a-z]\\{3\\}\\)[a-z]*\\'" text)
              (when-let* ((target (alist-get (match-string 1 text) org-decorate-core--weekdays
                                             nil nil #'equal)))
                (let ((ahead (mod (- target (org-decorate-core--weekday base)) 7)))
                  (org-decorate-core--add-days base (if (zerop ahead) 7 ahead)))))
             ((string-match "\\`\\(?:\\+\\|in \\)\\([0-9]+\\) ?\\(d\\|day\\|days\\|w\\|week\\|weeks\\|m\\|month\\|months\\)\\'" text)
              (let ((n (string-to-number (match-string 1 text)))
                    (unit (substring (match-string 2 text) 0 1)))
                (pcase unit
                  ("d" (org-decorate-core--add-days base n))
                  ("w" (org-decorate-core--add-days base (* 7 n)))
                  ("m" (let* ((y (/ base 10000)) (mo (+ (% (/ base 100) 100) n))
                              (y (+ y (/ (1- mo) 12))) (mo (1+ (mod (1- mo) 12))))
                         (+ (* y 10000) (* mo 100) (min (% base 100) 28)))))))
             ((string-match "\\`\\([a-z]\\{3\\}\\)[a-z]* \\([0-9]\\{1,2\\}\\)\\(?:st\\|nd\\|rd\\|th\\)?\\(?:,? \\([0-9]\\{4\\}\\)\\)?\\'" text)
              (when-let* ((month (alist-get (match-string 1 text) org-decorate-core--months
                                            nil nil #'equal)))
                (org-decorate-core--month-day base month (string-to-number (match-string 2 text))
                                              (and (match-string 3 text)
                                                   (string-to-number (match-string 3 text))))))
             ((string-match "\\`\\([0-9]\\{1,2\\}\\)\\(?:st\\|nd\\|rd\\|th\\)? \\([a-z]\\{3\\}\\)[a-z]*\\(?:,? \\([0-9]\\{4\\}\\)\\)?\\'" text)
              (when-let* ((month (alist-get (match-string 2 text) org-decorate-core--months
                                            nil nil #'equal)))
                (org-decorate-core--month-day base month (string-to-number (match-string 1 text))
                                              (and (match-string 3 text)
                                                   (string-to-number (match-string 3 text)))))))))
      (when date
        (if time (cons date (format "%02d:%02d" (car time) (cdr time))) date)))))

(defun org-decorate-core--month-day (base month day &optional year)
  "The date MONTH DAY, in YEAR or the first such date on or after BASE."
  (if year
      (+ (* year 10000) (* month 100) day)
    (let* ((y (/ base 10000))
           (candidate (+ (* y 10000) (* month 100) day)))
      (if (< candidate base) (+ candidate 10000) candidate))))

(defun org-decorate-core-resolve-dates (validated resolver created &optional now)
  "Resolve the phrases in VALIDATED with RESOLVER against CREATED.

RESOLVER is a function of (PHRASE BASE-DATE) returning a YYYYMMDD
integer or nil; the shell passes one built on `org-read-date'.  A
resolved date before NOW is kept and marked `:date-stale'; a phrase
that does not parse is dropped with its reason."
  (let ((out (copy-sequence validated))
        (drops (plist-get validated :drops)))
    (dolist (pair '((:scheduled_phrase . :scheduled)
                    (:deadline_phrase . :deadline)
                    (:timestamp_phrase . :timestamp)))
      (when-let* ((phrase (plist-get validated (car pair))))
        (let ((date (funcall resolver phrase created)))
          (if (null date)
              (push (list (cdr pair) phrase "does not parse as a date") drops)
            (setq out (plist-put out (cdr pair) date))
            (when (and now (< (if (consp date) (car date) date) now))
              (setq out (plist-put out :date-stale t)))))))
    (plist-put out :drops drops)))


;;;; Merge: the AI_ property writes

(defun org-decorate-core--why (validated canonical)
  "Compose AI_WHY from the rationale, the drops and CANONICAL fields left alone."
  (string-join
   (delq nil
         (append
          (list (plist-get validated :why))
          (mapcar (lambda (drop)
                    (format "dropped %s %S: %s" (nth 0 drop) (nth 1 drop) (nth 2 drop)))
                  (plist-get validated :drops))
          (mapcar (lambda (field) (format "%s already set, left alone" field))
                  canonical)))
   "; "))

(defun org-decorate-core--iso (date)
  "Return DATE, a YYYYMMDD integer or (YYYYMMDD . \"HH:MM\"), as text."
  (let* ((day (if (consp date) (car date) date))
         (text (format "%d-%02d-%02d" (/ day 10000) (% (/ day 100) 100) (% day 100))))
    (if (consp date) (concat text " " (cdr date)) text)))

(defun org-decorate-core-merge (entry validated stamp)
  "Return the AI_ property writes for ENTRY from VALIDATED, as an alist.

Only AI_-prefixed names ever appear.  A field whose canonical value the
entry already carries is still recorded but named in AI_WHY as
`already set', so the accept key knows to leave it alone.  STAMP is the
AI_STAMP text: time, backend, model, prompt and schema versions."
  (let (writes canonical)
    (cl-flet ((put (name value) (when value (push (cons name value) writes))))
      (put "AI_KIND" (plist-get validated :kind))
      (when (plist-get validated :keyword)
        (if (plist-get entry :state)
            (push "keyword" canonical)
          nil)
        (put "AI_KEYWORD" (plist-get validated :keyword)))
      (put "AI_TARGET" (plist-get validated :target))
      (put "AI_CATEGORY" (plist-get validated :category))
      (put "AI_CONTEXT" (plist-get validated :context))
      (put "AI_ENERGY" (plist-get validated :energy))
      (when (plist-get validated :tags)
        (put "AI_TAGS" (string-join (plist-get validated :tags) " ")))
      (when (plist-get validated :effort)
        (when (plist-get entry :effort) (push "Effort" canonical))
        (put "AI_EFFORT" (plist-get validated :effort)))
      (when (plist-get validated :impact)
        (when (plist-get entry :impact) (push "IMPACT" canonical))
        (put "AI_IMPACT" (number-to-string (plist-get validated :impact))))
      (when (plist-get validated :scheduled)
        (when (plist-get entry :scheduled) (push "SCHEDULED" canonical))
        (put "AI_SCHEDULED" (org-decorate-core--iso (plist-get validated :scheduled))))
      (when (plist-get validated :deadline)
        (when (plist-get entry :deadline) (push "DEADLINE" canonical))
        (put "AI_DEADLINE" (org-decorate-core--iso (plist-get validated :deadline)))
        (put "AI_DEADLINE_TYPE" (or (plist-get validated :deadline-type) "hard")))
      (when (plist-get validated :timestamp)
        (put "AI_TIMESTAMP" (org-decorate-core--iso (plist-get validated :timestamp))))
      (when (plist-get validated :waiting-on)
        (when (plist-get entry :waiting-on) (push "WAITING_ON" canonical))
        (put "AI_WAITING_ON" (plist-get validated :waiting-on)))
      (when (plist-get validated :related)
        (put "AI_RELATED" (string-join (plist-get validated :related) " ")))
      (when (plist-get validated :duplicate-of)
        (put "AI_DUPLICATE_OF" (plist-get validated :duplicate-of)))
      (when (plist-get validated :date-stale) (put "AI_DATE_STALE" "t"))
      (put "AI_REPO" (plist-get validated :repo))
      (put "AI_WHY" (org-decorate-core--why validated (nreverse canonical)))
      (put "AI_CONFIDENCE"
           (format "%.2f%s" (plist-get validated :confidence)
                   (mapconcat (lambda (cell) (format " %s=%.2f" (car cell) (cdr cell)))
                              (plist-get validated :field_confidence) "")))
      (put "AI_STAMP" stamp)
      (put "AI_HASH" (org-decorate-core-hash (plist-get entry :heading) (plist-get entry :body))))
    (nreverse writes)))

(defun org-decorate-core-plan (entry proposal lists stamp &optional resolver now)
  "Return the property writes decorating ENTRY with PROPOSAL, or an error plist.

A private entry, or one that is not stale, yields nil: nothing to
write.  A proposal that validates to nothing yields (:error TEXT) and no
writes -- never a partial one."
  (cond
   ((plist-get entry :private) nil)
   ((not (org-decorate-core-stale-p entry)) nil)
   (t
    (let* ((validated (org-decorate-core-validate proposal lists))
           (validated (if resolver
                          (org-decorate-core-resolve-dates
                           validated resolver (plist-get entry :created) now)
                        validated))
           (fields (cl-loop for (key value) on validated by #'cddr
                            when (and value (not (memq key '(:drops :why :confidence
                                                                    :field_confidence))))
                            collect key)))
      (if (null fields)
          (list :error (format "no usable proposal: %s"
                               (mapconcat (lambda (d) (format "%s" (nth 2 d)))
                                          (plist-get validated :drops) "; ")))
        (org-decorate-core-merge entry validated stamp))))))


;;;; Accept: AI_ properties into apply actions

(defun org-decorate-core--date (text)
  "Return TEXT, \"YYYY-MM-DD[ HH:MM]\", as a YYYYMMDD integer."
  (when (and text (string-match "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)" text))
    (+ (* 10000 (string-to-number (match-string 1 text)))
       (* 100 (string-to-number (match-string 2 text)))
       (string-to-number (match-string 3 text)))))

(defun org-decorate-core-strip-actions (entry)
  "Return the actions that remove every AI_ property from ENTRY."
  (delq nil
        (mapcar (lambda (name)
                  (when (org-decorate-core-property entry name)
                    (list :action 'property :name name :value nil)))
                org-decorate-property-names)))

(defun org-decorate-core-accept-actions (entry &optional fields)
  "Return the apply actions that promote ENTRY's proposals to real fields.

FIELDS, when given, restricts promotion to those AI_ names; the strip
always removes every AI_ property.  A canonical field the entry already
carries is never overwritten.  The refile comes last, since the entry
moves.  Each action still needs its `:task'."
  (let ((get (lambda (name)
               (and (or (null fields) (member name fields))
                    (org-decorate-core-property entry name))))
        actions refile)
    (when-let* ((keyword (funcall get "AI_KEYWORD")))
      (unless (or (plist-get entry :state) (equal keyword "none"))
        (push (list :action 'state :to keyword) actions)))
    (dolist (name '("AI_CONTEXT" "AI_ENERGY"))
      (when-let* ((tag (funcall get name)))
        (push (list :action 'tag :tag tag :add t) actions)))
    (when-let* ((tags (funcall get "AI_TAGS")))
      (dolist (tag (split-string tags))
        (push (list :action 'tag :tag tag :add t) actions)))
    (when-let* ((effort (funcall get "AI_EFFORT")))
      (unless (plist-get entry :effort)
        (push (list :action 'property :name "Effort" :value effort) actions)))
    (when-let* ((impact (funcall get "AI_IMPACT")))
      (unless (plist-get entry :impact)
        (push (list :action 'property :name "IMPACT" :value impact) actions)))
    (when-let* ((scheduled (funcall get "AI_SCHEDULED")))
      (unless (plist-get entry :scheduled)
        (push (list :action 'schedule :to (org-decorate-core--date scheduled)) actions)))
    (when-let* ((deadline (funcall get "AI_DEADLINE")))
      (unless (plist-get entry :deadline)
        (push (list :action 'deadline :to (org-decorate-core--date deadline)) actions)
        (when-let* ((type (funcall get "AI_DEADLINE_TYPE")))
          (when (equal type "soft")
            (push (list :action 'property :name "DEADLINE_TYPE" :value "soft") actions)))))
    (when-let* ((stamp (funcall get "AI_TIMESTAMP")))
      (push (list :action 'timestamp :to stamp) actions))
    (when-let* ((who (funcall get "AI_WAITING_ON")))
      (unless (plist-get entry :waiting-on)
        (push (list :action 'property :name "WAITING_ON" :value who) actions)))
    (when-let* ((related (funcall get "AI_RELATED")))
      (push (list :action 'body-line
                  :text (concat "Related: "
                                (mapconcat (lambda (r)
                                             (if (string-match-p "\\`\\(id\\|file\\):" r)
                                                 (format "[[%s]]" r)
                                               (format "[[hy:%s]]" r)))
                                           (split-string related) " ")))
            actions))
    (when-let* ((target (funcall get "AI_TARGET")))
      (setq refile (if (string-match "\\`\\(.*?\\)::\\*\\(.*\\)\\'" target)
                       (list :action 'refile :to (match-string 1 target)
                             :heading (match-string 2 target))
                     (list :action 'refile :to target))))
    (append (nreverse actions)
            (org-decorate-core-strip-actions entry)
            (and refile (list refile)))))

(defun org-decorate-core-corrections (entry accepted-values)
  "Return correction records: proposals ACCEPTED-VALUES overrode.
ACCEPTED-VALUES is an alist of (AI_NAME . VALUE-WRITTEN); a value that
differs from the proposal is a training example."
  (delq nil
        (mapcar (lambda (cell)
                  (let ((proposed (org-decorate-core-property entry (car cell))))
                    (when (and proposed (not (equal proposed (cdr cell))))
                      (list :hash (org-decorate-core-property entry "AI_HASH")
                            :field (car cell) :proposed proposed :corrected (cdr cell)
                            :prompt org-decorate-prompt-version))))
                accepted-values)))


;;;; Duplicates and neighbours

(defun org-decorate-core-normalise (text)
  "Return TEXT lower-cased, punctuation and extra space removed."
  (string-join (split-string (downcase (replace-regexp-in-string "[^[:alnum:] ]" " " (or text ""))))
               " "))

(defun org-decorate-core-duplicate (entry neighbours &optional threshold)
  "Return the neighbour ENTRY duplicates, or nil.

NEIGHBOURS are plists (:id :title :score :backlink :state :done).  A
duplicate needs two signals: a score at or above THRESHOLD and either
an exact normalised title or the same backlink.  A finished neighbour
is never a duplicate: it came back, which is a different finding."
  (let ((threshold (or threshold org-decorate-duplicate-threshold))
        (title (org-decorate-core-normalise (plist-get entry :heading))))
    (cl-find-if
     (lambda (neighbour)
       (and (not (plist-get neighbour :done))
            (>= (or (plist-get neighbour :score) 0.0) threshold)
            (or (equal title (org-decorate-core-normalise (plist-get neighbour :title)))
                (and (plist-get entry :backlink)
                     (equal (plist-get entry :backlink) (plist-get neighbour :backlink))))))
     neighbours)))

(defun org-decorate-core-related (entry neighbours &optional threshold)
  "Return the neighbours of ENTRY worth listing as related, best first."
  (let ((threshold (or threshold org-decorate-related-threshold))
        (duplicate (org-decorate-core-duplicate entry neighbours)))
    (sort (cl-remove-if (lambda (n) (or (eq n duplicate)
                                        (< (or (plist-get n :score) 0.0) threshold)))
                        (copy-sequence neighbours))
          (lambda (a b) (> (plist-get a :score) (plist-get b :score))))))


;;;; Commit evidence

(defun org-decorate-core-commit-evidence (commits ids)
  "Return (ID . SHA) for every commit in COMMITS whose message names one of IDS.
COMMITS are plists (:sha :message :date); the first commit naming an ID
wins, so a re-run over the same log proposes the same SHA."
  (let (found)
    (dolist (commit commits)
      (dolist (id ids)
        (when (and (not (assoc id found))
                   (string-match-p (regexp-quote id) (or (plist-get commit :message) "")))
          (push (cons id (plist-get commit :sha)) found))))
    (nreverse found)))

(provide 'org-decorate-core)
;;; org-decorate-core.el ends here
