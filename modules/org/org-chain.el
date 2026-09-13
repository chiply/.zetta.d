;;; org-chain.el --- Configure org-chain -*- lexical-binding: t; -*-

;; Thin wrapper around the in-tree `org-chain' package (under
;; `source/zettapkg/').  G16 of productivity.org: an agent has the ball.
;;
;;   ,-o-i        kick the entry at point (C-u past the limit, C-u C-u headless)
;;   ,-o-v a      the Chains view: in flight, landed for review, asking
;;   (auto)       the landing log is watched; AGENT becomes NEXT or QUES
;;
;; The Claude Code hooks (Stop and Notification) append one plist per
;; line to .data/org/agent-landings.el -- see ~/.claude/claude-landing.sh
;; in the .files repo -- and nothing else: no elisp is evaluated from a
;; hook, and no landing raises a prompt.  A question is a mark in the
;; mode line; a stop is a notification, held during the routine's quiet
;; windows.
;;
;; The AGENT keyword itself is added to `org-todo-keywords' in org.el,
;; after PROG; `org-gantt-machine-states' already names it, so its
;; intervals are machine minutes in their own lane, never a human total;
;; the queue excludes it with reason `in-flight' and plans a landed
;; entry at `org-queue-review-share' of its effort.

(defvar zetta-org-agenda-day-groups)
(defvar org-queue-close-chains-function)
(defvar org-queue-review-chains-function)
(defvar org-queue-morning-line-function)

(use-package org-chain
  :ensure nil
  :load-path "source/zettapkg/org-chain"
  :commands (org-chain-kick org-chain-land org-chain-watch org-chain-unwatch
             org-chain-kick-due org-chain-chains)
  :init
  (setq org-chain-landings-file
        (expand-file-name ".data/org/agent-landings.el" user-emacs-directory)
        org-chain-applied-file
        (expand-file-name ".data/org/agent-landings-applied.el" user-emacs-directory))
  ;; The close, the pack and the morning report each get their line the
  ;; moment the queue is up; the watch starts then too, so a landing
  ;; that arrives while you are away is applied when you look.
  (with-eval-after-load 'org-queue
    (require 'org-chain)
    (setq org-queue-close-chains-function #'org-chain-close-chains
          org-queue-review-chains-function #'org-chain-review-lines
          org-queue-morning-line-function #'org-chain-morning-line)
    (org-chain-watch)
    ;; KICK_AT entries: checked every ten minutes, kicked headless only.
    (run-with-timer 600 600 #'org-chain-kick-due)))

;; Three groups for the Day view: what landed is beside NEXT at the top,
;; what is in flight and what is asking come after the work you are doing.
(with-eval-after-load 'org-super-agenda
  (setq zetta-org-agenda-day-groups
        (append
         '((:name "Landed -- review" :and (:todo "NEXT" :pred zetta-org-agenda-landed-p) :order -2))
         (cl-remove-if (lambda (group) (member (plist-get group :name)
                                               '("Landed -- review" "In flight" "Agent asks")))
                       zetta-org-agenda-day-groups)
         '((:name "In flight -- an agent has it" :todo "AGENT" :order 5)
           (:name "Agent asks" :and (:todo "QUES" :property "AGENT_SESSION") :order 6)))))

(defun zetta-org-agenda-landed-p (item)
  "Non-nil if agenda ITEM is NEXT straight from AGENT."
  (when-let* ((marker (zetta-org-agenda--marker item)))
    (require 'org-chain)
    (org-with-point-at marker
      (org-chain-core-landed-p
       (mapcar (lambda (cell) (cons (car cell) (floor (float-time (cdr cell)))))
               (org-queue-state-log))))))

(declare-function zetta-org-agenda--marker "org-super-agenda" (item))
(declare-function org-queue-state-log "org-queue-harvest" (&optional pom))
(declare-function org-chain-core-landed-p "org-chain-core" (transitions))

(with-eval-after-load 'org-agenda
  (require 'org-chain)
  (add-to-list 'org-agenda-custom-commands
               '("a" "Chains -- in flight, landed, asking"
                 ((org-ql-block '(todo "AGENT")
                                ((org-ql-block-header "In flight -- an agent has it")))
                  (org-ql-block '(and (todo "NEXT") (landed-from-agent))
                                ((org-ql-block-header "Landed -- review, then d / a / n")))
                  (org-ql-block '(agent-asks)
                                ((org-ql-block-header "Agent asks -- answer in the session")))))
               t))

(general-define-key
 :keymaps 'menu-org-map
 "i" 'org-chain-kick)
;;; org-chain.el ends here
