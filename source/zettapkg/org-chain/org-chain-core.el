;;; org-chain-core.el --- Agent chains: kick, flight, landing, review -- arithmetic -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, outlines

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Most code is written by an agent you kick off and review, ten to
;; twenty minutes later, several at a time.  One state, AGENT, says an
;; agent has the ball; the lifecycle uses states that already exist:
;; PROG while you write the prompt, AGENT on kickoff, NEXT when the run
;; finished (you committed to the review the moment you kicked it off)
;; or QUES when the agent stopped to ask, PROG while you review, then
;; DONE, AGENT again, or NOPE.  Every hop is a logged transition, so the
;; derived clock gets the split for free.
;;
;; This file has no Org and no terminal in it: the prompt from an entry,
;; the kick rule, the landing log applied idempotently, the metrics per
;; chain, the expected-landings arithmetic, and the landed predicate.
;;
;; An entry plist here carries `:state', `:body', `:children' (a list of
;; (TITLE . BODY)), `:agent-session', `:kick-at', `:transitions' (a list
;; of (STATE . SECONDS), oldest first) and whatever else the harvest
;; adds.  A landing is (:session UUID :at SECONDS :cwd DIR :event stop|question :text STRING).

;;; Code:

(require 'cl-lib)

(defgroup org-chain nil
  "Agent chains: kick, flight, landing, review."
  :group 'org
  :prefix "org-chain-")

(defcustom org-chain-limit 3
  "How many chains may be in flight at once.
Three, with the report saying when two would do (Part 6 question 12)."
  :type 'integer
  :group 'org-chain)

(defcustom org-chain-agent-state "AGENT"
  "The state that says an agent has the ball."
  :type 'string
  :group 'org-chain)

(defcustom org-chain-prompt-heading "Prompt"
  "The sub-heading whose body is the prompt, when the entry holds notes too."
  :type 'string
  :group 'org-chain)

(defcustom org-chain-dawn 360
  "Minute of the day before which a KICK_AT run is unattended: 06:00."
  :type 'integer
  :group 'org-chain)


;;;; The prompt is the task

(defun org-chain-core-prompt (entry)
  "Return ENTRY's prompt, verbatim: the Prompt sub-heading's body, else the body.
Nil when there is neither, or it is blank."
  (let* ((child (cl-find org-chain-prompt-heading (plist-get entry :children)
                         :key #'car :test #'equal))
         (raw (or (and child (cdr child)) (plist-get entry :body) ""))
         ;; Verbatim: only the newlines around it go, never its spaces.
         (text (string-trim raw "\n+" "\n+")))
    (unless (string-blank-p text) text)))


;;;; Kicking

(defun org-chain-core-in-flight (entries)
  "Return the entries of ENTRIES an agent holds."
  (cl-remove-if-not (lambda (entry) (equal (plist-get entry :state) org-chain-agent-state))
                    entries))

(defun org-chain-core-kick-check (entry entries &optional override)
  "Return nil when ENTRY may be kicked, else the reason it may not.
ENTRIES is the corpus; OVERRIDE lifts the chain limit (and is logged
by the caller).  A refusal is a string."
  (cond
   ((null (org-chain-core-prompt entry)) "no prompt: the body, or a Prompt sub-heading, is the task")
   ((equal (plist-get entry :state) org-chain-agent-state) "already in flight")
   ((and (not override)
         (>= (length (org-chain-core-in-flight entries)) org-chain-limit))
    (format "%d chains in flight already; C-u kicks a %s anyway"
            org-chain-limit (if (= org-chain-limit 3) "fourth" "further one")))
   (t nil)))

(defun org-chain-core-kick-mode (entry interactive)
  "Return `interactive' or `headless' for kicking ENTRY, or a refusal.
An entry with KICK_AT runs unattended and only unattended: scheduling
an interactive session for the middle of the night is refused."
  (cond
   ((and (plist-get entry :kick-at) interactive)
    "a KICK_AT entry runs headless; C-u C-u, or remove KICK_AT")
   ((plist-get entry :kick-at) 'headless)
   (interactive 'interactive)
   (t 'headless)))

(defun org-chain-core-kick-due-p (entry now-minute)
  "Return non-nil if ENTRY's KICK_AT, a minute of the day, has arrived before dawn."
  (let ((at (plist-get entry :kick-at)))
    (and at (< at org-chain-dawn) (>= now-minute at))))

(defun org-chain-core-command (prompt session &optional headless)
  "Return the argument list that starts a session for PROMPT under SESSION.
The prompt is passed through untouched."
  (if headless
      (list "claude" "-p" "--session-id" session prompt)
    (list "claude" "--session-id" session prompt)))


;;;; Landing

(defun org-chain-core-landing-key (landing)
  "What identifies LANDING across reads: session, event and time."
  (list (plist-get landing :session) (plist-get landing :event) (plist-get landing :at)))

(defun org-chain-core-land (landings entries applied)
  "Turn LANDINGS into state actions over ENTRIES, skipping APPLIED keys.

Returns (:actions :orphans :applied):
  :actions   plists (:task ENTRY :to STATE :landing L) -- NEXT for a
             stop, QUES for a question -- for entries in AGENT whose
             AGENT_SESSION matches
  :orphans   landings no entry in AGENT owns, reported, never dropped
  :applied   APPLIED plus the keys of every landing consumed here
A landing already in APPLIED is skipped: a re-read applies nothing
twice."
  (let ((applied (copy-sequence applied))
        actions orphans)
    (dolist (landing landings)
      (let ((key (org-chain-core-landing-key landing)))
        (unless (member key applied)
          (push key applied)
          (let ((entry (cl-find-if
                        (lambda (entry)
                          (and (equal (plist-get entry :state) org-chain-agent-state)
                               (equal (plist-get entry :agent-session) (plist-get landing :session))))
                        entries)))
            (if (null entry)
                (push landing orphans)
              (push (list :task entry
                          :to (if (eq (plist-get landing :event) 'question) "QUES" "NEXT")
                          :landing landing)
                    actions)
              ;; The entry has landed: a second line for the same session
              ;; in this batch is an orphan, not a second transition.
              (setq entries (cl-remove entry entries)))))))
    (list :actions (nreverse actions) :orphans (nreverse orphans) :applied applied)))

(defun org-chain-core-landed-p (transitions)
  "Return non-nil if TRANSITIONS end in NEXT straight from AGENT."
  (let ((last (car (last transitions)))
        (before (car (last transitions 2))))
    (and last before
         (equal (car last) "NEXT")
         (equal (car before) org-chain-agent-state)
         t)))


;;;; Metrics

(defun org-chain-core-metrics (transitions &optional now)
  "Measure one chain from TRANSITIONS, (STATE . SECONDS) oldest first.

  :iterations  kicks: transitions into AGENT
  :machine     minutes in AGENT
  :human       minutes in PROG
  :latency     mean minutes from a kick to its landing (NEXT or QUES)
  :review-lag  mean minutes from a landing to the review (PROG)
  :in-flight   non-nil when the last state is AGENT
NOW closes an open AGENT interval."
  (let ((now (or now (float-time)))
        (iterations 0) (machine 0) (human 0)
        latencies lags
        kicked landed)
    (cl-loop for (transition . rest) on transitions
             do (let* ((state (car transition))
                       (start (cdr transition))
                       (end (if rest (cdr (car rest)) now))
                       (minutes (/ (- end start) 60.0)))
                  (cond
                   ((equal state org-chain-agent-state)
                    (cl-incf iterations)
                    (cl-incf machine minutes)
                    (setq kicked start landed nil))
                   ((member state '("PROG" "STARTED"))
                    (cl-incf human minutes)
                    (when landed
                      (push (/ (- start landed) 60.0) lags)
                      (setq landed nil)))
                   ((member state '("NEXT" "QUES"))
                    (when kicked
                      (push (/ (- start kicked) 60.0) latencies)
                      (setq kicked nil landed start))))))
    (list :iterations iterations
          :machine (round machine)
          :human (round human)
          :latency (and latencies (round (/ (apply #'+ latencies) (length latencies))))
          :review-lag (and lags (round (/ (apply #'+ lags) (length lags))))
          :in-flight (equal (car (car (last transitions))) org-chain-agent-state))))


;;;; The morning line

(defun org-chain-core-expected (chains latency cycle block)
  "Return what CHAINS in flight ask of a BLOCK of minutes.

Each chain lands every LATENCY + CYCLE minutes and each landing costs
you CYCLE minutes.  Returns (:landings :review :exceeds :enough), where
`:enough' is the most chains the block holds at these numbers -- the
line that says when two would do."
  (let* ((period (max 1 (+ latency cycle)))
         (per-chain (floor block period))
         (landings (* chains per-chain))
         (review (* landings cycle))
         (enough (if (> (* per-chain cycle) 0) (floor block (* per-chain cycle)) chains)))
    (list :landings landings
          :review review
          :exceeds (> review block)
          :enough (min chains (max 0 enough)))))

(defun org-chain-core-morning-line (chains latency cycle block)
  "Return one line for the morning report about CHAINS in flight."
  (if (zerop chains)
      "no chains in flight"
    (let ((expected (org-chain-core-expected chains latency cycle block)))
      (format "%d chain%s in flight: about %d landing%s in a %d-minute block, %d minutes of review%s"
              chains (if (= 1 chains) "" "s")
              (plist-get expected :landings) (if (= 1 (plist-get expected :landings)) "" "s")
              block (plist-get expected :review)
              (cond ((plist-get expected :exceeds)
                     (format " -- more than the block; %d would do" (plist-get expected :enough)))
                    (t ""))))))

(provide 'org-chain-core)
;;; org-chain-core.el ends here
