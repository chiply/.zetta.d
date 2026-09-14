;;; org-knowledge.el --- Configure org-knowledge -*- lexical-binding: t; -*-

;; Thin wrapper around the in-tree `org-knowledge' package (under
;; `source/zettapkg/').  G10 of productivity.org, the knowledge loop:
;;
;;   ,-o-M    promote the heading at point to a HyWiki page (Make a page):
;;            the body moves verbatim, one link with the reason you type
;;            stays behind
;;   ,-o-R    resurface the page untouched longest, beside the rolo hits
;;            that mention it
;;   M-x org-knowledge-on-this-day   the rolo a year and a month back
;;
;; The pages live in `hywiki-directory' (~/kb/wiki), named by WikiWord;
;; no org-roam, no renaming.  FavouriteProblems.org's headings are the
;; favourite problems; decoration scores each capture against them and
;; writes AI_PROBLEM.  Anki is not wired: the cards stay in the notes and
;; the push (org-anki or anki-editor) is a later, optional step.

(defvar hywiki-directory)

(use-package org-knowledge
  :ensure nil
  :load-path "source/zettapkg/org-knowledge"
  :commands (org-knowledge-promote org-knowledge-resurface org-knowledge-on-this-day
             org-knowledge-problems)
  :init
  (with-eval-after-load 'hyperbole
    (require 'org-knowledge)
    (setq org-knowledge-directory (zetta-kb-file "wiki")))
  ;; Decoration scores captures against the favourite problems.
  (with-eval-after-load 'org-decorate-lists
    (require 'org-knowledge)
    (setq org-decorate-problems-function #'org-knowledge-problems)))

(defvar org-decorate-problems-function)

(general-define-key
 :keymaps 'menu-org-map
 "M" 'org-knowledge-promote
 "R" 'org-knowledge-resurface)
;;; org-knowledge.el ends here
