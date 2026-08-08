;;; init.el --- Configure Emacs initialization -*- lexical-binding: t; -*-

;; load init data
(add-to-list 'load-path (expand-file-name "source/init-data" user-emacs-directory))
(require 'init-data)

;; bootstrap
(add-to-list 'load-path (expand-file-name "source/bootstrap" user-emacs-directory))
(require 'bootstrap)

;; install mandatory config files
(-each zetta-files-that-need-creating 'zetta-touch-maybe)

;; load user module config (~/.zetta.el) if it exists
;; this can call `zetta-modules!' to override the default user-files
(let ((zetta-config (expand-file-name "~/.zetta.el")))
  (when (file-exists-p zetta-config)
    (load-file zetta-config)))

;; 1Password integration — needed by ~/.private.el before modules load.
;; Uses `op inject` to resolve all secrets in a single CLI call (one
;; Touch ID prompt).  The template lives in source/op-secrets.env.tpl.
(defvar zetta-op--cache (make-hash-table :test 'equal)
  "Cache for 1Password secrets, populated by `zetta-op-load'.")

(defun zetta-op-read (key)
  "Read a secret from the 1Password cache by env-style KEY.
KEY is the environment variable name from op-secrets.env.tpl,
e.g. \"OPENAI_API_KEY\"."
  (or (gethash key zetta-op--cache)
      (warn "zetta-op-read: %s not found in cache" key)))

(defun zetta-op-load ()
  "Load all secrets from 1Password via `op inject' (single Touch ID prompt).
Parses source/op-secrets.env.tpl and caches resolved KEY=VALUE pairs."
  (let* ((tpl (expand-file-name "source/op-secrets.env.tpl" user-emacs-directory))
         (output (string-trim
                  (shell-command-to-string
                   (format "op inject -i '%s' 2>/dev/null" tpl)))))
    (if (string-empty-p output)
        (warn "zetta-op-load: `op inject' failed — is 1Password unlocked?")
      (dolist (line (split-string output "\n" t))
        (when (string-match "\\`\\([^=]+\\)=\\(.*\\)\\'" line)
          (puthash (match-string 1 line) (match-string 2 line) zetta-op--cache))))))

;; ──────────────────────────────────────────────────────────────────
;; auth-source backend backed by 1Password cache
;; Replaces ~/.authinfo — consumers like forge, erc, slack, gptel
;; call `auth-source-search' and this backend serves from cache.
;; ──────────────────────────────────────────────────────────────────

(require 'auth-source)
(require 'cl-lib)

(defvar zetta-op-auth-source-entries nil
  "Mapping from auth-source queries to 1Password cache keys.
Set this in ~/.private.el with entries of the form:
  (:host HOST :user USER [:port PORT] :key OP-KEY)
See .private.sample.el for an example.")

(cl-defun zetta-op-auth-source-search (&rest spec
                                       &key backend type host user port
                                       require max
                                       &allow-other-keys)
  "Search the 1Password cache for auth-source credentials."
  (let (results)
    (dolist (entry zetta-op-auth-source-entries)
      (let ((e-host (plist-get entry :host))
            (e-user (plist-get entry :user))
            (e-port (plist-get entry :port))
            (e-key  (plist-get entry :key)))
        ;; t in a spec slot is auth-source's wildcard ("present, any
        ;; value") — emacs-bluesky searches with :user t.
        (when (and (or (null host) (eq host t) (equal host e-host))
                   (or (null user) (eq user t) (equal user e-user))
                   (or (null port) (eq port t) (equal port e-port)))
          (let ((secret-key e-key))
            (push (list :host e-host
                        :user e-user
                        :port (or e-port "443")
                        :secret (lambda () (gethash secret-key zetta-op--cache)))
                  results)))))
    (setq results (nreverse results))
    (when (and max (> (length results) max))
      (setq results (cl-subseq results 0 max)))
    results))

(defun zetta-op-auth-source-parser (entry)
  "Parse auth-source backend ENTRY.
Returns a backend object when ENTRY is the symbol `zetta-op'."
  (when (eq entry 'zetta-op)
    (auth-source-backend
     :type 'zetta-op
     :source "1Password"
     :search-function #'zetta-op-auth-source-search)))

;; Register the backend parser
(if (boundp 'auth-source-backend-parser-functions)
    (add-hook 'auth-source-backend-parser-functions #'zetta-op-auth-source-parser)
  (advice-add 'auth-source-backend-parse :before-until #'zetta-op-auth-source-parser))

;; Put 1Password first in auth-sources
(setq auth-sources '(zetta-op))

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
 '(bmkp-last-as-first-bookmark-file "~/.zetta.d/bookmarks")
 '(connection-local-criteria-alist
   '(((:application tramp :machine "localhost")
      tramp-connection-local-darwin-ps-profile)
     ((:application tramp :machine "WQN4T69J6P")
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
   '("4c7228157ba3a48c288ad8ef83c490b94cb29ef01236205e360c2c4db200bb18"
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
;;; init.el ends here
