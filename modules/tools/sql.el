;;; sql.el --- Generic SQL workflow over built-in sql.el -*- lexical-binding: t; -*-

;; Machinery only -- no endpoints live here. Projects register their own
;; connections into `sql-connection-alist' (and `lsp-sqls-connections')
;; and everything below lights up; see sql-practice's elisp/sql-practice.el
;; for the pattern.
;;
;; Provides:
;;  1. keg-only psql/mysql clients on Emacs's PATH (also fixes ob-sql's
;;     hardcoded `mysql` for org-babel blocks)
;;  2. a DuckDB product for sql.el, via the official sql-add-product API
;;  3. `zetta-sql-send-paragraph' remapped over C-c C-c in sql-mode:
;;     first use prompts for a connection, then it sticks; C-u C-c C-c
;;     re-prompts to switch. `sql-buffer' is buffer-local, so different
;;     buffers can target different servers simultaneously.
;;  4. schema-aware completion via the sqls language server + lsp-mode
;;     (go install github.com/sqls-server/sqls@latest). Switch the
;;     completion target with M-x lsp-sql-switch-connection.

(require 'sql)

;;;; Client discovery ---------------------------------------------------

;; Prefer whatever is on PATH; fall back to Homebrew keg-only locations
;; (libpq and mysql-client don't symlink into /opt/homebrew/bin).  On
;; machines with neither, the bare program name is left for PATH to
;; resolve at connect time.
(defun zetta-sql--find-program (name keg-dir)
  "Locate client NAME on PATH, else under KEG-DIR, else return NAME."
  (or (executable-find name)
      (let ((p (expand-file-name name keg-dir)))
        (and (file-executable-p p) p))
      name))

(setq sql-postgres-program
      (zetta-sql--find-program "psql" "/opt/homebrew/opt/libpq/bin"))
(setq sql-mysql-program
      (zetta-sql--find-program "mysql" "/opt/homebrew/opt/mysql-client/bin"))

;; ob-sql shells out to a bare `mysql`, so also expose the keg dirs on
;; Emacs's PATH where they exist.  No-op elsewhere.
(dolist (dir '("/opt/homebrew/opt/libpq/bin" "/opt/homebrew/opt/mysql-client/bin"))
  (when (file-directory-p dir)
    (add-to-list 'exec-path dir)
    (let ((path (getenv "PATH")))
      (unless (member dir (split-string path ":"))
        (setenv "PATH" (concat dir ":" path))))))

;;;; DuckDB product (sql.el ships postgres/mysql/sqlite but not duckdb) --

(defcustom sql-duckdb-program "duckdb"
  "Command to start the DuckDB command interpreter."
  :type 'file
  :group 'SQL)

(defcustom sql-duckdb-options nil
  "List of additional options for `sql-duckdb-program'."
  :type '(repeat string)
  :group 'SQL)

(defcustom sql-duckdb-login-params '((database :file ".*\\.duckdb"))
  "Login parameters needed to connect to DuckDB."
  :type 'sql-login-params
  :group 'SQL)

(defun sql-comint-duckdb (product options &optional buf-name)
  "Create a comint buffer and connect to DuckDB."
  (let ((params (append options
                        (unless (string-empty-p sql-database)
                          (list (expand-file-name sql-database))))))
    (sql-comint product params buf-name)))

(unless (assoc 'duckdb sql-product-alist)
  (sql-add-product
   'duckdb "DuckDB"
   :free-software t
   :font-lock 'sql-mode-postgres-font-lock-keywords
   :sqli-program 'sql-duckdb-program
   :sqli-options 'sql-duckdb-options
   :sqli-login 'sql-duckdb-login-params
   :sqli-comint-func #'sql-comint-duckdb
   :list-all ".tables"
   :list-table ".schema %s"
   :prompt-regexp "^D "
   :prompt-length 2
   :prompt-cont-regexp "^[·>] "))

;;;; Send-with-server-selection ----------------------------------------

(defun zetta-sql-attach (&optional connection)
  "Attach this buffer's SQL sends to CONNECTION, prompting if nil.
Starts (or reuses) the connection's SQLi buffer via `sql-connect',
shows it in another window without stealing focus, and points the
buffer-local `sql-buffer' at it."
  (interactive)
  (let ((connection (or connection
                        (sql-read-connection "Send SQL to connection: "))))
    (save-window-excursion (sql-connect connection))
    (let ((sqli (sql-find-sqli-buffer (default-value 'sql-product)
                                      (default-value 'sql-connection))))
      (unless sqli
        (user-error "Could not start SQLi buffer for %s" connection))
      (setq-local sql-buffer sqli)
      (run-hooks 'sql-set-sqli-hook)
      (display-buffer sqli '(nil (inhibit-same-window . t)))
      (message "SQL now goes to %s" sqli))))

(defun zetta-sql-send-paragraph (&optional arg)
  "Send the SQL statement (paragraph) at point to this buffer's server.
First use prompts for a connection from `sql-connection-alist' and
remembers it.  With prefix ARG (\\[universal-argument]), re-prompt to
switch servers, then send."
  (interactive "P")
  (when (or arg (not (sql-buffer-live-p sql-buffer)))
    (zetta-sql-attach))
  (sql-send-paragraph))

;; Route every binding of `sql-send-paragraph' (C-c C-c, menu) through
;; the prompting version.
(keymap-set sql-mode-map "<remap> <sql-send-paragraph>"
            #'zetta-sql-send-paragraph)

;;;; sqls language server (table/column completion) ---------------------

(defvar zetta-sql-sqls-program
  (or (executable-find "sqls")
      (expand-file-name "~/go/bin/sqls"))   ; go install's default GOBIN
  "Path to the sqls language server binary.")

(defvar lsp-sqls-server)                ; defined in lsp-sqls
(defvar lsp-default-create-error-handler-fn)
(declare-function lsp-get "ext:lsp-mode")
(declare-function lsp-log "ext:lsp-mode")
(declare-function lsp--warn "ext:lsp-mode")
(declare-function lsp--error-string "ext:lsp-mode")

(with-eval-after-load 'lsp-mode
  (require 'lsp-sqls)
  (setq lsp-sqls-server zetta-sql-sqls-program)
  ;; sqls answers hover/completion/etc. on statements its (incomplete)
  ;; parser can't handle with hard errors, which the default async
  ;; error handler echoes as "LSP :: Error from the Language Server:
  ;; failed parse ..." on every cursor idle.  This is lsp-mode's
  ;; official hook for constructing those handlers: route the known
  ;; sqls parser noise to *lsp-log*, keep stock behavior otherwise.
  (setq lsp-default-create-error-handler-fn
        (lambda (method)
          (lambda (err)
            (let ((msg (lsp-get err :message)))
              (if (and msg (string-match-p "\\`failed parse" msg))
                  (lsp-log "sqls parser (suppressed, %s): %s" method msg)
                (lsp--warn "%s" (or (lsp--error-string err)
                                    (format "%s Request has failed" method)))))))))

;; Postgres Language Server (supabase-community; lsp client `postgres-ls')
;; parses with Postgres's own parser (libpg_query), so it handles the SQL
;; that sqls's homegrown parser chokes on.  It is project-scoped: it
;; serves the schema of the database named in the project root's
;; postgres-language-server.jsonc (generate with `postgres-language-server
;; init`; install the server itself with M-x lsp-install-server).
;;
;; Both clients register for sql-mode at equal priority, so arbitrate
;; with `lsp-disabled-clients': sqls is the deterministic global default
;; (multi-engine, zero config), and a Postgres project opts into
;; postgres-ls via a dir-local that SHADOWS the global list:
;;   ((sql-mode . ((lsp-disabled-clients . (sqls)))))
(defvar lsp-disabled-clients)
(with-eval-after-load 'lsp-mode
  (add-to-list 'lsp-disabled-clients 'postgres-ls))

;; A list of client symbols to disable is benign; silence the
;; risky-local-variable prompt for the dir-locals opt-in above.
(put 'lsp-disabled-clients 'safe-local-variable #'listp)

(defun zetta-sql-lsp-maybe ()
  "Start lsp in this sql buffer when lsp-mode and sqls are available."
  (when (and (fboundp 'lsp-deferred)
             (file-executable-p zetta-sql-sqls-program))
    (lsp-deferred)))

(add-hook 'sql-mode-hook #'zetta-sql-lsp-maybe)

;; sqls's homegrown SQL parser is incomplete -- e.g. it cannot parse
;; count(*) inside a subquery's select list -- and it answers completion
;; requests touching such statements with a hard JSON-RPC error, which
;; corfu then surfaces as a full backtrace on every keystroke.  In
;; sql-mode, degrade those failures to "no candidates" instead.  (The
;; request happens lazily inside the returned completion table, not in
;; the capf call itself, so the table is what needs the guard.)
(define-advice lsp-completion-at-point
    (:filter-return (result) zetta-sql-quiet-parser-errors)
  (if (and result (derived-mode-p 'sql-mode))
      (let ((table (nth 2 result)))
        (setf (nth 2 result)
              (lambda (str pred action)
                (condition-case nil
                    (if (functionp table)
                        (funcall table str pred action)
                      (complete-with-action action table str pred))
                  (error nil))))
        ;; :exclusive no — when sqls's parser fails and the guarded
        ;; table yields nothing, let completion fall through to the
        ;; remaining capfs (e.g. dabbrev over buffer words) instead of
        ;; claiming the region and showing nothing.
        (append result '(:exclusive no)))
    result))

;;;; Formatting (sqlformat, from the sqlparse package) --------------------

(defvar zetta-sql-format-args
  '("--reindent" "--keywords" "upper" "--identifiers" "lower")
  "Arguments passed to sqlformat (both DWIM command and apheleia).")

(defun zetta-sql-format-dwim ()
  "Format the active region, else the SQL statement (paragraph) at point.
Filters the text through sqlformat; leaves the buffer untouched if the
formatter fails."
  (interactive)
  (unless (executable-find "sqlformat")
    (user-error "sqlformat not found -- brew install sqlparse"))
  (let* ((beg (if (use-region-p) (region-beginning)
                (save-excursion (backward-paragraph)
                                (skip-chars-forward "\n")
                                (point))))
         (end (if (use-region-p) (region-end)
                (save-excursion (forward-paragraph) (point))))
         (out (generate-new-buffer " *sqlformat*")))
    (unwind-protect
        (let ((status (apply #'call-process-region beg end "sqlformat"
                             nil out nil
                             (append zetta-sql-format-args '("-")))))
          (unless (and (integerp status) (zerop status))
            (user-error "sqlformat failed: %s"
                        (with-current-buffer out
                          (string-trim (buffer-string)))))
          (let ((formatted (with-current-buffer out (buffer-string))))
            (delete-region beg end)
            (goto-char beg)
            (insert formatted)))
      (kill-buffer out))))

;; On-demand whole-buffer formatting via M-x apheleia-format-buffer
;; (apheleia-global-mode is off in this config, so nothing formats on
;; save unless apheleia-mode is enabled buffer-locally on purpose --
;; do NOT do that in lesson files, it would reflow the teaching SQL).
(defvar apheleia-formatters)            ; defined in apheleia
(defvar apheleia-mode-alist)

(with-eval-after-load 'apheleia
  (setf (alist-get 'sqlformat apheleia-formatters)
        (append '("sqlformat") zetta-sql-format-args '("-")))
  (setf (alist-get 'sql-mode apheleia-mode-alist) 'sqlformat))

(keymap-set sql-mode-map "C-c C-f" #'zetta-sql-format-dwim)

;;;; Endpoint registration ----------------------------------------------

;; Machine-local endpoint files (project labs, work DBs) are private
;; data, not public config: list them in ~/.private.el, e.g.
;;   (setq zetta-sql-endpoint-files
;;         '("~/source_code/sql-practice/elisp/sql-practice.el"))
;; Each file should MERGE its entries into `sql-connection-alist' /
;; `lsp-sqls-connections' rather than setq them.  Missing files are
;; skipped silently, so the list is safe to share across machines.
(defvar zetta-sql-endpoint-files nil
  "Elisp files registering SQL endpoints, loaded at module init if present.")

(dolist (file zetta-sql-endpoint-files)
  (let ((f (expand-file-name file)))
    (when (file-exists-p f)
      (load f t t))))
