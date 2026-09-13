;;; init.el --- Configure Emacs initialization -*- lexical-binding: t; -*-

;; load init data
(add-to-list 'load-path (expand-file-name "source/init-data" user-emacs-directory))
(require 'init-data)

;; bootstrap
(add-to-list 'load-path (expand-file-name "source/bootstrap" user-emacs-directory))
(require 'bootstrap)

;; install mandatory config files
(-each zetta-files-that-need-creating 'zetta-touch-maybe)

;; Customize writes to `custom-file', and into the init file when that
;; is unset -- which is how a laptop's host name once landed in this
;; tracked file (work-security-audit.org S3).  Default it under .data/
;; (gitignored) before ~/.zetta.el loads, so a profile may still choose
;; another path.  It is loaded at the end of this file, after the modules.
(setq custom-file (expand-file-name ".data/custom.el" user-emacs-directory))

;; load user module config (~/.zetta.el) if it exists
;; this can call `zetta-modules!' to override the default user-files
(let ((zetta-config (expand-file-name "~/.zetta.el")))
  (when (file-exists-p zetta-config)
    (load-file zetta-config)))

;; Secrets -- needed by ~/.private.el before the modules load.  The cache,
;; its loader and the auth-source bridge live in bootstrap-secrets.el; it
;; is loaded HERE, after ~/.zetta.el, because that file decides the
;; backend (`zetta-secrets-backend'): a personal 1Password vault, an
;; employer's vault through a command, Emacs's own authinfo files, or
;; none at all.  secrets.md describes the design.
(require 'bootstrap-secrets)

;; load private.el early (before config files that need API keys)
(load-file "~/.private.el")

;; load user config files
(let ((prev-category nil))
  (dolist (pkg user-files)
    (let ((category (file-name-directory pkg)))
      (when (and prev-category (not (string= category prev-category)))
        (elpaca-wait))
      (setq prev-category category)
      (zetta-load-config-file pkg))))

(elpaca-process-queues)

;; Bookmarks file (set before custom-set-variables to override)
(setq bmkp-last-as-first-bookmark-file
      (expand-file-name "bookmarks" user-emacs-directory))

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(bmkp-last-as-first-bookmark-file "~/.zetta.d/bookmarks" t)
 '(connection-local-criteria-alist
   '(((:application tramp :machine "localhost")
      tramp-connection-local-darwin-ps-profile)
     ((:application tramp)
      tramp-connection-local-default-system-profile
      tramp-connection-local-default-shell-profile)
     ((:application eshell) eshell-connection-default-profile)))
 '(connection-local-profile-alist
   '((tramp-connection-local-darwin-ps-profile
      (tramp-process-attributes-ps-args "-acxww" "-o"
                                        "pid,uid,user,gid,comm=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                        "-o" "state=abcde" "-o"
                                        "ppid,pgid,sess,tty,tpgid,minflt,majflt,time,pri,nice,vsz,rss,etime,pcpu,pmem,args")
      (tramp-process-attributes-ps-format (pid . number)
                                          (euid . number)
                                          (user . string)
                                          (egid . number) (comm . 52)
                                          (state . 5) (ppid . number)
                                          (pgrp . number)
                                          (sess . number)
                                          (ttname . string)
                                          (tpgid . number)
                                          (minflt . number)
                                          (majflt . number)
                                          (time . tramp-ps-time)
                                          (pri . number)
                                          (nice . number)
                                          (vsize . number)
                                          (rss . number)
                                          (etime . tramp-ps-time)
                                          (pcpu . number)
                                          (pmem . number) (args)))
     (tramp-connection-local-busybox-ps-profile
      (tramp-process-attributes-ps-args "-o"
                                        "pid,user,group,comm=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                        "-o" "stat=abcde" "-o"
                                        "ppid,pgid,tty,time,nice,etime,args")
      (tramp-process-attributes-ps-format (pid . number)
                                          (user . string)
                                          (group . string) (comm . 52)
                                          (state . 5) (ppid . number)
                                          (pgrp . number)
                                          (ttname . string)
                                          (time . tramp-ps-time)
                                          (nice . number)
                                          (etime . tramp-ps-time)
                                          (args)))
     (tramp-connection-local-bsd-ps-profile
      (tramp-process-attributes-ps-args "-acxww" "-o"
                                        "pid,euid,user,egid,egroup,comm=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                        "-o"
                                        "state,ppid,pgid,sid,tty,tpgid,minflt,majflt,time,pri,nice,vsz,rss,etimes,pcpu,pmem,args")
      (tramp-process-attributes-ps-format (pid . number)
                                          (euid . number)
                                          (user . string)
                                          (egid . number)
                                          (group . string) (comm . 52)
                                          (state . string)
                                          (ppid . number)
                                          (pgrp . number)
                                          (sess . number)
                                          (ttname . string)
                                          (tpgid . number)
                                          (minflt . number)
                                          (majflt . number)
                                          (time . tramp-ps-time)
                                          (pri . number)
                                          (nice . number)
                                          (vsize . number)
                                          (rss . number)
                                          (etime . number)
                                          (pcpu . number)
                                          (pmem . number) (args)))
     (tramp-connection-local-default-shell-profile
      (shell-file-name . "/bin/sh") (shell-command-switch . "-c"))
     (tramp-connection-local-default-system-profile
      (path-separator . ":") (null-device . "/dev/null"))
     (eshell-connection-default-profile (eshell-path-env-list))))
 '(custom-safe-themes
   '("b2fedbd478e90e41360d033506fb2bd42b8594fe472e48db94284dca85eebb79"
     "1b7e575c6681e66d8d83634c2c160b40af12f3756360a4dd81b8032f4495cb5e"
     "4c7228157ba3a48c288ad8ef83c490b94cb29ef01236205e360c2c4db200bb18"
     default))
 '(helm-minibuffer-history-key "M-p")
 '(org-fold-core-style 'overlays)
 '(org-safe-remote-resources '("\\`https://fniessen\\.github\\.io\\(?:/\\|\\'\\)"))
 '(warning-suppress-log-types '((native-compiler))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(cursor ((t (:background "gray"))))
 '(header-line-inactive ((t (:background unspecified :foreground unspecified :inherit header-line)))))

;; Per-machine Customize saves, loaded last so they win over the modules.
;; The directory must exist for `custom-save-all' to write there.
(when (stringp custom-file)
  (make-directory (file-name-directory custom-file) t)
  (when (file-exists-p custom-file)
    (load custom-file nil 'nomessage)))
;;; init.el ends here
