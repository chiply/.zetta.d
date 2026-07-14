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

(require 'autorevert)                   ; `irs-show-log' tails the server log
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

(defcustom irs-pid-file "~/.local/share/irs/irs.pid"
  "PID file written by `irs serve', used by `irs-restart-server' to stop it.
This mirrors the backend's own data_dir rather than being told by it, so
it goes stale if the backend runs under $IRS_DATA_DIR or a config.toml
data_dir override — point it at that directory's irs.pid if so."
  :type 'file)

(defcustom irs-log-file "~/.local/share/irs/irs.log"
  "File the server's output is appended to when Emacs spawns it.
The backend is deliberately detached — it outlives the Emacs that
started it and is shared across Emacsen — so it is not an Emacs
subprocess and never appears in `list-processes'.  This file is the only
view of its output; see `irs-show-log'.  A server started by hand
outside Emacs logs wherever that shell pointed it, not here."
  :type 'file)

(defvar irs--live-last-input nil
  "Most recent input the live dynamic source queried with.")

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
  ;; detach via a transient shell so the server survives the Emacs that
  ;; started it and is shared across Emacsen (design doc, Operational);
  ;; the backend's PID-file lock makes a racing second spawn a no-op.
  ;; Being detached, it is nobody's subprocess -- output would otherwise
  ;; go nowhere, so append it to `irs-log-file' (`irs-show-log' reads it).
  (let* ((default-directory (expand-file-name irs-backend-directory))
         (log (expand-file-name irs-log-file)))
    (make-directory (file-name-directory log) t)
    (make-process :name "irs-server-launcher"
                  :buffer nil
                  :command (list shell-file-name shell-command-switch
                                 (format "nohup uv run irs serve >>%s 2>&1 &"
                                         (shell-quote-argument log)))
                  :noquery t))
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
                (message "irs: server did not come up — see %s (M-x irs-show-log)"
                         (abbreviate-file-name (expand-file-name irs-log-file)))))))

;;;###autoload
(defun irs-show-log ()
  "Tail the backend's log in a buffer, following new output as it arrives."
  (interactive)
  (let ((log (expand-file-name irs-log-file)))
    (if (not (file-exists-p log))
        (message "irs: no log at %s yet — it is written when Emacs spawns the server"
                 (abbreviate-file-name log))
      (find-file-other-window log)
      (goto-char (point-max))
      (auto-revert-tail-mode 1))))

;;;; Restart: stop the process named by the PID file, then spawn

;; `ps' here is a local, millisecond call — the no-synchronous-calls rule
;; this client follows is about HTTP, which is what blocks meaningfully.

(defun irs--pid-live-p (pid)
  (zerop (call-process "ps" nil nil nil "-p" (number-to-string pid))))

(defun irs--pid-is-irs-p (pid)
  "Non-nil if PID's command line looks like the irs backend.
A PID file outlives its process whenever the server dies without running
its atexit hook, and the number is then free to be recycled by something
unrelated; without this check a restart could signal an innocent
process."
  (with-temp-buffer
    (and (zerop (call-process "ps" nil t nil "-p" (number-to-string pid)
                              "-o" "command="))
         (string-match-p "\\birs\\b" (buffer-string)))))

(defun irs--server-pid ()
  "PID of the running backend per `irs-pid-file', or nil if none is trustworthy."
  (let ((file (expand-file-name irs-pid-file)))
    (when (file-readable-p file)
      (let* ((text (with-temp-buffer
                     (insert-file-contents file)
                     (string-trim (buffer-string))))
             (pid (and (string-match-p "\\`[0-9]+\\'" text)
                       (string-to-number text))))
        (when (and pid (irs--pid-live-p pid) (irs--pid-is-irs-p pid))
          pid)))))

(defun irs--await-stop (pid retries)
  (cond
   ((not (irs--pid-live-p pid))
    (message "irs: stopped — starting…")
    (irs--spawn-server nil))
   ((> retries 0)
    (run-at-time 0.25 nil #'irs--await-stop pid (1- retries)))
   (t
    (message "irs: pid %s did not exit — not starting a second server" pid))))

;;;###autoload
(defun irs-restart-server ()
  "Restart the irs backend, starting one if none is running.
The service reads its config.toml once at startup, so a server that is
already up keeps serving the corpus roots it booted with — edit the
config, then run this, or an ingest will silently use the old roots."
  (interactive)
  (let ((pid (irs--server-pid)))
    (if (not pid)
        (progn (message "irs: no server to stop — starting…")
               (irs--spawn-server nil))
      (message "irs: stopping pid %s…" pid)
      (signal-process pid 'TERM)
      (irs--await-stop pid 40))))

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

(defun irs--start-job (label endpoint &optional on-done on-fail)
  "Start the backend job at ENDPOINT, then poll it to completion.
LABEL names the job in the start message; the finish message is
formatted by `irs--job-done-message' from the kind the server reports.
ON-DONE and ON-FAIL are passed to `irs--poll-job'."
  (irs-ensure-server
   (lambda ()
     (irs--post endpoint nil
                (lambda (data)
                  (let ((job-id (alist-get 'job_id data)))
                    (message "irs: %s started (job %s)" label job-id)
                    (irs--poll-job job-id on-done on-fail)))))))

(defun irs--job-done-message (job)
  "Report the result of finished JOB, formatted for its kind.
Each job kind returns a disjoint result shape, so the kinds cannot share
a formatter; an unknown kind prints its raw result rather than
misreporting it under another kind's keys."
  (let ((r (alist-get 'result job)))
    (pcase (alist-get 'kind job)
      ("ingest"
       (message "irs: ingest done — %s ingested, %s unchanged, %s deleted, %s errors"
                (alist-get 'files_ingested r)
                (alist-get 'files_unchanged r)
                (alist-get 'files_deleted r)
                (length (alist-get 'errors r))))
      ("embed"
       (message "irs: embed done — %s embedded, %s failed (model %s)"
                (alist-get 'embedded r)
                (alist-get 'failed r)
                (alist-get 'model r)))
      ("graph"
       ;; Links that resolve to no file are the norm, not an error: they
       ;; upsert a concept node and LINKS_TO points there.  Report both
       ;; numbers so a low resolved-count doesn't read as a failure.
       (message "irs: graph done — %s edges, %s concepts (epoch %s); %s/%s links resolved to files"
                (alist-get 'edges r)
                (alist-get 'concepts r)
                (alist-get 'epoch r)
                (alist-get 'resolved r)
                (alist-get 'links_seen r)))
      ("knn"
       (let ((note (alist-get 'note r)))
         (if note
             (message "irs: knn — %s" note)
           (message "irs: knn done — %s SIMILAR_TO edges over %s vectors (epoch %s, model %s)"
                    (alist-get 'edges r)
                    (alist-get 'vectors r)
                    (alist-get 'epoch r)
                    (alist-get 'model r)))))
      (kind (message "irs: %s done — %S" kind r)))))

(defun irs--poll-job (job-id &optional on-done on-fail)
  "Poll JOB-ID to completion and report its result.
ON-DONE is called with the finished job only when it succeeded — a
chained caller must not advance on a stage that failed — and ON-FAIL
with no arguments when it did not."
  (irs--get (format "/v1/jobs/%s" job-id)
            (lambda (job)
              (pcase (alist-get 'state job)
                ("running"
                 (run-at-time 2 nil #'irs--poll-job job-id on-done on-fail))
                ("done"
                 (irs--job-done-message job)
                 (when on-done (funcall on-done job)))
                (_
                 (message "irs: %s failed: %s"
                          (alist-get 'kind job) (alist-get 'error job))
                 (when on-fail (funcall on-fail)))))))

;;;; Pipeline commands: ingest -> embed -> graph -> knn

;;;###autoload
(defun irs-ingest ()
  "Trigger a corpus ingest job and report progress until it finishes."
  (interactive)
  (irs--start-job "ingest" "/v1/ingest"))

;;;###autoload
(defun irs-embed ()
  "Embed all non-fresh corpus text via the backend; reports when done."
  (interactive)
  (irs--start-job "embed" "/v1/embed"))

;;;###autoload
(defun irs-graph ()
  "Rebuild the typed edge graph (LINKS_TO, MENTIONS, DERIVED_FROM).
This is a full rebuild by design, not an incremental pass: link
resolution is global, so a newly ingested page can resolve targets that
dangled before.  Run it after `irs-ingest'."
  (interactive)
  (irs--start-job "graph" "/v1/graph/build"))

;;;###autoload
(defun irs-knn ()
  "Rebuild the k-NN SIMILAR_TO edges from the stored embeddings.
An epoch-stamped batch artifact: it depends on `irs-embed' having run,
and re-runs wholesale rather than incrementally, because one node's new
embedding can change an unrelated node's neighbour list."
  (interactive)
  (irs--start-job "knn" "/v1/graph/knn"))

(defconst irs--pipeline-stages
  '(("ingest" . "/v1/ingest")
    ("embed"  . "/v1/embed")
    ("graph"  . "/v1/graph/build")
    ("knn"    . "/v1/graph/knn"))
  "The pipeline in dependency order (design doc, Pipeline).
Nodes must exist before they can be embedded and embeddings before k-NN
can find neighbours; graph build resolves links over whatever ingest
produced.  Each stage is a whole-corpus job, so they cannot overlap.")

(defun irs--run-pipeline (stages n total)
  (if (null stages)
      (message "irs: pipeline done — %s/%s stages finished" total total)
    (let ((label (caar stages))
          (endpoint (cdar stages)))
      (message "irs: pipeline %s/%s — %s…" n total label)
      (irs--start-job
       label endpoint
       (lambda (_job) (irs--run-pipeline (cdr stages) (1+ n) total))
       (lambda () (message "irs: pipeline aborted at %s (%s/%s) — later stages skipped"
                           label n total))))))

;;;###autoload
(defun irs-pipeline ()
  "Run the whole backend pipeline: ingest, then embed, graph and knn.
Each stage starts only once the previous one has finished, and a failed
stage aborts the rest rather than building later artifacts on a
half-finished index.  Everything is async; the echo area reports each
stage as it starts and finishes.

Long: `irs-embed' downloads the model on first run and re-embeds every
changed node.  Nothing here blocks Emacs."
  (interactive)
  (irs--run-pipeline irs--pipeline-stages 1 (length irs--pipeline-stages)))

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
          (irs--report-selection query result)
          (irs--visit result)))))))

(defun irs--report-selection (query result)
  "Fire-and-forget: tell the backend which RESULT was picked for QUERY.
Selections are a noise-free relevance signal (design doc: usage-feedback
boosting); errors are silently ignored."
  (ignore-errors
    (irs--post "/v1/feedback/selection"
               `((query . ,query)
                 (node_id . ,(alist-get 'node_id result))
                 (stable_key . ,(alist-get 'stable_key result))
                 (retriever . ,(alist-get 'retriever result)))
               #'ignore #'ignore)))

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

;;;; As-you-type dynamic source (consult 3.x)
;;
;; The contract (consult--async-dynamic): the compute function runs inside
;; while-no-input and its callback MUST fire before it returns.  So: start
;; the async plz request, pump accept-process-output until the response
;; lands (a keystroke aborts the pump), and unwind-protect kills the curl
;; process so an abandoned request never leaks.

(declare-function consult--dynamic-collection "ext:consult")
(declare-function consult--lookup-member "ext:consult")

(defun irs--live-compute (endpoint)
  "Interruptible compute function for `consult--dynamic-collection'."
  (lambda (input callback)
    (setq irs--live-last-input input)
    (let* ((done nil) (response nil)
           (proc (irs--post endpoint
                            `((query . ,input) (limit . ,irs-search-limit))
                            (lambda (data) (setq response data done t))
                            (lambda (_err) (setq done t)))))
      (unwind-protect
          (while (not done)
            (accept-process-output nil 0.05))
        (when (and (processp proc) (process-live-p proc))
          (delete-process proc)))
      (when response
        (funcall callback
                 (mapcar (lambda (pair)
                           (propertize (car pair) 'irs-result (cdr pair)))
                         (irs--candidates (alist-get 'results response))))))))

;;;###autoload
(defun irs-search-live ()
  "As-you-type hybrid search over the corpus (dynamic consult source)."
  (interactive)
  (unless (fboundp 'consult--read)
    (user-error "irs: the live source needs consult"))
  (irs-ensure-server (lambda () (run-at-time 0 nil #'irs--live-read))))

(defun irs--live-read ()
  (let ((selected
         (consult--read
          (consult--dynamic-collection (irs--live-compute "/v1/search/hybrid")
            :min-input 2 :throttle 0.3 :debounce 0.2)
          :prompt "irs live: "
          :require-match t
          :sort nil
          :category 'irs-result
          :lookup #'consult--lookup-member)))
    (when-let* ((result (and selected
                             (get-text-property 0 'irs-result selected))))
      (irs--report-selection (or irs--live-last-input "") result)
      (irs--visit result))))

;;;; gptel tools (M6): each retrieval primitive as a tool the LLM coordinates

(declare-function gptel-make-tool "ext:gptel")

(defcustom irs-gptel-tool-limit 8
  "Default result count for gptel tool calls."
  :type 'natnum)

(defun irs--tool-trim (result)
  "Trim RESULT to the fields worth an LLM's tokens."
  (let (out)
    (dolist (key '(node_id stable_key kind title path score via line sources))
      (let ((value (alist-get key result)))
        (when value (push (cons key value) out))))
    (let ((trail (append (alist-get 'heading_trail result) nil))
          (snippet (irs--clean-snippet (or (alist-get 'snippet result) ""))))
      (when trail
        (push (cons 'heading_trail (string-join trail " › ")) out))
      (unless (string-empty-p snippet)
        (push (cons 'snippet (substring snippet 0 (min 240 (length snippet))))
              out)))
    (nreverse out)))

(defun irs--tool-format (data)
  "Render DATA's results as compact JSON for the model."
  (let ((results (append (alist-get 'results data) nil)))
    (if (null results)
        "no results"
      (json-encode (vconcat (mapcar #'irs--tool-trim results))))))

(defun irs--tool-error (callback)
  (lambda (err)
    (funcall callback
             (format "irs backend error: %s"
                     (or (and (fboundp 'plz-error-message)
                              (plz-error-message err))
                         err)))))

(defun irs--tool-post (callback endpoint payload &optional formatter)
  (irs-ensure-server
   (lambda ()
     (irs--post endpoint payload
                (lambda (data)
                  (funcall callback (funcall (or formatter #'irs--tool-format)
                                             data)))
                (irs--tool-error callback)))))

(defun irs--tool-search (endpoint)
  "Async gptel tool function for a (query, limit) search ENDPOINT."
  (lambda (callback query &optional limit)
    (irs--tool-post callback endpoint
                    `((query . ,query)
                      (limit . ,(or limit irs-gptel-tool-limit))))))

;;;###autoload
(defun irs-setup-gptel-tools ()
  "Register the irs retrieval tools with gptel (idempotent by tool name)."
  (interactive)
  (unless (fboundp 'gptel-make-tool)
    (user-error "irs: gptel-make-tool not available — load gptel first"))
  (let ((query-arg '(:name "query" :type string
                     :description "search query"))
        (limit-arg '(:name "limit" :type integer :optional t
                     :description "max results")))
    (gptel-make-tool
     :name "irs_hybrid_search" :category "irs" :async t
     :description "Search the personal corpus (notes, wiki, design docs, PDFs). Best default: fuses lexical+semantic retrieval, then reranks."
     :args (list query-arg limit-arg)
     :function (irs--tool-search "/v1/search/hybrid"))
    (gptel-make-tool
     :name "irs_fts_search" :category "irs" :async t
     :description "Lexical BM25 search; strongest when the query words appear verbatim in notes."
     :args (list query-arg limit-arg)
     :function (irs--tool-search "/v1/search/fts"))
    (gptel-make-tool
     :name "irs_semantic_search" :category "irs" :async t
     :description "Meaning-based search over embeddings; finds notes sharing no words with the query."
     :args (list query-arg limit-arg)
     :function (irs--tool-search "/v1/search/semantic"))
    (gptel-make-tool
     :name "irs_exact_search" :category "irs" :async t
     :description "Literal line-based search (ripgrep) across corpus files; for identifiers, exact phrases, code."
     :args (list query-arg
                 '(:name "regex" :type boolean :optional t
                   :description "treat query as a regex")
                 limit-arg)
     :function (lambda (callback query &optional regex limit)
                 (irs--tool-post callback "/v1/search/exact"
                                 `((query . ,query)
                                   ,@(when regex '((regex . t)))
                                   (limit . ,(or limit 20))))))
    (gptel-make-tool
     :name "irs_expand_context" :category "irs" :async t
     :description "Flagship retrieval: find seeds for the query (or expand given node ids) along links, shared concepts, similarity and hierarchy edges, then rerank the whole neighbourhood. Use to gather context around a topic."
     :args (list query-arg
                 '(:name "seeds" :type array :items (:type integer) :optional t
                   :description "node ids to expand from (from earlier results)")
                 limit-arg)
     :function (lambda (callback query &optional seeds limit)
                 (irs--tool-post
                  callback "/v1/context/expand"
                  `((query . ,query)
                    ,@(when seeds `((seeds . ,(append seeds nil))))
                    (limit . ,(or limit 15)))
                  (lambda (data)
                    (concat (irs--tool-format data)
                            "\nvia: " (json-encode (alist-get 'via data)))))))
    (gptel-make-tool
     :name "irs_graph_neighbors" :category "irs" :async t
     :description "Typed graph edges around nodes: LINKS_TO, MENTIONS, SIMILAR_TO, DERIVED_FROM plus hierarchy."
     :args '((:name "node_ids" :type array :items (:type integer)
              :description "node ids to inspect"))
     :function (lambda (callback node-ids)
                 (irs--tool-post callback "/v1/graph/neighbors"
                                 `((node_ids . ,(append node-ids nil)))
                                 #'json-encode)))
    (gptel-make-tool
     :name "irs_get_node" :category "irs" :async t
     :description "Fetch one node: full text plus ancestors and children."
     :args '((:name "node_id" :type integer :description "node id"))
     :function (lambda (callback node-id)
                 (irs-ensure-server
                  (lambda ()
                    (irs--get (format "/v1/nodes/%s" node-id)
                              (lambda (data)
                                (let* ((node (alist-get 'node data))
                                       (body (alist-get 'body node)))
                                  (when (and body (> (length body) 2000))
                                    (setf (alist-get 'body node)
                                          (concat (substring body 0 2000) "…")))
                                  (funcall callback (json-encode data))))
                              (irs--tool-error callback)))))))
  (message "irs: gptel tools registered (category \"irs\")"))

(provide 'irs)
;;; irs.el ends here
