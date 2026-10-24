;;; bootstrap-secrets.el --- The secrets cache and its auth-source backend -*- lexical-binding: t; -*-

;; Loaded by init.el AFTER ~/.zetta.el and BEFORE ~/.private.el.  One
;; cache, filled once by `zetta-secrets-load' from whichever backend
;; `zetta-secrets-effective-backend' names (`zetta-secrets-backend' in
;; ~/.zetta.el, or the nil rule; both in bootstrap-modules.el), read by
;; `zetta-secrets-read', and served to forge, gptel, slack, erc, mastodon
;; and bluesky through the `zetta-op' auth-source backend below.
;;
;; The `zetta-op-*' names remain as aliases: a private file that calls
;; (zetta-op-load) and (zetta-op-read "KEY") keeps working unchanged
;; (work-profile.org Part 4, requirement R-S4).  Design and the table of
;; vaults: secrets.md.

(require 'auth-source)
(require 'cl-lib)
(require 'bootstrap-modules)

(defvar zetta-op--cache (make-hash-table :test 'equal)
  "Cache of resolved secrets, KEY -> VALUE, filled by `zetta-secrets-load'.")

(defun zetta-secrets--parse (output label)
  "Cache every KEY=VALUE line of OUTPUT, a vault command's stdout.
LABEL names the command in the warning when it printed nothing."
  (let ((output (string-trim output)))
    (if (string-empty-p output)
        (warn "zetta-secrets-load: %s returned nothing -- is the vault unlocked?"
              label)
      ;; Only KEY=VALUE lines with an env-style KEY: a comment or a
      ;; diagnostic line that happens to contain `=' is not a secret.
      (dolist (line (split-string output "\n" t))
        (when (string-match "\\`\\([A-Za-z_][A-Za-z0-9_]*\\)=\\(.*\\)\\'" line)
          (puthash (match-string 1 line) (match-string 2 line)
                   zetta-op--cache))))))

;; The vault command runs in the BACKGROUND.  `op inject' took 1.05-1.21 s
;; of the init critical path with the vault already unlocked, and a Touch
;; ID prompt on top of that when it was not (OPTIMIZATIONS.org, "op inject
;; blocks startup").  `zetta-secrets-load' now only starts the process;
;; its sentinel fills the cache, and the first read that arrives before it
;; has finished waits for it -- so a consumer that is itself deferred
;; (spot, wombag behind `with-eval-after-load' in ~/.private.el) costs
;; nothing at init, and one that is not pays what it always paid.
(defvar zetta-secrets--process nil
  "The vault command in flight, or nil.")
(defvar zetta-secrets--state 'empty
  "`empty' (never started), `running', or `filled' (finished, or no cache).")
(defcustom zetta-secrets-wait-timeout 180
  "Seconds `zetta-secrets-read' waits for a vault command before giving up.
Long on purpose: a locked vault is waiting on Touch ID."
  :type 'number :group 'zetta)

(defun zetta-secrets--start (command label)
  "Run shell COMMAND in the background and cache the KEY=VALUE lines it prints.
LABEL names the command in warnings.  stderr is discarded: a vault's
error text must never become a value."
  (setq zetta-secrets--state 'running
        zetta-secrets--process
        (make-process
         :name "zetta-secrets"
         :buffer (generate-new-buffer " *zetta-secrets*" t)
         :command (list shell-file-name shell-command-switch
                        (concat command " 2>/dev/null"))
         :connection-type 'pipe
         :noquery t
         :sentinel
         (lambda (proc _event)
           (unless (process-live-p proc)
             (let ((buf (process-buffer proc)))
               (unwind-protect
                   (zetta-secrets--parse
                    (if (buffer-live-p buf)
                        (with-current-buffer buf (buffer-string))
                      "")
                    label)
                 (when (buffer-live-p buf) (kill-buffer buf))
                 (setq zetta-secrets--state 'filled
                       zetta-secrets--process nil))))))))

(defun zetta-secrets--wait ()
  "Block until the vault command in flight has filled the cache."
  (when (eq zetta-secrets--state 'running)
    (let ((deadline (+ (float-time) zetta-secrets-wait-timeout)))
      (while (and (eq zetta-secrets--state 'running)
                  (< (float-time) deadline))
        (accept-process-output zetta-secrets--process 0.2))
      (when (eq zetta-secrets--state 'running)
        (warn "zetta-secrets: the vault command did not finish in %s s"
              zetta-secrets-wait-timeout)
        (setq zetta-secrets--state 'filled)))))

(defun zetta-secrets--ensure ()
  "Make sure the cache has been filled: start the vault command if it never
ran, then wait for it if it is still running."
  (when (eq zetta-secrets--state 'empty)
    (zetta-secrets-load))
  (zetta-secrets--wait))

(defun zetta-secrets-load ()
  "Start filling the secrets cache from the effective backend.
`op': one `op inject' over `zetta-op-template-file' (a single Touch ID
prompt, or none with a service-account token).  `command': run
`zetta-secrets-command'.  Both run in the background and parse KEY=VALUE
lines into the same cache; `zetta-secrets-read' waits for them.
`authinfo' and `none' have no cache to fill and spawn nothing."
  (unless (eq zetta-secrets--state 'running)
    (pcase (zetta-secrets-effective-backend)
      ('op
       (zetta-secrets--start
        (format "op inject -i %s"
                (shell-quote-argument (expand-file-name zetta-op-template-file)))
        "`op inject'"))
      ('command
       (if zetta-secrets-command
           (zetta-secrets--start zetta-secrets-command "`zetta-secrets-command'")
         (setq zetta-secrets--state 'filled)
         (warn "zetta-secrets-load: backend `command' but `zetta-secrets-command' is nil")))
      ((or 'authinfo 'none) (setq zetta-secrets--state 'filled))
      (other
       (setq zetta-secrets--state 'filled)
       (warn "zetta-secrets-load: unknown `zetta-secrets-backend' %S" other)))))

(defun zetta-secrets-read (key)
  "The secret cached under KEY, a KEY=VALUE name such as \"OPENAI_API_KEY\".
Starts the vault command if it never ran and waits for it if it is still
running.  Nil, with a warning, when the cache has no such key -- always
the case under the `authinfo' and `none' backends, whose consumers read
auth-source directly."
  (zetta-secrets--ensure)
  (or (gethash key zetta-op--cache)
      (progn
        (warn "zetta-secrets-read: %s is not in the secrets cache (backend %s)"
              key (zetta-secrets-effective-backend))
        nil)))

(defalias 'zetta-op-load #'zetta-secrets-load
  "Alias kept for private files written against the 1Password-only design.")
(defalias 'zetta-op-read #'zetta-secrets-read
  "Alias kept for private files written against the 1Password-only design.")

;; ──────────────────────────────────────────────────────────────────
;; auth-source backend backed by the cache
;; Consumers like forge, erc, slack and gptel call `auth-source-search'
;; and this backend serves from the cache -- the bridge that lets any
;; vault the `op' or `command' backend can read stand in for ~/.authinfo.
;; ──────────────────────────────────────────────────────────────────

(defvar zetta-op-auth-source-entries nil
  "Mapping from auth-source queries to cache keys.
Set this in ~/.private.el with entries of the form:
  (:host HOST :user USER [:port PORT] :key CACHE-KEY)
See .private.sample.el for an example.")

(cl-defun zetta-op-auth-source-search (&rest spec
                                       &key backend type host user port
                                       require max
                                       &allow-other-keys)
  "Search the secrets cache for auth-source credentials."
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
                        :secret (lambda ()
                                  (zetta-secrets--ensure)
                                  (gethash secret-key zetta-op--cache)))
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
     :source "zetta secrets cache"
     :search-function #'zetta-op-auth-source-search)))

;; Register the backend parser
(if (boundp 'auth-source-backend-parser-functions)
    (add-hook 'auth-source-backend-parser-functions #'zetta-op-auth-source-parser)
  (advice-add 'auth-source-backend-parse :before-until #'zetta-op-auth-source-parser))

;; `auth-sources' per backend, decided now that ~/.zetta.el has loaded:
;;   op, command -> the cache-backed backend, and only it;
;;   authinfo    -> left alone: Emacs's default files (~/.authinfo.gpg,
;;                  ~/.authinfo, ~/.netrc), or whatever ~/.zetta.el set;
;;   none        -> nil, so no backend is ever consulted (CI, the hub).
(pcase (zetta-secrets-effective-backend)
  ((or 'op 'command) (setq auth-sources '(zetta-op)))
  ('none (setq auth-sources nil)))

(provide 'bootstrap-secrets)
;;; bootstrap-secrets.el ends here
