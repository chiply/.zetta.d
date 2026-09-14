;;; remote.el --- Configure remote editing -*- lexical-binding: t; -*-

(setq tramp-default-method "ssh")
(setq tramp-shell-prompt-pattern "\\(?:^\\|\r\\)[^]#$%>\n]*#?[]#$%>].* *\\(^[\\[[0-9;]*[a-zA-Z] *\\)*")

;; stuff to speed up tramp
;; probably doesn't have a significant affect
(setq remote-file-name-inhibit-cache nil)
(setq vc-ignore-dir-regexp
      (format "%s\\|%s"
              vc-ignore-dir-regexp
              tramp-file-name-regexp))
(setq tramp-verbose 1)

;; Hosts for `zetta-ssh' and `zetta-ssh-shell' come from `zetta-ssh-hosts'
;; when it is set (in ~/.private.el), else from the Host entries of the
;; ssh client config.  No host name lives in this module: a host is a
;; personal or an employer identifier (work-security-audit.org S3, WP-Z5).

(defvar zetta-ssh-hosts nil
  "Hosts offered by `zetta-ssh' and `zetta-ssh-shell'.
Nil means the Host aliases of `zetta-ssh-config-file' (wildcard and
negated patterns skipped, Include directives followed).  Set in
~/.private.el to override.")

(defvar zetta-ssh-config-file "~/.ssh/config"
  "The ssh client configuration `zetta-ssh-config-hosts' reads.")

(defun zetta-ssh-config-hosts (&optional file)
  "Host aliases declared in the ssh config FILE.
FILE defaults to `zetta-ssh-config-file'.  Include directives are
followed (relative to ~/.ssh), patterns containing * ? or ! are
skipped, and the result keeps first-seen order without duplicates."
  (let ((file (expand-file-name (or file zetta-ssh-config-file)))
        hosts)
    (when (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (re-search-forward
                "^[ \t]*\\(host\\|include\\)[ \t=]+\\([^\n]*?\\)[ \t]*$" nil t)
          (let ((keyword (downcase (match-string 1)))
                (args (split-string (match-string 2))))
            (if (string= keyword "include")
                (dolist (pattern args)
                  (dolist (included (file-expand-wildcards
                                     (expand-file-name pattern "~/.ssh/")))
                    (dolist (host (zetta-ssh-config-hosts included))
                      (unless (member host hosts) (push host hosts)))))
              (dolist (host args)
                (unless (or (string-match-p "[*?!]" host) (member host hosts))
                  (push host hosts))))))))
    (nreverse hosts)))

(defun zetta-ssh--hosts ()
  "The candidate list: `zetta-ssh-hosts', or the ssh config's Host aliases."
  (or zetta-ssh-hosts (zetta-ssh-config-hosts)))

(defun zetta-ssh ()
  "Open a directory on a remote host over TRAMP."
  (interactive)
  (let* ((host (completing-read "Choose a server: " (zetta-ssh--hosts)))
         (default-directory (concat "/ssh:" host ":/")))
    (call-interactively 'find-file)))

(defun zetta-ssh-shell ()
  "Open a vterm and ssh into a remote host."
  (interactive)
  (let* ((host (completing-read "Choose a server: " (zetta-ssh--hosts)))
         (nm (concat "*ssh-" host "-" (completing-read "Name: " '()) "*"))
         (cmd (concat "ssh " host "\n")))
    (vterm nm)
    (process-send-string nm cmd)))
;;; remote.el ends here
