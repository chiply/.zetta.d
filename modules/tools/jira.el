;;; jira.el --- Configure org-jira -*- lexical-binding: t; -*-

;; Nothing employer-specific lives in this file.  The instance URL and
;; the saved JQL queries are read from ~/.private.el (the shape is in
;; .private.sample.el); an employer's identifier is exactly the kind of
;; value that must never sit in a tracked module (work-security-audit.org
;; S3, work-profile.org Part 5).  With `zetta-jira-url' nil the package
;; is neither installed nor loaded.

(defvar zetta-jira-url nil
  "Base URL of the Jira instance org-jira talks to.
For example \"https://example.atlassian.net\".  Set in ~/.private.el;
nil leaves this module inert.")

(defvar zetta-jira-jqls nil
  "Saved queries for `org-jira-custom-jqls'.
A list of plists (:jql STRING :limit N :filename STRING).  Set in
~/.private.el; see .private.sample.el for the shape.")

(defvar zetta-jira-working-dir "~/kb/jira/"
  "Directory org-jira keeps its per-project org files in.")

(use-package org-jira
  :if zetta-jira-url
  :config
  (setq jiralib-url zetta-jira-url
        org-jira-custom-jqls zetta-jira-jqls
        org-jira-working-dir (expand-file-name zetta-jira-working-dir))
  (make-directory org-jira-working-dir t))
;;; jira.el ends here
