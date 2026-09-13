;;; org-decorate.el --- Configure org-decorate -*- lexical-binding: t; -*-

;; Thin wrapper around the in-tree `org-decorate' package (under
;; `source/zettapkg/').  G1 of productivity.org: the inbox is classified
;; against the config's own lists by a model, the proposals land as AI_*
;; properties, and one key per entry accepts them.
;;
;;   ,-o-f          decorate the inbox on demand (`org-decorate-inbox')
;;   ,-o-v i        the Inbox view, with its groups: captured before,
;;                  proposed (confirm), stale date, undecorated; and the
;;                  commit-evidence block
;;   C-c a / C-c e / C-c r   in the agenda or on the entry: accept all,
;;                  accept one field, reject.  C-c d decorates this one.
;;
;; The model is local by default (Ollama's qwen2.5:7b, already installed
;; for the router) and the inbox never leaves the machine;
;; `org-decorate-backend' set to `claude' sends it to Claude through the
;; gptel backend registered in modules/tools/ai.el.  A :private: entry
;; is never sent either way.  The idle timer the assay mentioned is not
;; wired: the first week says whether the proposals are worth having.
;;
;; The corrections file lives with the other unsynced state under
;; .data/org/, because it contains inbox text.

(defvar zetta-org-agenda-inbox-groups)

(use-package org-decorate
  :ensure nil
  :load-path "source/zettapkg/org-decorate"
  :commands (org-decorate-inbox org-decorate-this org-decorate-accept
             org-decorate-accept-field org-decorate-reject org-decorate-edit
             org-decorate-strip-all org-decorate-git-evidence
             org-decorate-enable-capture-hooks)
  :init
  (setq org-decorate-corrections-file
        (expand-file-name ".data/org/decoration-corrections.el" user-emacs-directory)
        org-decorate-inbox-file "~/kb/inbox.org")
  ;; The repositories whose commits may name an entry: the kb, plus
  ;; whatever ~/.private.el lists in `zetta-git-repos'.
  (setq org-decorate-git-repos
        (append '("~/kb") (bound-and-true-p zetta-git-repos)))
  ;; Every capture is checked for a duplicate once org-capture is up.
  (with-eval-after-load 'org-capture
    (require 'org-decorate)
    (org-decorate-enable-capture-hooks))
  ;; Commits join the day log.
  (with-eval-after-load 'org-queue-daylog
    (require 'org-decorate)
    (add-to-list 'org-queue-daylog-extra-functions #'org-decorate-git-day-events))
  :config
  ;; The three keys, in the agenda and in any Org buffer.  `C-c LETTER'
  ;; is the user's space, so nothing of Org's is shadowed.
  (with-eval-after-load 'org-agenda
    (define-key org-agenda-mode-map (kbd "C-c a") #'org-decorate-accept)
    (define-key org-agenda-mode-map (kbd "C-c e") #'org-decorate-accept-field)
    (define-key org-agenda-mode-map (kbd "C-c r") #'org-decorate-reject)
    (define-key org-agenda-mode-map (kbd "C-c d") #'org-decorate-this))
  (with-eval-after-load 'org
    (define-key org-mode-map (kbd "C-c a") #'org-decorate-accept)
    (define-key org-mode-map (kbd "C-c e") #'org-decorate-accept-field)
    (define-key org-mode-map (kbd "C-c r") #'org-decorate-reject)
    (define-key org-mode-map (kbd "C-c d") #'org-decorate-this)))

(defvar org-queue-daylog-extra-functions)

;; The Inbox view's groups, decoration-aware.  Matched in list order, so
;; a duplicate is named before its proposal is, and a stale date before a
;; plain proposal.
(with-eval-after-load 'org-super-agenda
  (setq zetta-org-agenda-inbox-groups
        '((:name "Captured before -- a duplicate of an open entry" :property "DUPLICATE_OF" :order 0)
          (:name "Proposed, but the date has passed -- confirm or edit" :property "AI_DATE_STALE" :order 1)
          (:name "Proposed -- C-c a accepts, C-c e one field, C-c r rejects" :property "AI_HASH" :order 2)
          (:name "Not yet a task -- decide what it is" :not (:todo t) :order 3)
          (:name "A task -- refile it somewhere" :todo t :order 4))))

(general-define-key
 :keymaps 'menu-org-map
 "f" 'org-decorate-inbox)
;;; org-decorate.el ends here
