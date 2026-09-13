;;; slack.el --- Configure emacs-slack -*- lexical-binding: t; -*-

;; Workspaces are registered from `zetta-slack-teams', set in
;; ~/.private.el, never from literals here: a workspace name is an
;; employer identifier (work-security-audit.org S3).  The token and
;; cookie for each team come from auth-source on the team's host and
;; user; slack.md explains how to obtain and store them.  With
;; `zetta-slack-teams' nil the package is neither installed nor loaded.

(defvar zetta-slack-teams nil
  "Slack workspaces to register, a list of plists.
Each is (:name NAME :host HOST :user USER [:default t]).  NAME is a
label of your choosing, HOST the workspace's Slack domain
\(\"acme.slack.com\") and USER the login under which auth-source holds
the two credentials:

  machine HOST login USER        password xoxc-...
  machine HOST login USER^cookie password d=...

Set in ~/.private.el; see .private.sample.el.  Nil leaves this module
inert.")

(use-package slack
  :if zetta-slack-teams
  :commands (slack-start slack-select-rooms slack-select-unread-rooms)
  :custom
  (slack-prefer-current-team t)
  (slack-quick-update t)
  :config
  ;; A team whose token auth-source cannot supply is reported and skipped
  ;; rather than allowed to abort the whole :config (`slack-register-team'
  ;; signals on a nil :token).
  (dolist (team zetta-slack-teams)
    (let* ((host (plist-get team :host))
           (user (plist-get team :user))
           (token (auth-source-pick-first-password :host host :user user))
           (cookie (auth-source-pick-first-password
                    :host host :user (concat user "^cookie"))))
      (if (not token)
          (message "slack: no token in auth-source for %s (login %s); team %s skipped"
                   host user (plist-get team :name))
        (slack-register-team
         :name (plist-get team :name)
         :token token
         :cookie cookie
         :full-and-display-names t
         :default (plist-get team :default))))))
;;; slack.el ends here
