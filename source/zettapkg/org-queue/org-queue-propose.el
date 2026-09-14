;;; org-queue-propose.el --- The horizon view and the proposal loop -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Keywords: convenience, calendar

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Two buffers over `org-queue-horizon':
;;
;; `org-queue-horizon' draws the simulation, one section per day, and
;; writes nothing.  It shows what the proposal would do before asking.
;;
;; `org-queue-propose' turns the simulation into a list of placements --
;; schedule this, move that, unschedule the other -- and draws them for
;; review.  Accept lines with `a', reject with `r', apply the accepted
;; with `C-c C-c'.  A rejection is remembered for `org-queue-rejection-days'
;; so the same placement is not proposed again tomorrow.  A date a person
;; wrote is never in the list; deadlines and states are never proposed.
;;
;;   a / r        accept / reject the line, or every line in the region
;;   A / R        accept / reject the whole day
;;   C-c C-a      accept everything
;;   e            change the day for this line (it becomes a human placement)
;;   g            propose again, keeping marks on unchanged lines
;;   C-c C-c      apply the accepted lines
;;   q            abandon; nothing is written

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-queue)
(require 'org-queue-horizon)
(require 'org-queue-apply)

(defcustom org-queue-rejections-file
  (expand-file-name "org-queue-rejections.el" user-emacs-directory)
  "Where rejected placements are remembered."
  :type 'file
  :group 'org-queue)

(defcustom org-queue-rejection-days 14
  "How many days a rejected placement stays out of proposals."
  :type 'integer
  :group 'org-queue)

(defcustom org-queue-horizon-buffer-name "*org-queue horizon*"
  "Buffer the horizon is drawn in."
  :type 'string
  :group 'org-queue)

(defcustom org-queue-proposal-buffer-name "*org-queue proposal*"
  "Buffer a proposal is drawn in."
  :type 'string
  :group 'org-queue)

(defface org-queue-accepted '((t :inherit bold))
  "Face for an accepted proposal line's mark."
  :group 'org-queue)

(defface org-queue-rejected '((t :inherit (shadow strike-through)))
  "Face for a rejected proposal line."
  :group 'org-queue)


;;;; Scopes

(defconst org-queue--scopes
  '(("today" . 0) ("tomorrow" . tomorrow) ("3 days" . 2) ("week" . 6)
    ("fortnight" . 13) ("month" . 29) ("backlog" . backlog)
    ("until a date" . date))
  "Named ranges a horizon or proposal can cover.")

(defun org-queue--read-scope ()
  "Ask for a scope and return (FROM . TO) as YYYYMMDD integers."
  (let* ((today (org-queue-core-today))
         (choice (completing-read "Scope: " (mapcar #'car org-queue--scopes) nil t))
         (spec (alist-get choice org-queue--scopes nil nil #'equal)))
    (pcase spec
      ('tomorrow (let ((d (org-queue-core-date-add today 1))) (cons d d)))
      ('backlog (cons today (org-queue-core-date-add today (1- org-queue-horizon-max-days))))
      ('date (cons today (org-queue-harvest--date
                          (org-read-date nil t nil "Until: "))))
      ((pred integerp) (cons today (org-queue-core-date-add today spec)))
      (_ (cons today today)))))

(defun org-queue--range-string (from to)
  (if (= from to)
      (org-queue--date-string from)
    (format "%s to %s" (org-queue--iso from) (org-queue--iso to))))

(defun org-queue--day-label (date)
  (format-time-string
   "%a %-d %b"
   (encode-time 0 0 12 (% date 100) (% (/ date 100) 100) (/ date 10000))))


;;;; Rejections

(defun org-queue--rejections ()
  "Return remembered rejections, (KEY DATE . DAY-RECORDED), still in force."
  (let ((cutoff (org-queue-core-date-add (org-queue-core-today)
                                         (- org-queue-rejection-days))))
    (cl-remove-if
     (lambda (entry) (< (nth 2 entry) cutoff))
     (when (file-readable-p org-queue-rejections-file)
       (with-temp-buffer
         (insert-file-contents org-queue-rejections-file)
         (ignore-errors (read (current-buffer))))))))

(defun org-queue--record-rejections (pairs)
  "Remember PAIRS, a list of (KEY . DATE), as rejected today."
  (when pairs
    (let ((today (org-queue-core-today))
          (entries (org-queue--rejections)))
      (dolist (pair pairs)
        (setq entries (cons (list (car pair) (cdr pair) today)
                            (cl-remove-if (lambda (e) (and (equal (car e) (car pair))
                                                           (eql (nth 1 e) (cdr pair))))
                                          entries))))
      (make-directory (file-name-directory org-queue-rejections-file) t)
      (with-temp-file org-queue-rejections-file
        (let ((print-length nil) (print-level nil))
          (prin1 entries (current-buffer))
          (insert "\n"))))))


;;;; The horizon view

(defvar-local org-queue--horizon nil
  "The horizon drawn in this buffer.")

(defvar-local org-queue--expanded nil
  "Days whose full plan is shown.")

(defun org-queue--simulate (from to &optional soft)
  "Harvest and simulate FROM to TO.  With SOFT, machine placements may move.
Returns (TASKS . HORIZON)."
  (let* ((tasks (org-queue-harvest nil from))
         (org-queue-core-placed-soft soft)
         (horizon (org-queue-core-horizon tasks from to)))
    (cons tasks horizon)))

(defun org-queue--day-summary (plan)
  "One line for PLAN: the day, its minutes, its buckets."
  (let ((by-reason (lambda (reason)
                     (cl-count reason (plist-get plan :planned)
                               :key (lambda (task) (plist-get task :queue-reason))))))
    (format "%-10s %s of %s   %d committed, %d chosen, %d pulled%s%s"
            (org-queue--day-label (plist-get plan :date))
            (org-queue-core-format-minutes (plist-get plan :minutes))
            (org-queue-core-format-minutes (plist-get plan :usable))
            (funcall by-reason 'committed)
            (funcall by-reason 'scored)
            (funcall by-reason 'pulled-forward)
            (if (plist-get plan :overcommitted) "   OVERCOMMITTED" "")
            (let ((over (cl-remove-if-not (lambda (b) (plist-get b :overcommitted))
                                          (plist-get plan :buckets))))
              (if over
                  (format " (%s)" (mapconcat (lambda (b) (format "%s" (plist-get b :name)))
                                             over ", "))
                "")))))

(defun org-queue--draw-horizon ()
  "Draw `org-queue--horizon' in the current buffer."
  (let ((inhibit-read-only t)
        (horizon org-queue--horizon))
    (erase-buffer)
    (org-queue--insert
     (format "Horizon %s\n" (org-queue--range-string (plist-get horizon :from)
                                                       (plist-get horizon :to)))
     'org-queue-header)
    (org-queue--insert (format "   %s\n" (org-queue-horizon-summary horizon))
                       'org-queue-detail)
    (org-queue--insert-legend)
    (org-queue--insert "   TAB on a day opens it; RET jumps; g re-simulates.\n"
                       'org-queue-detail)
    (dolist (plan (plist-get horizon :days))
      (let ((date (plist-get plan :date))
            (start (point)))
        (org-queue--insert (format "\n%s\n" (org-queue--day-summary plan))
                           (if (plist-get plan :overcommitted) 'org-queue-alarm 'org-queue-section))
        (put-text-property start (point) 'org-queue-day date)
        (when (memq date org-queue--expanded)
          (let ((body-start (point)))
            (setq org-queue--plan plan)
            (org-queue--draw-body plan)
            (put-text-property body-start (point) 'org-queue-date date)))))
    (when-let* ((unplaced (plist-get horizon :unplaced)))
      (setq org-queue--plan (car (last (plist-get horizon :days))))
      (org-queue--insert-section
       (format "\nNever fits in %d days (%d)" (length (plist-get horizon :days))
               (length unplaced))
       unplaced (lambda (_task) "")))
    (when-let* ((missed (plist-get horizon :missed)))
      (org-queue--insert-section
       (format "\nMissed deadlines (%d)" (length missed))
       (mapcar #'car missed)
       (lambda (task)
         (let ((cell (assq task missed)))
           (format "due %s, %s short"
                   (org-queue--iso (plist-get task :deadline))
                   (org-queue-core-format-minutes (cdr cell)))))))
    (goto-char (point-min))))

(defun org-queue-horizon-toggle-day ()
  "Open or close the day at point; elsewhere, toggle the details."
  (interactive)
  (if-let* ((date (get-text-property (point) 'org-queue-day)))
      (progn
        (setq org-queue--expanded
              (if (memq date org-queue--expanded)
                  (delq date org-queue--expanded)
                (cons date org-queue--expanded)))
        (let ((line (line-number-at-pos)))
          (org-queue--draw-horizon)
          (forward-line (1- line))))
    (org-queue-toggle-details)))

(defun org-queue-horizon-refresh ()
  "Re-simulate the range this buffer shows."
  (interactive)
  (let ((horizon org-queue--horizon))
    (setq org-queue--horizon
          (cdr (org-queue--simulate (plist-get horizon :from) (plist-get horizon :to))))
    (org-queue--draw-horizon)
    (message "%s" (org-queue-horizon-summary org-queue--horizon))))

(defvar-keymap org-queue-horizon-mode-map
  :doc "Keymap for `org-queue-horizon-mode'."
  :parent org-queue-mode-map
  "TAB" #'org-queue-horizon-toggle-day
  "g"   #'org-queue-horizon-refresh)

(define-derived-mode org-queue-horizon-mode org-queue-mode "Horizon"
  "Major mode for the many-day simulation.

\\{org-queue-horizon-mode-map}"
  (setq org-queue--redraw-function #'org-queue--draw-horizon))

;;;###autoload
(defun org-queue-horizon (from to)
  "Simulate the days FROM to TO and show them; nothing is written.
Interactively, ask for a scope."
  (interactive (let ((range (org-queue--read-scope)))
                 (list (car range) (cdr range))))
  (let ((buffer (get-buffer-create org-queue-horizon-buffer-name))
        (horizon (cdr (org-queue--simulate from to))))
    (with-current-buffer buffer
      (org-queue-horizon-mode)
      (setq org-queue--columns (copy-sequence org-queue-columns))
      (setq org-queue--details org-queue-show-details)
      (setq org-queue--horizon horizon)
      (setq org-queue--expanded (list from))
      (org-queue--draw-horizon))
    (pop-to-buffer buffer)
    (message "%s" (org-queue-horizon-summary horizon))))


;;;; The proposal

(defvar-local org-queue--proposal nil
  "The items drawn in this buffer: actions and findings.")

(defvar-local org-queue--marks nil
  "Alist of (ITEM-KEY . accept|reject).")

(defvar-local org-queue--range nil
  "(FROM . TO) this proposal covers.")

(defun org-queue--item-key (item)
  "What identifies ITEM across re-proposals: the task and its target day."
  (cons (org-queue-horizon-key (plist-get item :task))
        (or (plist-get item :to) (plist-get item :from))))

(defun org-queue--mark (item)
  (alist-get (org-queue--item-key item) org-queue--marks nil nil #'equal))

(defun org-queue--set-mark (item mark)
  (setf (alist-get (org-queue--item-key item) org-queue--marks nil nil #'equal)
        mark))

(defun org-queue--propose (from to)
  "Build the proposal for FROM to TO from the files as they are."
  (let* ((simulated (org-queue--simulate from to t))
         (rejected (mapcar (lambda (e) (cons (car e) (nth 1 e)))
                           (org-queue--rejections))))
    (org-queue-core-proposal (cdr simulated) (car simulated) rejected)))

(defun org-queue--actions (&optional kind)
  (cl-remove-if-not (lambda (item)
                      (and (plist-get item :action)
                           (or (null kind) (eq (plist-get item :action) kind))))
                    org-queue--proposal))

(defun org-queue--proposal-summary ()
  (let* ((actions (org-queue--actions))
         (accepted (cl-remove-if-not (lambda (i) (eq (org-queue--mark i) 'accept)) actions))
         (rejected (cl-count 'reject actions :key #'org-queue--mark))
         (minutes (cl-reduce #'+ (mapcar (lambda (i) (or (plist-get i :minutes) 0)) accepted)
                             :initial-value 0)))
    (format "%d to schedule, %d to move, %d to unschedule, %d finding%s;  %d accepted (%s), %d rejected"
            (length (org-queue--actions 'schedule))
            (length (org-queue--actions 'move))
            (length (org-queue--actions 'unschedule))
            (cl-count-if (lambda (i) (plist-get i :finding)) org-queue--proposal)
            (if (= 1 (cl-count-if (lambda (i) (plist-get i :finding)) org-queue--proposal)) "" "s")
            (length accepted)
            (org-queue-core-format-minutes minutes)
            rejected)))

(defun org-queue--insert-item (item)
  "Insert one proposal ITEM as a task line with its mark and its why."
  (let ((mark (org-queue--mark item))
        (start (point)))
    (org-queue--insert (pcase mark ('accept " + ") ('reject " - ") (_ "   "))
                       (pcase mark ('accept 'org-queue-accepted) (_ 'org-queue-detail)))
    (org-queue--insert-task
     (plist-get item :task)
     (pcase (plist-get item :action)
       ('schedule (format "-> %s   %s" (org-queue--iso (plist-get item :to))
                          (plist-get item :why)))
       ('move (format "%s -> %s   %s" (org-queue--iso (plist-get item :from))
                      (org-queue--iso (plist-get item :to)) (plist-get item :why)))
       ('unschedule (format "drop %s   %s" (org-queue--iso (plist-get item :from))
                            (plist-get item :why)))
       (_ (plist-get item :text))))
    (add-text-properties start (point)
                         (list 'org-queue-item item
                               'org-queue-date (plist-get item :date)))
    (when (eq mark 'reject)
      (add-face-text-property start (point) 'org-queue-rejected))))

(defun org-queue--draw-proposal ()
  "Draw `org-queue--proposal' in the current buffer."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (org-queue--insert
     (format "Proposal %s\n" (org-queue--range-string (car org-queue--range)
                                                        (cdr org-queue--range)))
     'org-queue-header)
    (org-queue--insert (format "   %s\n" (org-queue--proposal-summary))
                       'org-queue-detail)
    (org-queue--insert-legend)
    (org-queue--insert
     "   a/r accept/reject line or region   A/R the day   C-c C-a all   e change day   C-c C-c apply   q abandon\n"
     'org-queue-detail)
    ;; Placements by day.
    (let ((days (sort (delete-dups
                       (mapcar (lambda (i) (plist-get i :date))
                               (append (org-queue--actions 'schedule)
                                       (org-queue--actions 'move))))
                      #'<)))
      (dolist (day days)
        (let ((items (cl-remove-if-not
                      (lambda (i) (and (memq (plist-get i :action) '(schedule move))
                                       (eql (plist-get i :date) day)))
                      org-queue--proposal)))
          (org-queue--insert
           (format "\n%s   %s\n" (org-queue--day-label day)
                   (org-queue-core-format-minutes
                    (cl-reduce #'+ (mapcar (lambda (i) (or (plist-get i :minutes) 0)) items)
                               :initial-value 0)))
           'org-queue-section)
          (put-text-property (line-beginning-position 0) (point) 'org-queue-day day)
          (dolist (item items) (org-queue--insert-item item)))))
    (when-let* ((drops (org-queue--actions 'unschedule)))
      (org-queue--insert "\nUnschedule\n" 'org-queue-section)
      (dolist (item drops) (org-queue--insert-item item)))
    (when-let* ((findings (cl-remove-if-not (lambda (i) (plist-get i :finding))
                                            org-queue--proposal)))
      (org-queue--insert "\nFindings (nothing proposed; yours to decide)\n" 'org-queue-section)
      (dolist (item findings) (org-queue--insert-item item)))
    (unless org-queue--proposal
      (org-queue--insert "\nNothing to propose: the files already say what the simulation says.\n"
                         'org-queue-detail))
    (goto-char (point-min))))

(defun org-queue--item-at-point ()
  (get-text-property (point) 'org-queue-item))

(defun org-queue--items-in-region ()
  "Return the actionable items on the lines of the active region, or at point."
  (let (items)
    (if (use-region-p)
        (save-excursion
          (goto-char (region-beginning))
          (while (< (point) (region-end))
            (when-let* ((item (org-queue--item-at-point)))
              (when (plist-get item :action) (cl-pushnew item items)))
            (forward-line 1)))
      (when-let* ((item (org-queue--item-at-point)))
        (when (plist-get item :action) (push item items))))
    (nreverse items)))

(defun org-queue--mark-items (items mark)
  (unless items (user-error "No proposed action here"))
  (dolist (item items) (org-queue--set-mark item mark))
  (let ((line (line-number-at-pos)))
    (org-queue--draw-proposal)
    (forward-line (1- line))
    (deactivate-mark)))

(defun org-queue-proposal-accept ()
  "Accept the action at point, or every action in the region."
  (interactive)
  (org-queue--mark-items (org-queue--items-in-region) 'accept))

(defun org-queue-proposal-reject ()
  "Reject the action at point, or every action in the region."
  (interactive)
  (org-queue--mark-items (org-queue--items-in-region) 'reject))

(defun org-queue--items-of-day ()
  (let ((day (or (get-text-property (point) 'org-queue-day)
                 (get-text-property (point) 'org-queue-date)
                 (user-error "Not on a day"))))
    (cl-remove-if-not (lambda (i) (and (plist-get i :action) (eql (plist-get i :date) day)))
                      org-queue--proposal)))

(defun org-queue-proposal-accept-day ()
  "Accept every action on the day at point."
  (interactive)
  (org-queue--mark-items (org-queue--items-of-day) 'accept))

(defun org-queue-proposal-reject-day ()
  "Reject every action on the day at point."
  (interactive)
  (org-queue--mark-items (org-queue--items-of-day) 'reject))

(defun org-queue-proposal-accept-all ()
  "Accept every proposed action."
  (interactive)
  (org-queue--mark-items (org-queue--actions) 'accept))

(defun org-queue-proposal-edit-day ()
  "Change the day the action at point places its task on.
The placement then counts as yours: it is written without the stamp."
  (interactive)
  (let ((item (or (org-queue--item-at-point) (user-error "No proposed action here"))))
    (unless (memq (plist-get item :action) '(schedule move))
      (user-error "Only a placement can be moved"))
    (let ((date (org-queue-harvest--date
                 (org-read-date nil t nil (format "Place %s on: "
                                                  (plist-get (plist-get item :task) :title))))))
      (setq org-queue--proposal
            (mapcar (lambda (i)
                      (if (eq i item)
                          (let ((edited (copy-sequence i)))
                            (setq edited (plist-put edited :to date))
                            (setq edited (plist-put edited :date date))
                            (setq edited (plist-put edited :human t))
                            (setq edited (plist-put edited :why
                                                    (format "your choice (was %s)" (plist-get i :why))))
                            (org-queue--set-mark edited 'accept)
                            edited)
                        i))
                    org-queue--proposal))
      (org-queue--draw-proposal))))

(defun org-queue-proposal-refresh ()
  "Propose again for the same range, keeping marks on unchanged lines."
  (interactive)
  (setq org-queue--proposal (org-queue--propose (car org-queue--range) (cdr org-queue--range)))
  (org-queue--draw-proposal)
  (message "%s" (org-queue--proposal-summary)))

(defun org-queue-proposal-apply ()
  "Write the accepted actions, remember the rejected ones, propose again."
  (interactive)
  (let* ((actions (org-queue--actions))
         (accepted (cl-remove-if-not (lambda (i) (eq (org-queue--mark i) 'accept)) actions))
         (rejected (cl-remove-if-not (lambda (i) (eq (org-queue--mark i) 'reject)) actions)))
    (unless (or accepted rejected)
      (user-error "Nothing accepted or rejected; a / r mark lines first"))
    (when accepted
      (org-queue-apply-actions
       (mapcar (lambda (item)
                 (pcase (plist-get item :action)
                   ((or 'schedule 'move)
                    (list :action 'schedule :task (plist-get item :task)
                          :to (plist-get item :to)
                          :placed (not (plist-get item :human))))
                   ('unschedule
                    (list :action 'unschedule :task (plist-get item :task)))))
               accepted)
       (format "proposal %s" (org-queue--range-string (car org-queue--range)
                                                       (cdr org-queue--range)))))
    (org-queue--record-rejections
     (mapcar (lambda (item) (cons (org-queue-horizon-key (plist-get item :task))
                                  (plist-get item :to)))
             (cl-remove-if-not (lambda (i) (plist-get i :to)) rejected)))
    (message "Applied %d, rejected %d; %s to undo"
             (length accepted) (length rejected)
             (substitute-command-keys "\\[org-queue-undo-apply]"))
    (setq org-queue--marks nil)
    (org-queue-proposal-refresh)
    (when-let* ((buffer (get-buffer org-queue-buffer-name)))
      (with-current-buffer buffer (org-queue-refresh)))))

(defvar-keymap org-queue-proposal-mode-map
  :doc "Keymap for `org-queue-proposal-mode'."
  :parent org-queue-mode-map
  "a"       #'org-queue-proposal-accept
  "r"       #'org-queue-proposal-reject
  "A"       #'org-queue-proposal-accept-day
  "R"       #'org-queue-proposal-reject-day
  "C-c C-a" #'org-queue-proposal-accept-all
  "e"       #'org-queue-proposal-edit-day
  "g"       #'org-queue-proposal-refresh
  "C-c C-c" #'org-queue-proposal-apply
  ;; The single-line writers make no sense on a proposal: unbind them.
  "S" nil "L" nil "N" nil "H" nil "U" nil)

(define-derived-mode org-queue-proposal-mode org-queue-mode "Proposal"
  "Major mode for reviewing a scheduling proposal.

\\{org-queue-proposal-mode-map}"
  (setq org-queue--redraw-function #'org-queue--draw-proposal))

;;;###autoload
(defun org-queue-propose (from to)
  "Propose placements for the days FROM to TO and show them for review.
Interactively, ask for a scope.  Nothing is written until \\<org-queue-proposal-mode-map>\\[org-queue-proposal-apply]."
  (interactive (let ((range (org-queue--read-scope)))
                 (list (car range) (cdr range))))
  (let ((buffer (get-buffer-create org-queue-proposal-buffer-name)))
    (with-current-buffer buffer
      (org-queue-proposal-mode)
      (setq org-queue--columns (copy-sequence org-queue-columns))
      (setq org-queue--range (cons from to))
      (setq org-queue--marks nil)
      (setq org-queue--proposal (org-queue--propose from to))
      (org-queue--draw-proposal))
    (pop-to-buffer buffer)
    (with-current-buffer buffer
      (message "%s" (org-queue--proposal-summary)))))

(provide 'org-queue-propose)
;;; org-queue-propose.el ends here
