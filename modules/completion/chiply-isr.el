;;; chiply-isr.el --- Incremental Suggesting Read via semantic search -*- lexical-binding: t; -*-

;;; Commentary:
;; A worked example of *Incremental Suggesting Read* (ISR): completing-read
;; whose candidate COLLECTION is a function that asks an embedding index by
;; MEANING instead of matching characters.  Everything downstream -- consult
;; preview, Marginalia, Embark, muscle memory -- is the ordinary ICR
;; substrate, reused verbatim.
;;
;; The embeddings + vector search come from John Kitchin's org-db-v3
;; (https://github.com/jkitchin/org-db-v3, MIT), vendored under
;; `~/.zetta.d/chiply-isr/server/'.  Emacs only talks to its HTTP API; this
;; file is the ~40 lines of glue that wire that backend into consult.
;;
;; Companion blog post:
;; https://chiply.dev/post-incremental-suggesting-read
;;
;; Usage:
;;   M-x chiply-isr-start-server   ; launch the FastAPI backend (once)
;;   M-x chiply-isr-semantic-read  ; type a MEANING; candidates rank by similarity

;;; Code:

(require 'json)
(require 'url)

;; consult is required lazily in `chiply-isr-semantic-read' (the only command
;; that needs it), not at load time -- so byte-compiling this module never
;; depends on consult being built yet (matters on a cold CI cache).
(declare-function consult--read "consult")
(declare-function consult--dynamic-collection "consult")
(declare-function consult--lookup-cdr "consult")
(declare-function consult--jump-preview "consult")
(declare-function general-define-key "general")

(defgroup chiply-isr nil
  "Incremental Suggesting Read over a semantic index."
  :group 'completion
  :prefix "chiply-isr-")

(defcustom chiply-isr-dir
  (expand-file-name "chiply-isr/" user-emacs-directory)
  "Directory holding the vendored org-db-v3 server and demo database."
  :type 'directory)

(defcustom chiply-isr-corpus-dir
  (expand-file-name "corpus/" (expand-file-name "chiply-isr/" user-emacs-directory))
  "Directory of sample .org files indexed for the demo.
These are deliberately written so meaning-based queries surface the right
file while sharing no words with it -- see the files for examples."
  :type 'directory)

(defcustom chiply-isr-server-host "127.0.0.1"
  "Host the org-db-v3 server listens on."
  :type 'string)

(defcustom chiply-isr-server-port 8765
  "Port the org-db-v3 server listens on."
  :type 'integer)

(defcustom chiply-isr-corpus-pattern "%chiply-isr/corpus%"
  "SQL LIKE pattern scoping search to the indexed corpus.
A belt-and-suspenders guard so results stay in the intended corpus."
  :type 'string)

(defcustom chiply-isr-index-sources
  (list (cons (expand-file-name "corpus/" (expand-file-name "chiply-isr/" user-emacs-directory))
              "\\.org\\'"))
  "List of (DIRECTORY . FILE-REGEXP) pairs to index.
Each DIRECTORY is searched recursively for files whose name matches
FILE-REGEXP, and every match is sent to the semantic index.  Add your
own notes, code, etc. here, e.g.:

  \\='((\"~/org/\"  . \"\\\\.org\\\\\\='\")
    (\"~/src/\"  . \"\\\\.py\\\\\\='\"))"
  :type '(repeat (cons (directory :tag "Directory")
                       (regexp :tag "File regexp"))))

(defcustom chiply-isr-index-on-startup nil
  "When non-nil, index `chiply-isr-index-sources' after Emacs starts.
Starts the server if needed, waits for it, then indexes only files whose
content changed since the last run (unchanged ones are skipped via an md5
cache).  Set this in ~/.zetta.el before this module loads."
  :type 'boolean)

(defvar chiply-isr--md5-cache-file
  (expand-file-name "index-md5.eld"
                    (expand-file-name "db/" (expand-file-name "chiply-isr/" user-emacs-directory)))
  "File caching FILENAME -> content-md5 so unchanged files are not re-embedded.")

(defun chiply-isr-server-url ()
  "Base URL of the running org-db-v3 server."
  (format "http://%s:%d" chiply-isr-server-host chiply-isr-server-port))

;;; Server lifecycle ---------------------------------------------------------

(defvar chiply-isr--server-process nil
  "Process object for the locally-launched org-db-v3 server, if any.")

(defun chiply-isr-server-running-p ()
  "Return non-nil if the server answers a health check."
  (condition-case nil
      (let ((buf (url-retrieve-synchronously
                  (concat (chiply-isr-server-url) "/health") t nil 2)))
        (when buf (kill-buffer buf) t))
    (error nil)))

;;;###autoload
(defun chiply-isr-start-server ()
  "Start the vendored org-db-v3 FastAPI server with the demo database.
Sets ORG_DB_*_DB_PATH so the server uses `chiply-isr-dir'/db, isolated
from any other org-db install."
  (interactive)
  (cond
   ((chiply-isr-server-running-p)
    (message "chiply-isr: server already running on %s" (chiply-isr-server-url)))
   ((process-live-p chiply-isr--server-process)
    (message "chiply-isr: server process already starting..."))
   (t
    (let* ((default-directory (expand-file-name "server/" chiply-isr-dir))
           (db (expand-file-name "db/" chiply-isr-dir))
           (process-environment
            (append (list (format "ORG_DB_DB_PATH=%sorg-db-v3.db" db)
                          (format "ORG_DB_SEMANTIC_DB_PATH=%sorg-db-v3-semantic.db" db)
                          (format "ORG_DB_IMAGE_DB_PATH=%sorg-db-v3-images.db" db)
                          (format "ORG_DB_HOST=%s" chiply-isr-server-host)
                          (format "ORG_DB_PORT=%d" chiply-isr-server-port))
                    process-environment)))
      (setq chiply-isr--server-process
            (make-process
             :name "chiply-isr-server"
             :buffer "*chiply-isr-server*"
             :command (list "uv" "run" "uvicorn" "org_db_server.main:app"
                            "--host" chiply-isr-server-host
                            "--port" (number-to-string chiply-isr-server-port))))
      (message "chiply-isr: starting server (see *chiply-isr-server*)...")))))

;;;###autoload
(defun chiply-isr-stop-server ()
  "Stop the locally-launched org-db-v3 server."
  (interactive)
  (when (process-live-p chiply-isr--server-process)
    (kill-process chiply-isr--server-process))
  (setq chiply-isr--server-process nil)
  (message "chiply-isr: server stopped"))

;;; Indexing ------------------------------------------------------------------

(defun chiply-isr--gather-files (sources)
  "Return all files matched by SOURCES, a list of (DIR . REGEXP) pairs.
Each existing DIR is searched recursively for names matching REGEXP."
  (apply #'append
         (mapcar (lambda (pair)
                   (let ((dir (expand-file-name (car pair))))
                     (when (file-directory-p dir)
                       (directory-files-recursively dir (cdr pair)))))
                 sources)))

(defun chiply-isr--post-file (filename content)
  "Send FILENAME with CONTENT to /api/file.  Return non-nil on success.
Content-only: the server embeds CONTENT directly for semantic search, so
no org parsing happens here."
  (let* ((url-request-method "POST")
         (url-request-extra-headers '(("Content-Type" . "application/json")))
         (url-request-data
          (encode-coding-string
           (json-encode `((filename . ,filename)
                          (md5 . ,(md5 content))
                          (file_size . ,(string-bytes content))
                          (content . ,content)
                          (headlines . ,[]) (links . ,[]) (keywords . ,[])
                          (src_blocks . ,[]) (images . ,[]) (linked_files . ,[])))
           'utf-8))
         (buf (url-retrieve-synchronously
               (concat (chiply-isr-server-url) "/api/file") t nil 120)))
    (when buf (kill-buffer buf) t)))

(defun chiply-isr--load-md5-cache ()
  "Return the saved FILENAME -> md5 alist, or nil."
  (when (file-exists-p chiply-isr--md5-cache-file)
    (with-temp-buffer
      (insert-file-contents chiply-isr--md5-cache-file)
      (ignore-errors (read (current-buffer))))))

(defun chiply-isr--save-md5-cache (alist)
  "Persist ALIST (FILENAME -> md5) to `chiply-isr--md5-cache-file'."
  (make-directory (file-name-directory chiply-isr--md5-cache-file) t)
  (with-temp-file chiply-isr--md5-cache-file
    (let ((print-length nil) (print-level nil))
      (prin1 alist (current-buffer)))))

;;;###autoload
(defun chiply-isr-index (&optional sources force)
  "Index every file matched by SOURCES into the running server.
SOURCES is a list of (DIRECTORY . FILE-REGEXP) pairs; it defaults to
`chiply-isr-index-sources'.  Files whose content is unchanged since the
last run are skipped (md5 cache); with prefix arg FORCE, re-index all.
The database persists on disk, so this only needs to run when files change."
  (interactive (list nil current-prefix-arg))
  (setq sources (or sources chiply-isr-index-sources))
  (unless (chiply-isr-server-running-p)
    (user-error "chiply-isr: server not running -- M-x chiply-isr-start-server"))
  (let ((files (chiply-isr--gather-files sources))
        (cache (unless force (chiply-isr--load-md5-cache)))
        (seen nil) (indexed 0) (skipped 0))
    (dolist (f files)
      (let* ((content (with-temp-buffer (insert-file-contents f) (buffer-string)))
             (sum (md5 content)))
        (cond
         ((and (not force) (equal (cdr (assoc f cache)) sum))
          (push (cons f sum) seen) (setq skipped (1+ skipped)))
         ((chiply-isr--post-file f content)
          (push (cons f sum) seen) (setq indexed (1+ indexed))))))
    ;; `seen' omits files that vanished from disk, so they age out of the cache.
    (chiply-isr--save-md5-cache seen)
    (message "chiply-isr: indexed %d, skipped %d unchanged, of %d file(s)"
             indexed skipped (length files))
    indexed))

;;;###autoload
(defun chiply-isr-index-corpus (&optional force)
  "Index `chiply-isr-corpus-dir' (the demo sample files).
Thin wrapper over `chiply-isr-index'; FORCE re-indexes unchanged files too."
  (interactive "P")
  (chiply-isr-index (list (cons chiply-isr-corpus-dir "\\.org\\'")) force))

;;; Startup indexing ---------------------------------------------------------

(defvar chiply-isr--startup-tries 0
  "Internal counter for `chiply-isr--startup-attempt' retries.")

(defun chiply-isr--startup-attempt ()
  "Index sources once the server answers; retry briefly while it boots."
  (cond
   ((chiply-isr-server-running-p)
    (setq chiply-isr--startup-tries 0)
    (ignore-errors (chiply-isr-index)))
   ((< (setq chiply-isr--startup-tries (1+ chiply-isr--startup-tries)) 30)
    (run-with-timer 1 nil #'chiply-isr--startup-attempt))
   (t (setq chiply-isr--startup-tries 0)
      (message "chiply-isr: server did not come up; skipped startup index"))))

(defun chiply-isr-maybe-startup-index ()
  "If `chiply-isr-index-on-startup', start the server and index sources.
Added to `emacs-startup-hook'; a no-op unless the option is enabled."
  (when chiply-isr-index-on-startup
    (chiply-isr-start-server)            ; no-op if already running
    (chiply-isr--startup-attempt)))

(add-hook 'emacs-startup-hook #'chiply-isr-maybe-startup-index)

;;; Semantic source ----------------------------------------------------------

(defun chiply-isr--search (input)
  "POST INPUT to the semantic-search endpoint, return the results vector."
  (let* ((url-request-method "POST")
         (url-request-extra-headers '(("Content-Type" . "application/json")))
         (url-request-data
          (encode-coding-string
           (json-encode `((query . ,input)
                          (limit . 12)
                          (filename_pattern . ,chiply-isr-corpus-pattern)))
           'utf-8))
         (buf (url-retrieve-synchronously
               (concat (chiply-isr-server-url) "/api/search/semantic") t nil 5)))
    (when buf
      (unwind-protect
          (with-current-buffer buf
            (goto-char (point-min))
            (when (re-search-forward "^$" nil t)
              (alist-get 'results (json-read))))
        (kill-buffer buf)))))

;; The candidate COLLECTION is just a function.  Emacs hands it your input
;; and asks for matches; the contract never says where they come from.
;; Here it asks an embedding index by meaning, not by characters.
(defun chiply-isr--collection (input)
  "Consult dynamic-collection callback: meaning INPUT -> (DISPLAY . PLIST)."
  (mapcar
   (lambda (r)
     (let* ((file  (alist-get 'filename r))
            (line  (alist-get 'begin_line r))
            (score (alist-get 'similarity_score r))
            (text  (replace-regexp-in-string
                    "[\n\r]+" " " (or (alist-get 'chunk_text r) ""))))
       (cons (format "%-6.3f  %-22s  %s"
                     (or score 0.0)
                     (file-name-nondirectory file)
                     (truncate-string-to-width text 64 nil nil "..."))
             (list :file file :line line))))
   (append (chiply-isr--search input) nil)))

(defun chiply-isr--state ()
  "Consult preview state: jump to the matched line as candidates change."
  (let ((preview (consult--jump-preview)))
    (lambda (action cand)
      (when-let* ((cand)
                  (pl (cdr cand))
                  (file (plist-get pl :file)))
        (funcall preview action
                 (when (and (eq action 'preview) (file-exists-p file))
                   (with-current-buffer (find-file-noselect file)
                     (save-excursion
                       (goto-char (point-min))
                       (forward-line (1- (or (plist-get pl :line) 1)))
                       (point-marker)))))))))

;; consult drives that function as a live, per-keystroke source; preview,
;; Marginalia, and Embark are inherited unchanged.  This is still ICR.
;;;###autoload
(defun chiply-isr-semantic-read ()
  "Incremental Suggesting Read: type a MEANING, open the matched post.
Candidates are ranked by embedding similarity, not spelling."
  (interactive)
  (require 'consult)
  (unless (chiply-isr-server-running-p)
    (user-error "chiply-isr: server not running -- M-x chiply-isr-start-server"))
  (let ((sel (consult--read
              (consult--dynamic-collection #'chiply-isr--collection
                :min-input 3 :debounce 0.3)
              :prompt "Suggesting read (by meaning): "
              :lookup #'consult--lookup-cdr
              :category 'chiply-isr
              :sort nil
              :require-match t
              :state (chiply-isr--state))))
    (when (plist-get sel :file)
      (find-file (plist-get sel :file))
      (goto-char (point-min))
      (forward-line (1- (or (plist-get sel :line) 1)))
      (recenter))))

;;; Keybinding ---------------------------------------------------------------

(with-eval-after-load 'general
  (when (boundp 'menu-lookup-map)
    (general-define-key
     :keymaps 'menu-lookup-map
     "i" 'chiply-isr-semantic-read)))

(provide 'chiply-isr)
;;; chiply-isr.el ends here
