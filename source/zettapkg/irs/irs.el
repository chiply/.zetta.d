;;; irs.el --- Client for the information-retrieval-service backend -*- lexical-binding: t; -*-

;; Author: Charlie Holland
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (plz "0.9"))
;; Keywords: tools, matching

;;; Commentary:

;; Thin async HTTP client for the irs backend — the FastAPI service at
;; ~/source_code/information-retrieval-service (design doc:
;; text-search.org at the .zetta.d root).
;;
;; M2 scope: server lifecycle (probe -> adopt -> spawn), status, ingest,
;; and `irs-search' — FTS/BM25 with hierarchy-expanded results presented
;; through `consult--read' when consult is loaded (plain
;; `completing-read' otherwise).
;;
;; Every request is an async `plz' call; nothing here blocks the command
;; loop.  The as-you-type dynamic consult source (custom async stage per
;; the design doc) is deliberately deferred to a later milestone — this
;; command reads the query first, fetches once, then completes over the
;; returned candidates.

;;; Code:

(require 'json)
(require 'plz)
(require 'subr-x)

(declare-function consult--read "ext:consult")

(defgroup irs nil
  "Client for the information-retrieval-service backend."
  :group 'tools
  :prefix "irs-")

(defcustom irs-base-url "http://127.0.0.1:8878"
  "Base URL of the irs backend."
  :type 'string)

(defcustom irs-backend-directory "~/source_code/information-retrieval-service"
  "Checkout of the backend repo; `irs-ensure-server' runs `uv run irs serve' here."
  :type 'directory)

(defcustom irs-search-limit 20
  "Maximum results to request per search."
  :type 'natnum)

(defvar irs--server-process nil
  "Server process spawned by this Emacs, if any (an adopted server is not ours).")

;;;; HTTP plumbing (async only)

(defun irs--url (path)
  (concat irs-base-url path))

(defun irs--error (err)
  "Report a `plz-error' ERR in the echo area."
  (message "irs: %s"
           (or (plz-error-message err)
               (when-let* ((resp (plz-error-response err)))
                 (format "HTTP %s" (plz-response-status resp)))
               (format "%S" err))))

(defun irs--get (path then &optional else)
  (plz 'get (irs--url path)
    :as #'json-read
    :then then
    :else (or else #'irs--error)))

(defun irs--post (path payload then &optional else)
  (plz 'post (irs--url path)
    :headers '(("Content-Type" . "application/json"))
    :body (json-encode payload)
    :as #'json-read
    :then then
    :else (or else #'irs--error)))

;;;; Server lifecycle: probe -> verify identity -> adopt, else spawn

(defun irs-ensure-server (&optional callback)
  "Make sure an irs backend answers at `irs-base-url', then call CALLBACK.
Adopts an already-running server after verifying the /v1/status service
identity; only spawns a new one when nothing answers."
  (interactive)
  (irs--get "/v1/status"
            (lambda (data)
              (if (equal (alist-get 'service data) "irs")
                  (progn
                    (when (called-interactively-p 'interactive)
                      (message "irs: server up"))
                    (when callback (funcall callback)))
                (message "irs: %s is answering at %s — not adopting"
                         (or (alist-get 'service data) "something else")
                         irs-base-url)))
            (lambda (_err)
              (message "irs: starting backend…")
              (irs--spawn-server callback))))

(defun irs--spawn-server (callback)
  (unless (process-live-p irs--server-process)
    (let ((default-directory (expand-file-name irs-backend-directory)))
      (setq irs--server-process
            (make-process :name "irs-server"
                          :buffer " *irs-server*"
                          :command '("uv" "run" "irs" "serve")
                          :noquery t))))
  (irs--poll-health 20 callback))

(defun irs--poll-health (retries callback)
  (irs--get "/v1/status"
            (lambda (data)
              (if (equal (alist-get 'service data) "irs")
                  (progn (message "irs: server ready")
                         (when callback (funcall callback)))
                (message "irs: port answered but not irs — giving up")))
            (lambda (_err)
              (if (> retries 0)
                  (run-at-time 0.5 nil #'irs--poll-health (1- retries) callback)
                (message "irs: server did not come up; see buffer %s"
                         " *irs-server*")))))

;;;; Status and ingest

;;;###autoload
(defun irs-status ()
  "Show backend status in the echo area."
  (interactive)
  (irs--get "/v1/status"
            (lambda (data)
              (let* ((corpus (alist-get 'corpus data))
                     (kinds (alist-get 'nodes_by_kind corpus)))
                (message "irs %s — %s nodes (%s documents, %s chunks); embedder ready: %s"
                         (alist-get 'version data)
                         (alist-get 'nodes_total corpus)
                         (alist-get 'document kinds)
                         (alist-get 'chunk kinds)
                         (if (eq (alist-get 'ready (alist-get 'embedder data))
                                 :json-false)
                             "no" "yes"))))))

;;;###autoload
(defun irs-ingest ()
  "Trigger a corpus ingest job and report progress until it finishes."
  (interactive)
  (irs-ensure-server
   (lambda ()
     (irs--post "/v1/ingest" nil
                (lambda (data)
                  (let ((job-id (alist-get 'job_id data)))
                    (message "irs: ingest started (job %s)" job-id)
                    (irs--poll-job job-id)))))))

(defun irs--poll-job (job-id)
  (irs--get (format "/v1/jobs/%s" job-id)
            (lambda (job)
              (pcase (alist-get 'state job)
                ("running"
                 (run-at-time 2 nil #'irs--poll-job job-id))
                ("done"
                 (let ((r (alist-get 'result job)))
                   (if (equal (alist-get 'kind job) "embed")
                       (message "irs: embed done — %s embedded, %s failed (model %s)"
                                (alist-get 'embedded r)
                                (alist-get 'failed r)
                                (alist-get 'model r))
                     (message "irs: ingest done — %s ingested, %s unchanged, %s deleted, %s errors"
                              (alist-get 'files_ingested r)
                              (alist-get 'files_unchanged r)
                              (alist-get 'files_deleted r)
                              (length (alist-get 'errors r))))))
                (_
                 (message "irs: %s failed: %s"
                          (alist-get 'kind job) (alist-get 'error job)))))))

;;;###autoload
(defun irs-embed ()
  "Embed all non-fresh corpus text via the backend; reports when done."
  (interactive)
  (irs-ensure-server
   (lambda ()
     (irs--post "/v1/embed" nil
                (lambda (data)
                  (let ((job-id (alist-get 'job_id data)))
                    (message "irs: embed started (job %s)" job-id)
                    (irs--poll-job job-id)))))))

;;;; Search (FTS / BM25 with hierarchy-expanded results)

(defun irs--clean-snippet (snippet)
  (thread-last (or snippet "")
               (replace-regexp-in-string "[\n\r]+" " ")
               (replace-regexp-in-string "[ \t]+" " ")
               (string-trim)))

(defun irs--candidates (results)
  "Build an alist of (display-string . result-alist), deduping displays."
  (let ((seen (make-hash-table :test #'equal))
        cands)
    (dolist (result (append results nil))
      (let* ((trail (append (alist-get 'heading_trail result) nil))
             (head (if trail (string-join trail " › ")
                     (file-name-nondirectory (or (alist-get 'path result) "?"))))
             (snippet (irs--clean-snippet (alist-get 'snippet result)))
             (display (concat (propertize head 'face 'bold)
                              (and (not (string-empty-p snippet)) "  ")
                              snippet))
             (n (gethash display seen 0)))
        (puthash display (1+ n) seen)
        (when (> n 0)
          (setq display (format "%s (%d)" display (1+ n))))
        (push (cons display result) cands)))
    (nreverse cands)))

(defun irs--visit (result)
  "Open RESULT's file and move point near the hit, best effort."
  (find-file (alist-get 'path result))
  (goto-char (point-min))
  (let ((trail (append (alist-get 'heading_trail result) nil))
        (snippet (or (alist-get 'snippet result) "")))
    ;; trail is document -> ... -> parent; the document title isn't in the
    ;; buffer text, so search for the innermost heading only.
    (when (> (length trail) 1)
      (let ((heading (car (last trail))))
        (when (and (stringp heading) (not (string-empty-p heading)))
          (search-forward heading nil t))))
    ;; then the first FTS-highlighted term, if any
    (when (string-match "«\\([^»]+\\)»" snippet)
      (search-forward (match-string 1 snippet) nil t))
    (when (fboundp 'org-fold-show-context)
      (ignore-errors (org-fold-show-context)))))

(defun irs--present (query data)
  "Complete over DATA's results for QUERY and jump to the selection."
  (let* ((results (alist-get 'results data))
         (mode (alist-get 'match_mode data))
         (cands (irs--candidates results)))
    (cond
     ((null cands)
      (message "irs: no results for %S" query))
     (t
      (when (equal mode "or")
        (message "irs: no strict match — showing any-term results"))
      (let* ((prompt (format "irs %s(%d): " query (length cands)))
             (display
              (if (fboundp 'consult--read)
                  (consult--read (mapcar #'car cands)
                                 :prompt prompt
                                 :require-match t
                                 :sort nil
                                 :category 'irs-result)
                (completing-read prompt (mapcar #'car cands) nil t))))
        (when-let* ((result (assoc-default display cands)))
          (irs--visit result)))))))

(defun irs--run-search (endpoint query)
  (when (string-empty-p (string-trim query))
    (user-error "irs: empty query"))
  (irs-ensure-server
   (lambda ()
     (irs--post endpoint
                `((query . ,query) (limit . ,irs-search-limit))
                (lambda (data)
                  ;; don't open the minibuffer from inside a plz callback
                  (run-at-time 0 nil #'irs--present query data))))))

;;;###autoload
(defun irs-search (query)
  "Search the corpus lexically (BM25) via the irs backend."
  (interactive (list (read-string "irs search: " nil 'irs-search-history)))
  (irs--run-search "/v1/search/fts" query))

;;;###autoload
(defun irs-search-semantic (query)
  "Search the corpus by meaning (embeddings) via the irs backend."
  (interactive (list (read-string "irs semantic: " nil 'irs-search-history)))
  (irs--run-search "/v1/search/semantic" query))

;;;###autoload
(defun irs-search-hybrid (query)
  "Search the corpus with RRF fusion + rerank — the flagship retriever."
  (interactive (list (read-string "irs hybrid: " nil 'irs-search-history)))
  (irs--run-search "/v1/search/hybrid" query))

(provide 'irs)
;;; irs.el ends here
