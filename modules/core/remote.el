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

(defun zetta-ssh ()
  "A function to conveniently ssh into a server"
  (interactive)
  (let* ((host (completing-read "Choose a server: " '("debian_droplet"
                                                      "som")))
         (default-directory (concat "/ssh:" host ":/")))
    (call-interactively 'find-file)
    )
  )

(defun zetta-ssh-shell ()
  "A function to conveniently ssh into a server"
  (interactive)
  (let* ((host (completing-read "Choose a server: " '("debian_droplet"
                                                      "som")))
         (nm (concat "*ssh-" host "-" (completing-read "Name: " '()) "*"))
         (cmd (concat "ssh " host "\n"))
         )
    (vterm nm)
    (process-send-string nm cmd)
    )
  )
;;; remote.el ends here
