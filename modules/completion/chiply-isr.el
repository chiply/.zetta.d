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

(require 'consult)
(require 'json)
(require 'url)

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

;;;###autoload
(defun chiply-isr-index-corpus ()
  "Index every .org file in `chiply-isr-corpus-dir' into the running server.
Content-only: semantic search embeds the file body, so no org parsing is
needed.  Run once (the database persists), or after editing the samples."
  (interactive)
  (unless (chiply-isr-server-running-p)
    (user-error "chiply-isr: server not running -- M-x chiply-isr-start-server"))
  (let ((files (directory-files chiply-isr-corpus-dir t "\\.org\\'"))
        (n 0))
    (dolist (f files)
      (let* ((content (with-temp-buffer (insert-file-contents f) (buffer-string)))
             (url-request-method "POST")
             (url-request-extra-headers '(("Content-Type" . "application/json")))
             (url-request-data
              (encode-coding-string
               (json-encode `((filename . ,f)
                              (md5 . ,(md5 content))
                              (file_size . ,(string-bytes content))
                              (content . ,content)
                              ;; empty parsed-structure arrays -- the server
                              ;; embeds `content' directly for semantic search
                              (headlines . ,[]) (links . ,[]) (keywords . ,[])
                              (src_blocks . ,[]) (images . ,[]) (linked_files . ,[])))
               'utf-8))
             (buf (url-retrieve-synchronously
                   (concat (chiply-isr-server-url) "/api/file") t nil 120)))
        (when buf (kill-buffer buf) (setq n (1+ n)))))
    (message "chiply-isr: indexed %d file(s) from %s" n chiply-isr-corpus-dir)))

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
