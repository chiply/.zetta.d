(use-package org-jira
  :config

  (setq jiralib-url "https://genedx.atlassian.net")
  (setq org-jira-custom-jqls
        '(
          (:jql " assignee = currentUser() and sprint in openSprints() and project = 'ENGDPS' ORDER BY
  priority DESC, created ASC"
                :limit 1000
                :filename "My current tasks")
          ))
  )



