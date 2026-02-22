;;; git-link.el --- Configure git-link -*- lexical-binding: t; -*-

(use-package git-link
  :config
  (defun git-link-diffrent-branch (branch)
    "Invoke `git-link', but with the `branch' name set to a different
branch than the one you're currently working on."
    (interactive "P")
    (let* ((default-remote-branch-name "main")
           (git-link-current-branch-setting git-link-default-branch)
           (git-link-default-branch
            (if branch
                (completing-read
                 (format
                  "Instead of '%s' branch replace with branch: "
                  (git-link--branch))
                 (magit-list-branch-names))
              default-remote-branch-name)))
      (setq current-prefix-arg nil)
      (call-interactively 'git-link)
      (setq git-link-default-branch git-link-current-branch-setting))))
;;; git-link.el ends here
