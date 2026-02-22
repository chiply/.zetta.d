;;; jira.el --- Configure org-jira -*- lexical-binding: t; -*-

(use-package org-jira
  :config

  (setq jiralib-url "https://REMOVED-EMPLOYER.atlassian.net")
  (setq org-jira-custom-jqls
        '(
          (:jql " assignee = currentUser() and sprint in openSprints() and project = 'REMOVED-PROJECT' ORDER BY
  priority DESC, created ASC"
                :limit 1000
                :filename "My current tasks")
          ))
  )
;;; jira.el ends here
