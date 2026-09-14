;;; org-routine-core.el --- The daily routine as a machine-readable template -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; The routine table, read by code.  No Org in here: the parser takes the
;; text of an Org table and returns plists, and every question the rest
;; of the config asks of the routine -- what today's blocks are, when the
;; dip is, which rows are fixed, how many focus minutes Monday has -- is a
;; function over those plists, tested in batch against a copy of the table.
;;
;; The table is the prose note's own (`~/kb/notes/schedule.org'), given a
;; `#+NAME: routine' line and three columns the prose did not need:
;;
;;   | Time        | Activity           | Notes | kind  | days    | bucket  | habit |
;;   |-------------+--------------------+-------+-------+---------+---------+-------|
;;   | 05:00-05:30 | Clean apartment    | ...   | fixed |         |         | yes   |
;;   | 08:00-12:00 | Focus block 1 (4h) | ...   | focus |         | work    |       |
;;   | 13:30-15:00 | Focus block 2, dip | ...   | dip   |         | work    |       |
;;   | 18:00-20:00 | Free time / admin  | ...   | admin |         |         |       |
;;   | 06:00-07:00 | Lift weights       | ...   | fixed | Mon-Sat | body    | yes   |
;;
;; `kind' is one of `fixed', `focus', `dip', `admin', `off'.  `days' is a
;; weekday set ("Mon Tue" or "Mon-Fri"; blank means every day).  `bucket'
;; names the queue bucket the row's minutes belong to; blank means the
;; kind's default (focus and dip are `work', admin is `housekeeping',
;; fixed rows with a habit are the bucket they name).  `habit' marks a
;; fixed row that should exist as a habit entry in `(todo) routine.org'.
;;
;; A second table, `#+NAME: variants', overrides rows on named days:
;;
;;   | variant   | Time        | Activity | kind  | days |
;;   |-----------+-------------+----------+-------+------|
;;   | interview | 08:00-12:00 | Focus block 1 | off | |
;;
;; A variant replaces every routine row whose time range it overlaps, on
;; the days it applies.  The report says which rows a variant removed.
;;
;; Times are minutes since midnight.  Dates are YYYYMMDD integers where a
;; date is needed, weekdays are 0-6 with Sunday 0, as in org-queue-core.
;; The en dash the prose table uses ("05:00–05:30") parses the same as a
;; hyphen, because the table is the prose table and rewriting it is the
;; thing this file must not do.

;;; Code:

(require 'cl-lib)

(defgroup org-routine nil
  "The daily routine as a template."
  :group 'org
  :prefix "org-routine-")

(defcustom org-routine-kinds '(fixed focus dip admin off)
  "The kinds a routine row may have."
  :type '(repeat symbol)
  :group 'org-routine)

(defcustom org-routine-kind-buckets
  '((focus . work) (dip . work) (admin . housekeeping))
  "The queue bucket a row's minutes belong to when the row names none."
  :type '(alist :key-type symbol :value-type symbol)
  :group 'org-routine)

(defcustom org-routine-default-bucket-minutes 60
  "Minutes the `default' bucket gets per day when the table does not say.
The table says what focus, admin and habits take; whatever is left of
the free minutes is `default', and this is its floor."
  :type 'integer
  :group 'org-routine)

(defcustom org-routine-dip-first-hours nil
  "When non-nil, the first two hours of the first focus block are a dip too.
Part 6 question 1 of composite.org: the routine's prose puts pomodoros
in block one's first two hours and in the dip, which contradicts its own
principle.  The default follows the principle; set this to follow the
prose."
  :type 'boolean
  :group 'org-routine)


;;;; Parsing

(defconst org-routine--weekdays
  '(("sun" . 0) ("mon" . 1) ("tue" . 2) ("wed" . 3) ("thu" . 4) ("fri" . 5) ("sat" . 6))
  "Weekday names to numbers, Sunday 0.")

(defun org-routine-core-parse-time (string)
  "Return STRING, \"HH:MM\", as minutes since midnight, or nil."
  (when (and string (string-match "\\`\\s-*\\([0-9]\\{1,2\\}\\):\\([0-9]\\{2\\}\\)\\s-*\\'" string))
    (let ((h (string-to-number (match-string 1 string)))
          (m (string-to-number (match-string 2 string))))
      (when (and (<= h 24) (< m 60))
        (+ (* 60 h) m)))))

(defun org-routine-core-parse-range (string)
  "Return (START . END) minutes for STRING, \"HH:MM-HH:MM\", or nil.
Hyphen, en dash and em dash all separate the two.  A bare \"HH:MM\" is
an instant: START equals END."
  (when string
    (let ((parts (split-string string "[-–—]" t "[ \t]+")))
      (pcase (length parts)
        (1 (when-let* ((at (org-routine-core-parse-time (car parts))))
             (cons at at)))
        (2 (let ((start (org-routine-core-parse-time (car parts)))
                 (end (org-routine-core-parse-time (cadr parts))))
             (when (and start end (<= start end))
               (cons start end))))))))

(defun org-routine-core-parse-days (string)
  "Return STRING, a weekday set, as a list of 0-6, or nil for every day.
Accepts \"Mon Tue\", \"Mon-Fri\", \"Mon, Wed\", \"weekdays\", \"weekend\".
An unknown word makes the whole set nil with an error, not a partial
set: a typo should not quietly close the bucket on Saturdays."
  (let ((text (and string (downcase (string-trim string)))))
    (cond
     ((or (null text) (string-empty-p text)) nil)
     ((equal text "weekdays") '(1 2 3 4 5))
     ((equal text "weekend") '(0 6))
     ((equal text "daily") nil)
     (t
      (let (days)
        (dolist (word (split-string text "[ ,]+" t))
          (if (string-match "\\`\\([a-z]+\\)-\\([a-z]+\\)\\'" word)
              (let ((from (alist-get (substring (match-string 1 word) 0 3)
                                     org-routine--weekdays nil nil #'equal))
                    (to (alist-get (substring (match-string 2 word) 0 3)
                                   org-routine--weekdays nil nil #'equal)))
                (unless (and from to)
                  (error "Unknown weekday range: %s" word))
                (let ((d from))
                  (push d days)
                  (while (/= d to)
                    (setq d (mod (1+ d) 7))
                    (push d days))))
            (let ((day (alist-get (substring word 0 (min 3 (length word)))
                                  org-routine--weekdays nil nil #'equal)))
              (unless day (error "Unknown weekday: %s" word))
              (push day days))))
        (sort (delete-dups days) #'<))))))

(defun org-routine-core--split-row (line)
  "Return the cells of table LINE, trimmed, or nil for a rule or non-row."
  (let ((trimmed (string-trim line)))
    (when (and (string-prefix-p "|" trimmed)
               (not (string-match-p "\\`|[-+|]*\\'" trimmed)))
      (mapcar #'string-trim
              (split-string (substring trimmed 1 (if (string-suffix-p "|" trimmed)
                                                     (1- (length trimmed))
                                                   nil))
                            "|")))))

(defun org-routine-core--header-index (header)
  "Return an alist of (COLUMN . INDEX) for HEADER, cells lower-cased."
  (let ((index 0) columns)
    (dolist (cell header)
      (push (cons (intern (downcase cell)) index) columns)
      (cl-incf index))
    columns))

(defun org-routine-core--cell (row columns name)
  "Return ROW's cell under column NAME, or nil when the column is absent."
  (when-let* ((index (alist-get name columns)))
    (let ((value (nth index row)))
      (and value (not (string-empty-p value)) value))))

(defun org-routine-core-parse (text &optional name)
  "Parse TEXT, the lines of an Org table, into a list of row plists.

NAME is used in error messages.  Each row is

  (:start MIN :end MIN :label STRING :kind SYMBOL :days LIST-OR-NIL
   :bucket SYMBOL-OR-NIL :habit BOOL :line N :notes STRING)

A table without a `kind' column, or a row with a malformed time or an
unknown kind, signals an error naming the line: a partial routine would
be a wrong capacity, and a wrong capacity is worse than none."
  (let* ((lines (split-string text "\n"))
         (line-number 0)
         header columns rows)
    (dolist (line lines)
      (cl-incf line-number)
      (when-let* ((cells (org-routine-core--split-row line)))
        (if (null header)
            (progn
              (setq header cells
                    columns (org-routine-core--header-index cells))
              (unless (alist-get 'time columns)
                (error "%s: line %d: the table has no Time column"
                       (or name "routine") line-number))
              (unless (alist-get 'kind columns)
                (error "%s: line %d: the table has no kind column"
                       (or name "routine") line-number)))
          (let* ((time (org-routine-core--cell cells columns 'time))
                 (range (org-routine-core-parse-range time))
                 (kind-cell (org-routine-core--cell cells columns 'kind))
                 (kind (and kind-cell (intern (downcase kind-cell))))
                 (bucket (org-routine-core--cell cells columns 'bucket))
                 (habit (org-routine-core--cell cells columns 'habit)))
            (unless range
              (error "%s: line %d: malformed time %S"
                     (or name "routine") line-number time))
            (unless kind
              (error "%s: line %d: no kind on %S"
                     (or name "routine") line-number
                     (org-routine-core--cell cells columns 'activity)))
            (unless (memq kind org-routine-kinds)
              (error "%s: line %d: unknown kind %s (one of %s)"
                     (or name "routine") line-number kind
                     (mapconcat #'symbol-name org-routine-kinds " ")))
            (push (list :start (car range) :end (cdr range)
                        :label (or (org-routine-core--cell cells columns 'activity)
                                   (org-routine-core--cell cells columns 'label)
                                   "")
                        :kind kind
                        :days (condition-case err
                                  (org-routine-core-parse-days
                                   (org-routine-core--cell cells columns 'days))
                                (error (error "%s: line %d: %s"
                                              (or name "routine") line-number
                                              (error-message-string err))))
                        :bucket (and bucket (intern (downcase bucket)))
                        :habit (and habit
                                    (member (downcase habit) '("yes" "y" "t" "x" "habit"))
                                    t)
                        :variant (org-routine-core--cell cells columns 'variant)
                        :notes (or (org-routine-core--cell cells columns 'notes) "")
                        :line line-number)
                  rows)))))
    (unless header
      (error "%s: no table found" (or name "routine")))
    (nreverse rows)))

(defun org-routine-core-check (rows)
  "Signal an error if ROWS overlap on a day they share, else return ROWS."
  (dolist (a rows)
    (dolist (b rows)
      (when (and (not (eq a b))
                 (< (plist-get a :line) (plist-get b :line))
                 (< (plist-get a :start) (plist-get b :end))
                 (< (plist-get b :start) (plist-get a :end))
                 (< (plist-get a :start) (plist-get a :end))
                 (< (plist-get b :start) (plist-get b :end))
                 (org-routine-core--days-intersect-p (plist-get a :days)
                                                     (plist-get b :days)))
        (error "routine: lines %d and %d overlap (%s and %s)"
               (plist-get a :line) (plist-get b :line)
               (plist-get a :label) (plist-get b :label)))))
  rows)

(defun org-routine-core--days-intersect-p (a b)
  "Return non-nil if weekday sets A and B share a day; nil means every day."
  (or (null a) (null b) (cl-intersection a b)))


;;;; The routine

(defun org-routine-core-make (rows &optional variants)
  "Return a routine plist from ROWS and VARIANTS, both parsed tables."
  (list :rows (org-routine-core-check rows)
        :variants (or variants nil)))

(defun org-routine-core-row-applies-p (row weekday)
  "Return non-nil if ROW falls on WEEKDAY (0-6)."
  (let ((days (plist-get row :days)))
    (or (null days) (memq weekday days))))

(defun org-routine-core--variant-rows (routine variant)
  "Return the variant rows named VARIANT, or nil."
  (when variant
    (cl-remove-if-not (lambda (row) (equal (plist-get row :variant) variant))
                      (plist-get routine :variants))))

(defun org-routine-core-blocks (routine weekday &optional variant)
  "Return the blocks of ROUTINE on WEEKDAY, in time order.

With VARIANT, a name from the variants table, its rows replace every
routine row they overlap.  Each block is a row plist with `:minutes'
added; a block a variant removed is kept with `:removed-by' set so the
report can say what the variant cost."
  (let* ((rows (cl-remove-if-not
                (lambda (row) (org-routine-core-row-applies-p row weekday))
                (plist-get routine :rows)))
         (overrides (cl-remove-if-not
                     (lambda (row) (org-routine-core-row-applies-p row weekday))
                     (org-routine-core--variant-rows routine variant)))
         (blocks
          (mapcar
           (lambda (row)
             (let ((hit (cl-find-if
                         (lambda (override)
                           (and (< (plist-get row :start) (plist-get override :end))
                                (< (plist-get override :start) (plist-get row :end))))
                         overrides)))
               (append (list :minutes (- (plist-get row :end) (plist-get row :start))
                             :removed-by (and hit (plist-get hit :variant)))
                       row)))
           rows)))
    (setq blocks (append blocks
                         (mapcar (lambda (override)
                                   (append (list :minutes (- (plist-get override :end)
                                                             (plist-get override :start)))
                                           override))
                                 overrides)))
    (sort blocks (lambda (a b) (< (plist-get a :start) (plist-get b :start))))))

(defun org-routine-core-active-blocks (routine weekday &optional variant)
  "Return the blocks of ROUTINE on WEEKDAY that a VARIANT did not remove."
  (cl-remove-if (lambda (block) (plist-get block :removed-by))
                (org-routine-core-blocks routine weekday variant)))

(defun org-routine-core-bucket-of (block)
  "Return the queue bucket BLOCK's minutes belong to."
  (or (plist-get block :bucket)
      (alist-get (plist-get block :kind) org-routine-kind-buckets)))

(defun org-routine-core-minutes (routine weekday kinds &optional variant)
  "Return the minutes ROUTINE gives to blocks of KINDS on WEEKDAY."
  (cl-reduce #'+
             (mapcar (lambda (block) (plist-get block :minutes))
                     (cl-remove-if-not
                      (lambda (block) (memq (plist-get block :kind) kinds))
                      (org-routine-core-active-blocks routine weekday variant)))
             :initial-value 0))

(defun org-routine-core-discretionary (routine weekday &optional variant)
  "Return the minutes of ROUTINE on WEEKDAY the queue may plan into.
Focus, dip and admin rows; fixed rows are already spent."
  (org-routine-core-minutes routine weekday '(focus dip admin) variant))

(defun org-routine-core-capacity (routine weekday slack &optional variant)
  "Return the planning capacity for WEEKDAY: discretionary minutes less SLACK.
SLACK is a fraction, as `org-queue-slack-fraction'.  What replaces the
guess in `org-queue-capacity'."
  (round (* (org-routine-core-discretionary routine weekday variant)
            (- 1.0 slack))))

(defun org-routine-core-capacity-table (routine slack &optional variant)
  "Return an `org-queue-capacity' alist, one entry per weekday."
  (mapcar (lambda (weekday)
            (cons weekday (org-routine-core-capacity routine weekday slack variant)))
          '(0 1 2 3 4 5 6)))

(defun org-routine-core-fixed (routine weekday &optional variant)
  "Return the fixed rows of ROUTINE on WEEKDAY: appointments with the self."
  (cl-remove-if-not (lambda (block) (eq (plist-get block :kind) 'fixed))
                    (org-routine-core-active-blocks routine weekday variant)))

(defun org-routine-core-habits (routine)
  "Return the rows of ROUTINE marked as habits, whatever the day."
  (cl-remove-if-not (lambda (row) (plist-get row :habit))
                    (plist-get routine :rows)))

(defun org-routine-core-dip (routine weekday &optional variant)
  "Return the dip windows of ROUTINE on WEEKDAY as a list of (START . END).

The `dip' rows, plus -- when `org-routine-dip-first-hours' is set -- the
first two hours of the first focus block.  Usually one window; a list so
that both readings of the routine's prose are expressible."
  (let* ((blocks (org-routine-core-active-blocks routine weekday variant))
         (dips (mapcar (lambda (block)
                         (cons (plist-get block :start) (plist-get block :end)))
                       (cl-remove-if-not (lambda (block) (eq (plist-get block :kind) 'dip))
                                         blocks)))
         (first-focus (cl-find-if (lambda (block) (eq (plist-get block :kind) 'focus))
                                  blocks)))
    (when (and org-routine-dip-first-hours first-focus)
      (push (cons (plist-get first-focus :start)
                  (min (plist-get first-focus :end)
                       (+ (plist-get first-focus :start) 120)))
            dips))
    (sort dips (lambda (a b) (< (car a) (car b))))))

(defun org-routine-core-in-dip-p (routine weekday minute &optional variant)
  "Return non-nil if MINUTE (since midnight) on WEEKDAY falls in a dip."
  (cl-some (lambda (window) (and (<= (car window) minute) (< minute (cdr window))))
           (org-routine-core-dip routine weekday variant)))

(defun org-routine-core-block-at (routine weekday minute &optional variant)
  "Return the block of ROUTINE that contains MINUTE on WEEKDAY, or nil."
  (cl-find-if (lambda (block) (and (<= (plist-get block :start) minute)
                                   (< minute (plist-get block :end))))
              (org-routine-core-active-blocks routine weekday variant)))


;;;; Derived tables for the queue

(defun org-routine-core-buckets (routine slack &optional variant matches)
  "Derive an `org-queue-buckets' table from ROUTINE.

Every focus and dip minute is `work', admin minutes are `housekeeping'
\(or what the row's bucket column says), a fixed row with a habit gives
its bucket the row's minutes so the habit's reservation has room, and
`default' is `org-routine-default-bucket-minutes'.  Minutes are per
weekday.  SLACK is not applied here -- the packer takes it.  MATCHES is
an alist of (BUCKET . MATCH-PLIST) giving each bucket its claim; a
bucket without one claims nothing and is filled by `default'."
  (let (names)
    (dolist (weekday '(0 1 2 3 4 5 6))
      (dolist (block (org-routine-core-active-blocks routine weekday variant))
        (when-let* ((bucket (org-routine-core-bucket-of block)))
          (when (or (memq (plist-get block :kind) '(focus dip admin))
                    (plist-get block :habit))
            (cl-pushnew bucket names)))))
    (setq names (sort names (lambda (a b) (string< (symbol-name a) (symbol-name b)))))
    (append
     (mapcar
      (lambda (name)
        (cons name
              (append
               (list :minutes
                     (mapcar
                      (lambda (weekday)
                        (cons weekday
                              (cl-reduce
                               #'+
                               (mapcar (lambda (block) (plist-get block :minutes))
                                       (cl-remove-if-not
                                        (lambda (block)
                                          (and (eq (org-routine-core-bucket-of block) name)
                                               (or (memq (plist-get block :kind)
                                                         '(focus dip admin))
                                                   (plist-get block :habit))))
                                        (org-routine-core-active-blocks
                                         routine weekday variant)))
                               :initial-value 0)))
                      '(0 1 2 3 4 5 6)))
               (when-let* ((match (alist-get name matches)))
                 (list :match match)))))
      names)
     (list (list 'default :minutes org-routine-default-bucket-minutes)))))

(defun org-routine-core-habit-entries (routine)
  "Return the habit rows of ROUTINE as plists for `(todo) routine.org'.

Each is (:title :minutes :days :bucket :start :end).  What the generator
writes as an entry with `:STYLE: habit', `:Effort:' and `:HABIT_DAYS:'."
  (mapcar (lambda (row)
            (list :title (plist-get row :label)
                  :minutes (- (plist-get row :end) (plist-get row :start))
                  :days (plist-get row :days)
                  :bucket (plist-get row :bucket)
                  :start (plist-get row :start)
                  :end (plist-get row :end)))
          (org-routine-core-habits routine)))


;;;; Windows for the chains (G16)

(defun org-routine-core-windows (routine weekday &optional variant)
  "Return the kick, review and quiet windows of ROUTINE on WEEKDAY.

A plist of three lists of (START . END):

  :kick    the first ten minutes of every focus and dip block, and the
           ten minutes before the first fixed row of the day
  :review  the last fifteen minutes of every focus and dip block
  :quiet   the middle of every focus block: everything a kick or a
           review window does not cover

The numbers are a first reading of the routine, not a theory; they are
one function so a better reading is one edit."
  (let* ((blocks (org-routine-core-active-blocks routine weekday variant))
         (working (cl-remove-if-not (lambda (block) (memq (plist-get block :kind) '(focus dip)))
                                    blocks))
         (first-fixed (cl-find-if (lambda (block) (eq (plist-get block :kind) 'fixed))
                                  blocks))
         kick review quiet)
    (when first-fixed
      (push (cons (max 0 (- (plist-get first-fixed :start) 10))
                  (plist-get first-fixed :start))
            kick))
    (dolist (block working)
      (let ((start (plist-get block :start))
            (end (plist-get block :end)))
        (push (cons start (min end (+ start 10))) kick)
        (push (cons (max start (- end 15)) end) review)
        (when (and (eq (plist-get block :kind) 'focus)
                   (> (- end 15) (+ start 10)))
          (push (cons (+ start 10) (- end 15)) quiet))))
    (list :kick (sort kick (lambda (a b) (< (car a) (car b))))
          :review (sort review (lambda (a b) (< (car a) (car b))))
          :quiet (sort quiet (lambda (a b) (< (car a) (car b)))))))

(defun org-routine-core-in-window-p (windows minute)
  "Return non-nil if MINUTE falls in one of WINDOWS, a list of (START . END)."
  (cl-some (lambda (window) (and (<= (car window) minute) (< minute (cdr window))))
           windows))


;;;; Formatting

(defun org-routine-core-format-time (minute)
  "Return MINUTE since midnight as HH:MM."
  (format "%02d:%02d" (/ minute 60) (% minute 60)))

(defun org-routine-core-format-range (window)
  "Return WINDOW, a (START . END) pair, as HH:MM-HH:MM."
  (format "%s-%s" (org-routine-core-format-time (car window))
          (org-routine-core-format-time (cdr window))))

(defun org-routine-core-report (routine weekday slack &optional variant)
  "Return lines describing ROUTINE on WEEKDAY: the blocks and the sums."
  (let ((blocks (org-routine-core-blocks routine weekday variant))
        lines)
    (dolist (block blocks)
      (push (format "%s  %-6s %-24s %4d%s"
                    (org-routine-core-format-range
                     (cons (plist-get block :start) (plist-get block :end)))
                    (plist-get block :kind)
                    (plist-get block :label)
                    (plist-get block :minutes)
                    (if (plist-get block :removed-by)
                        (format "  removed by %s" (plist-get block :removed-by))
                      ""))
            lines))
    (push (format "focus %d, dip %d, admin %d, fixed %d; capacity %d at %d%% slack"
                  (org-routine-core-minutes routine weekday '(focus) variant)
                  (org-routine-core-minutes routine weekday '(dip) variant)
                  (org-routine-core-minutes routine weekday '(admin) variant)
                  (org-routine-core-minutes routine weekday '(fixed) variant)
                  (org-routine-core-capacity routine weekday slack variant)
                  (round (* 100 slack)))
          lines)
    (nreverse lines)))

(provide 'org-routine-core)
;;; org-routine-core.el ends here
