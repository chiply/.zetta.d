;;; irs.el --- Client for the information-retrieval-service backend -*- lexical-binding: t; -*-

;; Author: Charlie Holland
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (plz "0.9") (consult "3.0"))
;; Keywords: tools, matching

;;; Commentary:

;; Thin async HTTP client for the irs backend — the FastAPI service at
;; ~/source_code/information-retrieval-service (design doc:
;; text-search.org at the .zetta.d root).
;;
;; Two surfaces over the same endpoints:
;;
;; - `irs-search' (M8) — one `consult--multi' over every retriever at once.
;;   Narrow to pick one: `l' literal (ripgrep), `f' inverted index (BM25),
;;   `s' semantic, `h' hybrid (RRF + rerank), `i' images (CLIP, hidden by
;;   default).  Scope with flags in the input — `--root=blog --type=org' —
;;   which are passed to the backend rather than filtered here.  Marginalia
;;   shows each hit's root and file type; embark expands the graph around it.
;;
;; - `irs-setup-gptel-tools' (M6) — the same primitives as LLM tools.
;;
;; Plus lifecycle (probe -> adopt -> spawn) and the pipeline commands.
;;
;; Every request is an async `plz' call; nothing here blocks the command
;; loop.  The consult sources use a custom async stage rather than
;; `consult--dynamic-collection', which forbids the late callbacks an HTTP
;; response necessarily is — see "The async stage" below.

;;; Code:

(require 'autorevert)                   ; `irs-show-log' tails the server log
(require 'json)
(require 'plz)
(require 'subr-x)

;; `marginalia--fields' / `marginalia--field' are macros, so they must be
;; available when this file is compiled -- but they expand completely, so
;; marginalia stays a compile-time dependency only.  Nothing here loads it:
;; the annotator below is called by marginalia or not at all.
(eval-when-compile (require 'marginalia nil t))

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

(defconst irs--limit-ceilings
  '(("/v1/search/exact"    . 10000)
    ("/v1/search/fts"      . 10000)
    ("/v1/search/images"   . 10000)
    ("/v1/search/semantic" . 200)
    ("/v1/search/hybrid"   . 200))
  "Server-side `limit' ceiling per search endpoint (api.py request models).

Two tiers, split by what a big request costs the backend: exact, fts and
images only fetch more rows, so they take a huge ceiling — `--limit=' a
very large number to ask for everything.  semantic pays hierarchy-expand
per hit and hybrid feeds the cross-encoder, so those two stay at 200.
The clamp exists because the backend rejects an over-ceiling value with
a 422, which would blank that source's results entirely.")

(defconst irs--limit-max 200
  "Fallback `limit' ceiling for an endpoint not in `irs--limit-ceilings'.
The conservative tier, so an unlisted endpoint can never be sent a value
its request model might 422 on.")

(defconst irs--neighbors-limit-max 200
  "Server ceiling on `/v1/graph/neighbors' `limit' (NeighborsRequest.limit).
The graph actions clamp their prompted max to this rather than send a value
the backend would reject with a 422.")

(defconst irs--expand-limit-max 100
  "Server ceiling on `/v1/context/expand' `limit' (ContextExpandRequest.limit).")

(defcustom irs-search-limit 20
  "Maximum results to request per search, per source.

`irs-search' shows up to this many hits under EACH visible source, so
the unnarrowed list can be several times this long.

Values above an endpoint's ceiling (`irs--limit-ceilings') are clamped
rather than sent: the backend rejects them with a 422, which would blank
that source while its cheaper neighbours — whose ceilings are higher —
kept working.  So `--limit=10000' returns up to 10000 literal/fts/image
hits but caps semantic and hybrid at their 200."
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

(defvar irs--status nil
  "Last verified /v1/status response, cached by `irs-ensure-server'.
Holds the corpus roots (for resolving a result's root) and per-retriever
readiness (which gates the search sources).")

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

;;;; Result cache — memoised per request, dropped on any build
;;
;; The one thing the client did not cache was retrieval itself: every keystroke
;; and every graph pull re-hit the backend, even for an identical request.  The
;; cache below keys on the full request identity (endpoint + payload — and the
;; payload already carries every param that changes a result: query, limit,
;; facets, depth, descend), so a hit is always a correct hit.
;;
;; Validity is "until a build".  `irs-ensure-server' refreshes `irs--status' at
;; the head of every command, so a signature drawn from it costs no request and
;; moves whenever ANY pipeline stage (ingest/embed/graph/knn) touches the index
;; — including builds run outside this Emacs.  When it moves, the whole table is
;; dropped: a stale result is never served across a rebuild.  In-memory only, so
;; a restart starts empty; single-threaded async, so no lock is needed.

(defcustom irs-cache-enabled t
  "Whether retrieval responses are memoised between identical requests.
The cache is dropped whenever a build (ingest/embed/graph/knn) changes the
index, so it never serves results from before a rebuild.  Set nil to always
hit the backend."
  :type 'boolean)

(defvar irs--result-cache (make-hash-table :test #'equal)
  "Decoded retrieval responses keyed by `irs--cache-key'.
Only valid for `irs--result-cache-signature'; a build invalidates it.")

(defvar irs--result-cache-signature nil
  "The `irs--corpus-signature' the cache currently holds results for.")

(defun irs--corpus-signature ()
  "A value that changes when any build stage alters the index.
Read from the already-fetched `irs--status', so it costs no request: a
result cached under one signature is refetched once the signature moves."
  (let ((c (alist-get 'corpus irs--status))
        (g (alist-get 'graph irs--status)))
    (list (alist-get 'last_ingest (alist-get 'index irs--status))
          (alist-get 'nodes_total c)
          (alist-get 'epoch g)
          (alist-get 'knn_epoch g)
          (alist-get 'vectors (alist-get 'embedder irs--status))
          (alist-get 'vectors (alist-get 'clip irs--status)))))

(defun irs--cache-key (endpoint payload)
  "Stable cache key for the request ENDPOINT + PAYLOAD.
The json encoding is the request identity: same key iff same request."
  (cons endpoint (json-encode payload)))

(defun irs--cache-refresh ()
  "Drop the whole cache when a build has moved the corpus signature.
Both `irs--cache-get' and `irs--cache-put' call this first, so the table is
never left holding entries from before a rebuild — and a `put' anchors the
signature just as a `get' does, so the two do not depend on call order."
  (let ((sig (irs--corpus-signature)))
    (unless (equal sig irs--result-cache-signature)
      (clrhash irs--result-cache)
      (setq irs--result-cache-signature sig))))

(defun irs--cache-get (key)
  "Cached response for KEY, or nil, honouring `irs-cache-enabled'."
  (when irs-cache-enabled
    (irs--cache-refresh)
    (gethash key irs--result-cache)))

(defun irs--cache-put (key value)
  "Store VALUE under KEY and return it, honouring `irs-cache-enabled'."
  (when irs-cache-enabled
    (irs--cache-refresh)
    (puthash key value irs--result-cache))
  value)

;;;###autoload
(defun irs-cache-clear ()
  "Drop every cached retrieval result, forcing the next request to the backend."
  (interactive)
  (clrhash irs--result-cache)
  (setq irs--result-cache-signature nil)
  (when (called-interactively-p 'interactive)
    (message "irs: result cache cleared")))

(defun irs--post-cached (path payload then &optional else)
  "Like `irs--post', but serve a fresh cached response body when one exists.
Caches the decoded response keyed on PATH+PAYLOAD; a build drops it.  On a
hit THEN is still called asynchronously (via `run-at-time'), so callers
keep the same control flow whether the answer came from the wire or memory."
  (let* ((key (irs--cache-key path payload))
         (cached (irs--cache-get key)))
    (if cached
        (run-at-time 0 nil then cached)
      (irs--post path payload
                 (lambda (data) (funcall then (irs--cache-put key data)))
                 else))))

;;;; Server lifecycle: probe -> verify identity -> adopt, else spawn

(defun irs-ensure-server (&optional callback)
  "Make sure an irs backend answers at `irs-base-url', then call CALLBACK.
Adopts an already-running server after verifying the /v1/status service
identity; only spawns a new one when nothing answers.

The verified response is cached in `irs--status' — every command already
pays for this probe, so the corpus roots and retriever readiness the
search sources need cost no second request."
  (interactive)
  (irs--get "/v1/status"
            (lambda (data)
              (if (equal (alist-get 'service data) "irs")
                  (progn
                    (setq irs--status data)
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

(defun irs--status-refresh ()
  "Refresh `irs--status' in the background, gating nothing.
Unlike `irs-ensure-server' nothing waits on this: `irs-search' opens its
minibuffer synchronously and the probe lands whenever it lands.  And
unlike `irs-ensure-server' it never spawns — when nothing answers it
says how to start the backend instead, because the old auto-spawn held
the prompt through a health poll of up to ten seconds."
  (irs--get "/v1/status"
            (lambda (data)
              (if (equal (alist-get 'service data) "irs")
                  (setq irs--status data)
                (message "irs: %s is answering at %s — not irs"
                         (or (alist-get 'service data) "something else")
                         irs-base-url)))
            (lambda (_err)
              (message
               (substitute-command-keys
                "irs: no backend at %s — \\[irs-restart-server] starts it (or `uv run irs serve' in %s)")
               irs-base-url
               (abbreviate-file-name (expand-file-name irs-backend-directory))))))

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
      ("clip"
       ;; Candidates are raster only: SVG is excluded upstream, since its
       ;; labels are already exact text by the time CLIP could guess at them.
       (message "irs: image embed done — %s embedded, %s failed of %s raster candidates (model %s)"
                (alist-get 'embedded r)
                (alist-get 'failed r)
                (alist-get 'candidates r)
                (alist-get 'model r)))
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

;;;###autoload
(defun irs-embed-images ()
  "CLIP-embed corpus images, so `irs-search' can find them under `i'.
A second, independent vector space from `irs-embed': that one reads an
image's extracted text (SVG labels, OCR) and cannot see a picture
carrying no text at all, which is what this one is for.  Downloads
~600MB on first run and loads it only when there is work to do."
  (interactive)
  (irs--start-job "embed-images" "/v1/embed/images"))

(defconst irs--pipeline-stages
  '(("ingest"       . "/v1/ingest")
    ("embed"        . "/v1/embed")
    ("embed-images" . "/v1/embed/images")
    ("graph"        . "/v1/graph/build")
    ("knn"          . "/v1/graph/knn"))
  "The pipeline in dependency order (design doc, Pipeline).
Nodes must exist before they can be embedded and embeddings before k-NN
can find neighbours; graph build resolves links over whatever ingest
produced.  Each stage is a whole-corpus job, so they cannot overlap.

Image embedding sits after `embed' and before the graph stages, which do
not read its vectors — k-NN builds SIMILAR_TO from the text model only,
CLIP living in a space of its own.  It is in the pipeline because image
search otherwise rots silently as pictures are added, and it is cheap to
include: with nothing to embed the backend loads no model at all.")

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

;;;; Search: one consult--multi over every retriever (M8)
;;
;; One command, one source per retriever, narrowing to pick among them.  The
;; per-retriever commands are gone: they were five ways to ask the same
;; question, and the point is to ask once and see who answers.
;;
;; Every source is HTTP.  Exact retrieval is the one the design doc pinned as
;; frontend-local, and M8 revised that on measurement: `rg' is 282ms of the
;; 284ms round trip, and doing it locally would need one `rg' per root (they
;; have different include/formats globs) plus a reimplementation of the
;; backend's `file_selected' glob engine -- which the backend needs because
;; rg's gitignore semantics are not the corpus glob contract.  A second glob
;; matcher, hand-synced forever, to save 2ms.  See text-search.org, M8.

(declare-function consult--multi "ext:consult")
(declare-function consult--command-split "ext:consult")
(declare-function consult--async-pipeline "ext:consult")
(declare-function consult--async-min-input "ext:consult")
(declare-function consult--async-throttle "ext:consult")
(declare-function consult--temporary-files "ext:consult")
(declare-function consult--jump-state "ext:consult")
(declare-function consult--file-action "ext:consult")
(declare-function consult--lookup-member "ext:consult")
;; `marginalia--fields' expands into this; reachable only from the annotator,
;; which only marginalia itself calls
(declare-function marginalia--truncate "ext:marginalia")

(defcustom irs-search-sources '(literal fts semantic hybrid images)
  "Retrievers offered by `irs-search', in display order.
Every entry gets a narrowing key whether or not it is visible by
default; see `irs-search-hidden-sources'."
  :type '(repeat (choice (const literal) (const fts) (const semantic)
                         (const hybrid) (const images))))

(defcustom irs-search-hidden-sources '(images)
  "Sources hidden until narrowed to.
A hidden source costs nothing at all: `consult--multi' puts a
visibility predicate ahead of each source's async stage, so a source
that is not shown never receives the input and never fires a request.

`images' is hidden for a property of CLIP rather than a preference.
Cosine ranks rather than filters, so `/search/images' has no relevance
floor and cannot be given one -- a query with no answer still returns
`irs-search-limit' confidently-ordered pictures.  Visible, it would
inject that many junk images into every text search forever.  It is one
`i' away."
  :type '(repeat symbol))

(defcustom irs-search-preview-key 'any
  "Preview key(s) for `irs-search', as consult's `:preview-key'.
The default `any' previews the candidate under point as you move — the
same as `consult-preview-key'.  Set it to a key, e.g. \"C-=\", for
opt-in preview: matches are then shown only when you press that key on
one, never automatically.

Applied per source: `consult--multi' reads each source's
`:preview-key' (falling back to `consult-preview-key' otherwise), so a
source-level setting works without any `consult-customize' on the
command."
  :type '(choice (const :tag "Preview as you move" any)
                 (const :tag "No preview" nil)
                 (key :tag "Manual preview key")
                 (repeat key)))

;;; Corpus metadata, from the /v1/status probe every command already pays for

(defun irs--corpus ()
  (alist-get 'corpus irs--status))

(defun irs--roots ()
  "Corpus roots as a list of (ALIAS . ABSOLUTE-PATH), longest path first.
Longest first because roots can nest: the server prefix-matches paths to
resolve a root, so a shorter root that prefixes a longer one would claim
its results."
  (sort (mapcar (lambda (r) (cons (alist-get 'alias r) (alist-get 'path r)))
                (append (alist-get 'roots (irs--corpus)) nil))
        (lambda (a b) (> (length (cdr a)) (length (cdr b))))))

(defun irs--root-aliases ()
  (mapcar #'car (irs--roots)))

(defun irs--known-types ()
  "Every value `--type=' accepts: adapter formats plus file extensions."
  (append (append (alist-get 'formats (irs--corpus)) nil)
          (append (alist-get 'extensions (irs--corpus)) nil)))

(defun irs--retriever-ready-p (name)
  "Non-nil when the backend reports retriever NAME usable.
Gates each source's :enabled, so a source whose retriever is not ready
simply does not appear -- better than offering a search that 503s."
  (let ((r (alist-get (intern name) (alist-get 'retrievers irs--status))))
    ;; absent = an older backend that predates the readiness block; assume
    ;; usable rather than hiding a working retriever
    (or (null r) (not (eq (alist-get 'ready r) :json-false)))))

(defun irs--root-of (path)
  "Alias of the corpus root containing PATH, or nil."
  (when path
    (car (seq-find (lambda (root)
                     (string-prefix-p (file-name-as-directory (cdr root)) path))
                   (irs--roots)))))

;;; Input: query plus --root= / --type= / --limit= flags
;;
;; Parsed with `consult--command-split' -- consult's own parser, the one
;; consult-ripgrep/grep/find already use, so the muscle memory transfers and
;; there is no bespoke parser to maintain.  Measured: spot's " -- " separator
;; does NOT work here; consult reads `--' as "options end" and folds the rest
;; back into the query.  Bare `--root=blog', options start at the first
;; space-dash.
;;
;; Flag values are lists: `--root=blog+zetta', or repeat the flag.  The
;; separator is `+' because a comma cannot reach this parser from the
;; minibuffer: `consult--read' wraps every async function with
;; `consult--async-split' (`consult--async-wrap', consult.el:2138) and this
;; config splits on comma (`consult-async-split-style'), so everything after
;; the first comma is client-side filter input, never backend input --
;; `--root=a,b' silently searches root `a' and orderless-filters on "b".
;; The regexp still accepts comma for input that skips the minibuffer (the
;; gptel tools call this parser with plain strings).
;;
;; Full minibuffer grammar (worked examples in text-search.org):
;;   QUERY [FLAGS...] [-- LITERAL-QUERY-TEXT] [,ORDERLESS-COMPONENT...]
;; e.g. `server --root=notes -- -v,proxy,section' -- query "server -v"
;; scoped to notes, rows then narrowed on "proxy" and "section".

(defconst irs--flag-regexp "\\`--?\\([a-z]+\\)=\\(.*\\)\\'"
  "One `--key=value' flag.  Matched generically and dispatched on the key,
rather than one alternation per flag: three capture groups for three
flags is where that regexp stops being readable.")

(defun irs--parse-input (input)
  "Split INPUT into a plist of :query, :roots, :formats, :limit and :valid.

:valid is nil when a flag is unknown or names something the backend does
not know.  The source then declines to search at all, rather than firing
a request per keystroke that 400s while `--root=b', `--root=bl',
`--root=blo' are typed on the way to `--root=blog'."
  (pcase-let* ((`(,query . ,opts) (consult--command-split input))
               (roots nil) (formats nil) (limit nil) (valid t))
    (dolist (opt opts)
      (save-match-data
        (if (not (string-match irs--flag-regexp opt))
            (setq valid nil)          ; an unknown flag is not a query word
          ;; Bind the groups BEFORE any further matching: `split-string' and
          ;; `string-match-p' clobber the match data, and reading a group
          ;; afterwards returns nil -- which once filed `--root=a,b' under
          ;; formats and silently searched nothing.
          (let ((key (match-string 1 opt))
                (val (match-string 2 opt)))
            (pcase key
              ((or "root" "r")
               (setq roots (append roots (split-string val "[,+]" t "[ \t]+"))))
              ((or "type" "t")
               (setq formats (append formats (split-string val "[,+]" t "[ \t]+"))))
              ((or "limit" "l")
               ;; a half-typed `--limit=' or `--limit=1x' must not search with
               ;; the default and look like it honoured the flag
               (if (string-match-p "\\`[0-9]+\\'" val)
                   (setq limit (string-to-number val))
                 (setq valid nil)))
              (_ (setq valid nil)))))))
    (when (or (seq-difference roots (irs--root-aliases))
              (seq-difference formats (irs--known-types)))
      (setq valid nil))
    (list :query (string-trim query) :roots roots :formats formats
          :limit limit :valid valid)))

(defun irs--request-payload (parsed endpoint)
  "Backend request body for PARSED input, bound for ENDPOINT.
The facets travel to the server rather than filtering here, because a
flag filters BEFORE `limit' and a client-side filter after it: ask for
20 hits, narrow to Org, get 3.  That is a wrong result, not a slow one.

ENDPOINT picks the limit ceiling (`irs--limit-ceilings'): the cheap
retrievers accept a huge `--limit=', the reranked ones clamp at 200 —
so one flag value can mean \"everything\" where everything is affordable
without handing the cross-encoder a 10000-row pool."
  (let ((roots (plist-get parsed :roots))
        (formats (plist-get parsed :formats)))
    `((query . ,(plist-get parsed :query))
      ;; `--limit=' overrides the default for this query only; both go through
      ;; the same clamp, so neither route can send a value the backend 422s on
      (limit . ,(max 1 (min (or (plist-get parsed :limit) irs-search-limit)
                            (or (cdr (assoc endpoint irs--limit-ceilings))
                                irs--limit-max))))
      ,@(when roots `((roots . ,(vconcat roots))))
      ,@(when formats `((formats . ,(vconcat formats)))))))

;;; Rendering

(defun irs--clean-snippet (snippet)
  (thread-last (or snippet "")
               (replace-regexp-in-string "[\n\r]+" " ")
               (replace-regexp-in-string "[ \t]+" " ")
               (string-trim)))

(defun irs--uniquify (cands)
  "Suffix duplicate display strings in CANDS, preserving order.
Completion collapses candidates that are `equal', so two results
rendering identically would leave one of them permanently unreachable."
  (let ((seen (make-hash-table :test #'equal)))
    (mapcar (lambda (cand)
              (let ((n (gethash (substring-no-properties cand) seen 0)))
                (puthash (substring-no-properties cand) (1+ n) seen)
                (if (> n 0)
                    (concat cand (propertize (format " (%d)" (1+ n))
                                             'face 'shadow))
                  cand)))
            cands)))

(defcustom irs-search-label-width 44
  "Max display width of a result's heading/title on the candidate line.
The candidate is `label  snippet'; marginalia's columns (root, type,
kind, score) are right-aligned AFTER it, so an unbounded candidate fills
the line and pushes the annotation off the right edge — which is exactly
what a long capture title like
\"(highlights eww) github.com/namilus/completions-overlay-annotations\"
does.  Bounding both parts reserves room for the annotation."
  :type 'natnum)

(defcustom irs-search-snippet-width 68
  "Max display width of a result's snippet on the candidate line.
See `irs-search-label-width' for why the candidate is bounded at all."
  :type 'natnum)

(defun irs--truncate (string width)
  "STRING truncated to WIDTH display columns, ellipsised when cut.
Counts columns, not characters, so wide glyphs and the `›' separator are
measured as displayed; text properties (faces) are preserved."
  (if (> (string-width string) width)
      (truncate-string-to-width string width nil nil t)
    string))

(defun irs--result-label (result)
  "Headline for RESULT: its heading trail, else its file name."
  (let ((trail (append (alist-get 'heading_trail result) nil)))
    (cond
     (trail (string-join trail " › "))
     ((not (string-empty-p (or (alist-get 'title result) ""))) (alist-get 'title result))
     (t (file-name-nondirectory (or (alist-get 'path result) "?"))))))

(defun irs--candidate (result)
  "One propertized candidate string for RESULT.

A propertized string, not a (display . data) pair: `consult--multi'
passes the pair's cdr through as the candidate datum, and embark needs a
string for its target.  Spot's pattern, and the reason it works.

Label and snippet are each bounded (`irs-search-label-width',
`irs-search-snippet-width') so the line leaves room for the marginalia
columns; the snippet is kept — it is the matching text — just capped."
  (let* ((label (irs--result-label result))
         (line (alist-get 'line result))
         (snippet (irs--clean-snippet (alist-get 'snippet result)))
         ;; a text-free image has no body and the backend falls back to the
         ;; title for its snippet -- don't render the same string twice.
         ;; Compare against the FULL label, before truncation.
         (snippet (if (string= snippet label) "" snippet)))
    (propertize
     (concat (propertize (irs--truncate label irs-search-label-width) 'face 'bold)
             (when line (propertize (format ":%d" line) 'face 'shadow))
             (unless (string-empty-p snippet)
               (concat "  " (irs--truncate snippet irs-search-snippet-width))))
     'irs-result result)))

(defun irs--candidates (data)
  (irs--uniquify (mapcar #'irs--candidate (append (alist-get 'results data) nil))))

;;; Image candidates
;;
;; The score is NOT rendered into the line here, unlike the M7-era
;; `irs-search-images' it replaces.  It is in the marginalia column with every
;; other retriever's, labelled and colour-coded -- one score per result, in one
;; place, on a scale the label names.  The M7 reasoning is unchanged and is why
;; that column colours CLIP against `irs-image-strong-score': cosine has no
;; relevance floor and its scores are compressed (~0.33 found, ~0.24 the top of
;; the noise), so for this one source the number needs interpreting rather than
;; just reading.  See `irs--score-face'.

(defcustom irs-image-strong-score 0.28
  "Cosine at which a CLIP image hit starts to look like a real match.
A display hint: at or above this a score is highlighted, below it
dimmed.  Measured on this corpus, ~0.33 meant \"found it\" and ~0.24
meant \"no such picture exists\".  The backend imposes no floor of its
own."
  :type 'number)

(defun irs--image-candidate (result)
  (let* ((title (or (alist-get 'title result)
                    (file-name-nondirectory (or (alist-get 'path result) "?"))))
         (text (irs--clean-snippet (alist-get 'snippet result)))
         ;; a text-free image has no body and the backend falls back to the
         ;; title for its snippet -- don't render the same string twice
         (text (if (string= text title) "" text)))
    (propertize
     (concat (propertize (irs--truncate title irs-search-label-width) 'face 'bold)
             (unless (string-empty-p text)
               (concat "  " (propertize (irs--truncate text irs-search-snippet-width)
                                        'face 'shadow))))
     'irs-result result)))

(defun irs--image-candidates (data)
  (irs--uniquify (mapcar #'irs--image-candidate
                         (append (alist-get 'results data) nil))))

;;; The async stage
;;
;; `consult--async-dynamic' runs its compute function inside `while-no-input'
;; and errors if the callback fires after it returns ("Callback called too
;; late", consult.el).  The M7-era live source worked around that by pumping
;; `accept-process-output' until the response landed -- tolerable for one
;; source, wrong for five: each keystroke would serialise four blocking pumps,
;; the slowest being hybrid's cross-encoder.
;;
;; So bypass it and implement the async protocol directly.  The sink itself has
;; no late-callback rule; only `consult--async-dynamic' does.  Modelled on
;; `consult--async-process', including its deferred flush.

(defun irs--async-kill (proc)
  "Kill an in-flight plz PROC, so an abandoned request leaks no curl."
  (when (and (processp proc) (process-live-p proc))
    (delete-process proc)))

(defun irs--async-search (endpoint format-fn)
  "Async function querying ENDPOINT as the input changes.
FORMAT-FN renders a decoded response into candidate strings."
  (lambda (sink)
    (let (proc last-input)
      (lambda (action)
        (pcase action
          ((pred stringp)
           (funcall sink action)
           (unless (equal action last-input)
             (setq last-input action)
             (irs--async-kill proc)
             (setq proc nil)
             (let ((parsed (irs--parse-input action)))
               (if (or (not (plist-get parsed :valid))
                       (string-empty-p (plist-get parsed :query)))
                   ;; nothing answerable: clear rather than leave stale hits
                   (progn (funcall sink 'flush)
                          (funcall sink [indicator finished]))
                 (let* ((payload (irs--request-payload parsed endpoint))
                        (key (irs--cache-key endpoint payload))
                        (cached (irs--cache-get key)))
                   (if cached
                       ;; identical request, no build since: answer from memory,
                       ;; no round trip.  Synchronous, so the stale-guard is moot.
                       (progn (funcall sink 'flush)
                              (funcall sink (funcall format-fn cached))
                              (funcall sink [indicator finished]))
                     ;; Deferred flush, as in `consult--async-process': hold the
                     ;; old candidates until the new ones land, so the list does
                     ;; not blink to empty on every keystroke.
                     (let ((flush t) (input action))
                       (funcall sink [indicator running])
                       (setq proc
                             (irs--post
                              endpoint payload
                              (lambda (data)
                                ;; Stale guard.  Five sources answer at wildly
                                ;; different latencies (1ms fts vs 190ms hybrid),
                                ;; so a slower earlier request outliving a newer
                                ;; one is the normal case, not the edge case.
                                (when (equal input last-input)
                                  (irs--cache-put key data)
                                  (when flush (setq flush nil) (funcall sink 'flush))
                                  (funcall sink (funcall format-fn data))
                                  (funcall sink [indicator finished])))
                              (lambda (_err)
                                (when (equal input last-input)
                                  (when flush (setq flush nil) (funcall sink 'flush))
                                  (funcall sink [indicator failed])))))))))))
           nil)
          ((or 'cancel 'destroy)
           (irs--async-kill proc)
           (setq proc nil last-input nil)
           (funcall sink action))
          (_ (funcall sink action)))))))

(defun irs--source-async (endpoint &optional format-fn)
  (consult--async-pipeline
   (consult--async-min-input 2)
   (consult--async-throttle 0.3 0.2)
   (irs--async-search endpoint (or format-fn #'irs--candidates))))

;;; Preview and visiting

(defun irs--seek (result)
  "Move point to RESULT's hit in the current buffer, best effort."
  (goto-char (point-min))
  (let ((line (alist-get 'line result))
        (trail (append (alist-get 'heading_trail result) nil))
        (snippet (or (alist-get 'snippet result) "")))
    (cond
     ;; only /search/exact carries a line, and it is exact
     (line (forward-line (1- line)))
     (t
      ;; trail is document -> ... -> parent; the document title is not in the
      ;; buffer text, so seek the innermost heading only
      (when (> (length trail) 1)
        (let ((heading (car (last trail))))
          (when (and (stringp heading) (not (string-empty-p heading)))
            (search-forward heading nil t))))
      ;; then the first FTS-highlighted term, if any
      (when (string-match "«\\([^»]+\\)»" snippet)
        (search-forward (match-string 1 snippet) nil t))))))

(defun irs--position (cand &optional find-file)
  "Marker for CAND's hit, opening its file with FIND-FILE.

CAND is nil more often than it looks: consult passes nil on `setup' and
`exit', and `consult--multi' passes it to the PREVIOUS source's state
whenever the cursor crosses into another source's group.  Guard it
first — `get-text-property' on nil throws args-out-of-range rather than
returning nil, and an error here aborts consult's setup, which leaves
`consult--async-indicator' without its overlay and turns the next
[indicator running] into a baffling (wrong-type-argument overlayp nil)."
  (when-let* ((cand)
              (result (get-text-property 0 'irs-result cand))
              (path (alist-get 'path result))
              ((file-readable-p path))
              (buffer (funcall (or find-file #'consult--file-action) path))
              ((buffer-live-p buffer)))
    (with-current-buffer buffer
      (save-excursion
        (without-restriction
          (ignore-errors (irs--seek result))
          (point-marker))))))

(defun irs--state ()
  "Consult state previewing the file under point."
  (let ((open (consult--temporary-files))
        (jump (consult--jump-state)))
    (lambda (action cand)
      (unless cand (funcall open))      ; release the preview buffers
      (funcall jump action
               (irs--position cand (and (not (eq action 'return)) open))))))

;;; Image preview: a side window, because the eye settles what the score hints

(defcustom irs-image-preview t
  "Whether the images source previews the picture under point."
  :type 'boolean)

(defconst irs--image-preview-buffer " *irs-image*")

(defun irs--image-preview-show (path)
  "Display the image at PATH in a side window, scaled to fit."
  (let ((buffer (get-buffer-create irs--image-preview-buffer)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (condition-case err
            (insert-image
             (create-image path nil nil
                           :max-width (round (* 0.5 (frame-pixel-width)))
                           :max-height (round (* 0.8 (frame-pixel-height)))))
          ;; say so rather than showing an empty window: this Emacs may lack
          ;; the library for the type (webp, or librsvg for svg)
          (error (insert (format "irs: cannot display %s\n\n%s"
                                 (file-name-nondirectory path)
                                 (error-message-string err)))))))
    (display-buffer buffer '(display-buffer-in-side-window
                             (side . right) (window-width . 0.5)
                             (dedicated . t)))))

(defun irs--image-preview-hide ()
  (when-let* ((buffer (get-buffer irs--image-preview-buffer)))
    (when-let* ((window (get-buffer-window buffer)))
      (ignore-errors (delete-window window)))
    (kill-buffer buffer)))

(defun irs--image-state ()
  (lambda (action cand)
    (pcase action
      ('preview
       (let ((path (and cand (alist-get 'path (get-text-property
                                               0 'irs-result cand)))))
         (if (and path irs-image-preview (file-readable-p path))
             (irs--image-preview-show path)
           (irs--image-preview-hide))))
      ((or 'exit 'return) (irs--image-preview-hide)))))

;;; Sources

(defvar irs--history-literal nil)
(defvar irs--history-fts nil)
(defvar irs--history-semantic nil)
(defvar irs--history-hybrid nil)
(defvar irs--history-images nil)

(defun irs--source (key)
  "Build the consult source plist for KEY."
  (pcase-let ((`(,name ,narrow ,endpoint ,retriever ,history ,format-fn ,state)
               (pcase key
                 ('literal  (list "Literal (rg)" ?l "/v1/search/exact" "exact"
                                  'irs--history-literal nil #'irs--state))
                 ('fts      (list "Index (BM25)" ?f "/v1/search/fts" "fts"
                                  'irs--history-fts nil #'irs--state))
                 ('semantic (list "Semantic" ?s "/v1/search/semantic" "semantic"
                                  'irs--history-semantic nil #'irs--state))
                 ('hybrid   (list "Hybrid (RRF+rerank)" ?h "/v1/search/hybrid"
                                  "hybrid" 'irs--history-hybrid nil #'irs--state))
                 ('images   (list "Images (CLIP)" ?i "/v1/search/images" "images"
                                  'irs--history-images #'irs--image-candidates
                                  #'irs--image-state)))))
    `(:name ,name
      :narrow ,narrow
      :category irs-result
      :history ,history
      :async ,(irs--source-async endpoint format-fn)
      :state ,state
      ;; per-source, because consult--multi-preview-key reads it here and
      ;; falls back to consult-preview-key otherwise -- see the defcustom
      :preview-key ,irs-search-preview-key
      :hidden ,(and (memq key irs-search-hidden-sources) t)
      :enabled ,(lambda () (irs--retriever-ready-p retriever))
      ;; not a consult field; read back by `irs--report-selection'
      :irs-retriever ,retriever)))

;;; Feedback

(defun irs--report-selection (query result retriever)
  "Fire-and-forget: tell the backend which RESULT was picked for QUERY.
Selections are a noise-free relevance signal (design doc: usage-feedback
boosting); errors are silently ignored."
  (when (alist-get 'node_id result)
    (ignore-errors
      (irs--post "/v1/feedback/selection"
                 `((query . ,query)
                   (node_id . ,(alist-get 'node_id result))
                   (stable_key . ,(alist-get 'stable_key result))
                   (retriever . ,(or (alist-get 'retriever result) retriever)))
                 #'ignore #'ignore))))

;;; The command

(defvar irs--search-history nil)

;;;###autoload
(defun irs-search (&optional initial)
  "Search the corpus through every retriever at once.

Narrow to pick one: \\<consult-narrow-map>`l' literal (ripgrep), `f'
inverted index (BM25), `s' semantic (embeddings), `h' hybrid (RRF +
cross-encoder rerank), `i' images (CLIP).  Narrowing is not just a view
filter -- a source that is not shown never fires its request.

Scope with flags in the input, which are passed to the backend:

  svg rendering --root=blog --type=org
  kubernetes deploy --root=notes,zetta
  emacs --type=pdf --limit=50

`--root=' (`-r=') takes a corpus root alias.  `--type=' (`-t=') takes an
adapter format (org, md, pdf, code, image, txt, transcript) or a file
extension (svg, webp, el, py...) — the extension spelling exists because
the format collapses, so `--type=image' is every picture and
`--type=svg' is only the SVGs.  Repeat either flag or comma-separate to
widen.  `--limit=' (`-l=') overrides `irs-search-limit' for one query.

Flag values are validated against the backend before anything is sent,
so a typo searches nothing rather than quietly answering the wrong
question — and typing toward `--root=blog' does not fire a request per
keystroke.

The prompt opens immediately, like `consult-ripgrep'; the status probe
runs concurrently.  If no backend is answering, searches fail and the
echo area says how to start one — `irs-restart-server', or `uv run irs
serve' in `irs-backend-directory'.

INITIAL is the starting input."
  (interactive)
  (unless (fboundp 'consult--multi)
    (user-error "irs: irs-search needs consult"))
  ;; No async gate ahead of the read.  The old flow held the prompt through
  ;; a /v1/status round trip (a curl spawn, its sentinel, a `run-at-time'
  ;; hop) — lag when those callbacks ran promptly, and a minibuffer popping
  ;; up at some later surprising moment when the event loop was slow to run
  ;; them.  The probe still runs, concurrently, because search needs
  ;; `irs--status' only for flag validation, readiness gating and
  ;; marginalia — each of which degrades gracefully on a stale or nil
  ;; status, none of which is worth a wait the user can see.
  (irs--status-refresh)
  (irs--search-read initial))

(defun irs--search-read (initial)
  (pcase-let ((`(,cand . ,src)
               (consult--multi (mapcar #'irs--source irs-search-sources)
                               :prompt "irs: "
                               :require-match t
                               :sort nil
                               :initial initial
                               :history '(:input irs--search-history))))
    (when-let* (((plist-get src :match))
                (result (get-text-property 0 'irs-result cand))
                (query (plist-get (irs--parse-input (or (car irs--search-history) ""))
                                  :query)))
      (irs--report-selection query result (plist-get src :irs-retriever))
      (when-let* ((path (alist-get 'path result)))
        (find-file path)
        ;; An image IS the hit — there is no position inside it to seek to.
        ;; `equal', not `eq': json-read decodes JSON strings to Elisp strings,
        ;; so (eq kind 'image) is nil for every result there has ever been.
        (unless (equal (alist-get 'kind result) "image")
          (irs--seek result)
          (when (fboundp 'org-fold-show-context)
            (ignore-errors (org-fold-show-context))))))))

;;; Marginalia: which root, which type
;;
;; Neither facet is on the search response as such: `format' is (M8 added it),
;; but the root is not stored anywhere -- it is resolved by prefix-matching the
;; path against the corpus roots, which also works for the concept/source nodes
;; that have no root at all.
;;
;; Registered against the `irs-result' category and reached THROUGH
;; consult--multi by `marginalia-annotate-multi-category', which dispatches on
;; the multi-category text property to the inner category's annotator.

(defvar marginalia-annotators)

(defface irs-marginalia-root '((t :inherit marginalia-type))
  "Face for the corpus root field.")

(defface irs-marginalia-type '((t :inherit marginalia-value))
  "Face for the file-type field.")

(defface irs-marginalia-kind '((t :inherit marginalia-modified))
  "Face for the node-kind field.")

(defface irs-marginalia-score '((t :inherit marginalia-number))
  "Face for the score field.")

(defface irs-marginalia-relation '((t :inherit marginalia-key))
  "Face for the graph-relation field — the edge a neighbour arrived by.")

(defface irs-marginalia-hop '((t :inherit marginalia-number))
  "Face for the hop field — degrees of separation from the seed node.")

(defun irs--score-field (result)
  "RESULT's score, labelled with the scale it is on.

Five retrievers, five meanings for one number — measured on one query:
bm25 26.6, cosine 0.797, cross-encoder logit 6.48, CLIP cosine 0.284,
and exact has none at all.  Rendered bare they invite the one comparison
that is never valid: 26.60 sitting above 0.80 reads as the better hit
and is not (design doc, Contracts: score is retriever-native, scales are
NOT comparable across retrievers — sort within one, or trust server
order).  The label is what makes the column honest, and it is why the
number is worth showing at all: within a group it ranks, across groups
it only identifies."
  (let ((score (alist-get 'score result))
        (retriever (alist-get 'retriever result)))
    (cond
     ;; /search/exact is literal matching — it has no ranking to report
     ((null score) "")
     ((member retriever '("semantic" "image")) (format "cos %.2f" score))
     ((equal retriever "fts") (format "bm25 %.1f" score))
     ((equal retriever "hybrid")
      (if (alist-get 'rerank_score result)
          (format "ce %.2f" score)      ; cross-encoder logit, unbounded
        (format "rrf %.3f" score)))     ; fusion only: reranker off/unavailable
     (t (format "%.2f" score)))))

(defun irs--score-face (result)
  "Face for RESULT's score field.

CLIP is the one retriever whose number needs interpreting rather than
just reading: it has no relevance floor, so a query with no answer still
returns confidently-ordered pictures, and its scores are compressed —
measured on this corpus, ~0.33 meant \"found it\" and ~0.24 meant \"no
such picture exists\" (M7, tier 4).  So colour it against
`irs-image-strong-score'.  Every other retriever ranks within its own
group, where the ordering already carries that information."
  (if (equal (alist-get 'retriever result) "image")
      (if (>= (or (alist-get 'score result) 0) irs-image-strong-score)
          'success 'shadow)
    'irs-marginalia-score))

(defun irs--annotate-result (cand)
  "Annotate CAND with graph relation, hop, root, file type, kind and score.

The relation and hop columns are only present on results that came in
through a graph action (neighbors/expand) — relation names the edge that
reached them, hop the degrees of separation from the seed (0° is the
seed itself, re-presented by expand).  Initial-search results have
neither, and get the four-column annotation they always did: the two
branches differ only by those leading fields, so no empty column is ever
rendered."
  (when-let* ((result (get-text-property 0 'irs-result cand)))
    (let* ((path (alist-get 'path result))
           (relation (alist-get 'relation result))
           ;; hop rides in on both graph actions — /context/expand puts it on
           ;; every result, /graph/neighbors on every edge (folded in by
           ;; `irs--neighbor-results') — but a pre-depth backend omits it,
           ;; so an empty field must degrade gracefully
           (hop (let ((h (alist-get 'hop result)))
                  (if (numberp h) (format "%d°" h) "")))
           (root (or (irs--root-of path)
                     ;; concept/source nodes are synthesised at graph-build time
                     ;; and belong to no root and no file.  `member', not `memq':
                     ;; json-read gives strings, so the symbol test never matched.
                     (if (member (alist-get 'kind result) '("concept" "source"))
                         "—" "?")))
           (type (or (alist-get 'format result)
                     (and path (file-name-extension path))
                     "—"))
           (kind (format "%s" (or (alist-get 'kind result) "—")))
           (score (irs--score-field result))
           ;; :face is spliced into a runtime `propertize', so it can vary
           ;; per result -- CLIP colours against its floor, everything else flat
           (score-face (irs--score-face result)))
      (if relation
          (marginalia--fields
           (relation :truncate 20 :face 'irs-marginalia-relation)
           (hop :truncate 3 :face 'irs-marginalia-hop)
           (root :truncate 10 :face 'irs-marginalia-root)
           (type :truncate 10 :face 'irs-marginalia-type)
           (kind :truncate 10 :face 'irs-marginalia-kind)
           (score :truncate 11 :face score-face))
        (marginalia--fields
         (root :truncate 10 :face 'irs-marginalia-root)
         (type :truncate 10 :face 'irs-marginalia-type)
         (kind :truncate 10 :face 'irs-marginalia-kind)
         (score :truncate 11 :face score-face))))))

(defconst irs--marginalia-annotators
  '((irs-result irs--annotate-result builtin none)))

(with-eval-after-load 'marginalia
  (dolist (entry irs--marginalia-annotators)
    (add-to-list 'marginalia-annotators entry)))

;;; Embark: the graph is an action, not a source
;;
;; Retrieval finds the seed; the graph answers "now that I found something
;; relevant, what else should come with it?" (design doc, Guiding principle).
;; That is an action ON a result, not another list to search -- so the
;; structural layer lives here rather than as a sixth consult source.

(defvar embark-keymap-alist)
(defvar embark-general-map)
(defvar irs--graph-history nil
  "Minibuffer history for the re-presented neighbour/expand sessions.")

(defcustom irs-graph-descend-containers t
  "Whether graph actions resolve a container hit to its chunks first.

FTS and hybrid hits are usually whole documents or sections, and a
container node carries only hierarchy edges — the cross-document
SIMILAR_TO graph hangs off the leaf chunks beneath it.  With this on,
`irs-action-neighbors' and `irs-action-expand' ask the backend to
descend a container seed to its text_units before traversing, so a
document hit reaches the cross-document neighbourhood rather than just
its own sections.  A chunk hit is unaffected — it is already a leaf.

Sent as the `descend_containers' flag; the backend default is off, so
turning this off here restores the pinned neighbours/expand contract."
  :type 'boolean)

(defun irs--descend-flag ()
  "The `descend_containers' request value, as JSON true/false."
  (if irs-graph-descend-containers t :json-false))

;; The actions below are plain functions, NOT `(interactive)' commands, and
;; that is load-bearing.  Embark dispatches a command action by INJECTING its
;; target back into a minibuffer, and it injects the target
;; `substring-no-properties' (embark.el, `embark--act') — which strips the
;; `irs-result' text property every one of these reads.  A non-command
;; function takes embark's other path, funcalled with the propertized target
;; string intact.  Making these commands is what produced
;; "irs: no result data on this candidate".  (Spot's actions are plain
;; functions for the same reason.)

(defun irs--target (item)
  (or (get-text-property 0 'irs-result item)
      (user-error "irs: no result data on this candidate")))

(defun irs--node-id (item)
  (or (alist-get 'node_id (irs--target item))
      ;; /search/exact resolves nodes best-effort by path containment, so a
      ;; file the index has never seen still matches literally and carries no
      ;; node at all.  Every graph action needs one.
      (user-error "irs: this hit resolves to no indexed node — nothing to expand")))

(defun irs--present (buffer-name lines)
  (let ((buffer (get-buffer-create buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (string-join lines "\n"))
        (goto-char (point-min))
        (special-mode)))
    (display-buffer buffer)))

(defun irs--brief (node)
  "One line for NODE, from any of the endpoint shapes."
  (format "  %-9s %s%s"
          (or (alist-get 'kind node) "?")
          (or (let ((title (alist-get 'title node)))
                (and title (not (string-empty-p title)) title))
              (when-let* ((p (alist-get 'path node)))
                (file-name-nondirectory p))
              "—")
          (let ((path (alist-get 'path node)))
            (if-let* ((root (irs--root-of path)))
                (format "   [%s]" root) ""))))

(defun irs-action-show-data (item)
  "Display ITEM's raw result alist."
  (irs--present "*irs-result*" (list (pp-to-string (irs--target item)))))

(defun irs-action-open (item)
  "Open ITEM's file."
  (let ((result (irs--target item)))
    (if-let* ((path (alist-get 'path result)))
        (progn (find-file path) (irs--seek result))
      (user-error "irs: this node has no file"))))

;;; Graph results, re-presented in consult
;;
;; A neighbourhood is just more results — so show it the way search results are
;; shown (consult, preview on C-=, marginalia, embark) rather than dumping a
;; static buffer.  Selecting a neighbour visits it; acting on it again walks
;; another hop.  Two shapes feed in: /graph/neighbors nodes carry `id' + title
;; + path (no snippet/heading_trail/line), and /context/expand results carry
;; `id' (not `node_id'), a `via', a `hop' and a rerank `score'.  `irs--graph-result'
;; normalises both onto the `irs-result' shape the shared candidate/preview/
;; embark code already speaks, tagging each with the edge it arrived by.

(defun irs--graph-result (node relation &optional hop)
  "NODE (a /graph/neighbors or /context/expand summary) as an `irs-result'.

Normalises `id' -> `node_id' — /context/expand names it `id', and every
shared helper (`irs--node-id', `irs--report-selection') keys on
`node_id', so without this a re-presented node could not be acted on
again.  RELATION, the edge that reached this node, is stored under
`relation' for the marginalia; nil leaves the annotation untouched.
HOP, the degree of separation from the seed, is stored under `hop' — a
/context/expand result already carries its own `hop', so callers only
pass it for /graph/neighbors nodes, where it lives on the edge instead.
Non-destructive: only prepends, never mutates the decoded JSON."
  (let ((r node))
    (when (and (alist-get 'id r) (not (assq 'node_id r)))
      (setq r (cons (cons 'node_id (alist-get 'id r)) r)))
    (when relation
      (setq r (cons (cons 'relation relation) r)))
    (when (and hop (not (assq 'hop r)))
      (setq r (cons (cons 'hop hop) r)))
    r))

(defun irs--neighbor-results (data id)
  "DATA's neighbours of node ID as `irs-result' alists, edge-tagged.

The response is an adjacency map plus a flat edge list —
{nodes: {\"<id>\": node},
 edges: [{from_id, to_id, kind, weight, virtual, hop, reached}]}
— with `nodes' keyed by the id as a STRING (so `json-read' interns it).
`hop' is the degree of separation the edge was found on and `reached' the
node it discovered; both let a multi-hop pull (depth > 1) orient an edge
that touches neither seed.
Hierarchy edges arrive `virtual: t': computed from parent_id/ordinal at
read time, never stored, because two copies of one fact diverge on
re-chunk (design doc, Part 2).  k-NN writes SIMILAR_TO reciprocally
(A->B and B->A both exist), so dedup on (kind . other) or every semantic
neighbour lists twice."
  (let ((nodes (alist-get 'nodes data))
        (seen (make-hash-table :test #'equal))
        (out nil))
    (dolist (edge (append (alist-get 'edges data) nil))
      (let* ((from (alist-get 'from_id edge))
             (to (alist-get 'to_id edge))
             ;; `reached' names the node this edge discovered; past hop 1 the
             ;; edge touches neither seed, so the seed-relative fallback (used
             ;; when a pre-depth backend omits `reached') can't orient it.
             (reached (alist-get 'reached edge))
             (hop (alist-get 'hop edge))
             (outp (equal from id))
             (other (or reached (if outp to from)))
             (kind (format "%s" (alist-get 'kind edge)))
             (key (cons kind other)))
        (unless (gethash key seen)
          (puthash key t seen)
          (when-let* ((node (alist-get (intern (number-to-string other)) nodes)))
            (push (irs--graph-result
                   node
                   (concat
                    ;; the →/← arrow is meaningful only at hop 1, where the
                    ;; seed is an endpoint; past that the edge touches
                    ;; neither seed, so it gets a direction-free mark — the
                    ;; distance itself is the marginalia hop column's job
                    (cond ((and hop (> hop 1)) "· ")
                          (outp "→ ")
                          (t "← "))
                    kind
                    (when-let* ((w (alist-get 'weight edge)))
                      (format " %.2f" w))
                    (when (eq (alist-get 'virtual edge) t) " ⇡"))
                   hop)
                  out)))))
    (nreverse out)))

;; Graph results are rendered by `irs--candidate', the same builder search
;; uses: /graph/neighbors and /context/expand now return `heading_trail' and a
;; body `snippet' on every node (backend `_rich_summary'), so a neighbour reads
;; as "doc > section  <chunk text>" — distinct per section, content visible —
;; and `irs--seek' can jump to it on preview.  Before that enrichment these
;; were bare filenames that all collapsed together and previewed to the
;; document top.

(defun irs--seed-label (item)
  "Short headline for the seed ITEM, for a graph session's prompt."
  (irs--truncate (irs--result-label (irs--target item)) 48))

(defcustom irs-graph-label-width 34
  "Max display width of the heading on a graph result's candidate line.
Graph results (neighbours/expand) carry a marginalia column search
results do not — the relation — so their candidate is bounded tighter
than `irs-search-label-width' to leave the annotation room; otherwise the
extra column pushes the rightmost fields off the edge."
  :type 'natnum)

(defcustom irs-graph-snippet-width 50
  "Max display width of the snippet on a graph result's candidate line.
See `irs-graph-label-width'."
  :type 'natnum)

(defun irs--read-results (prompt results)
  "Present graph RESULTS in a consult session titled PROMPT, then visit
the choice.  Deferred through `run-at-time' because the plz callback that
calls this runs inside a process filter, and opening the minibuffer there
wedges the command loop."
  (run-at-time
   0 nil
   (lambda ()
     ;; render graph candidates tighter than search's: `irs--candidate' reads
     ;; these two widths dynamically, so binding them here reserves room for
     ;; the relation column without touching search's own layout
     (let* ((irs-search-label-width irs-graph-label-width)
            (irs-search-snippet-width irs-graph-snippet-width)
            (cands (irs--uniquify (mapcar #'irs--candidate results)))
            (choice (consult--read
                     cands
                     :prompt prompt
                     :category 'irs-result
                     :require-match t
                     :sort nil
                     :lookup #'consult--lookup-member
                     :state (irs--state)
                     :preview-key irs-search-preview-key
                     :history 'irs--graph-history)))
       (when-let* ((result (and choice (get-text-property 0 'irs-result choice)))
                   (path (alist-get 'path result)))
         (find-file path)
         ;; an image IS the hit; a concept/source node has no file at all and
         ;; never reaches here (no `path').  `equal', not `eq': json-read
         ;; decodes JSON strings to Elisp strings.
         (unless (equal (alist-get 'kind result) "image")
           (irs--seek result)
           (when (fboundp 'org-fold-show-context)
             (ignore-errors (org-fold-show-context)))))))))

(defun irs-action-neighbors (item)
  "Present ITEM's typed graph neighbours in a consult session.
LINKS_TO, MENTIONS, SIMILAR_TO, PART_OF — each annotated with the edge
that reaches it.  Pick one to visit it; act on it again to walk further.

Prompts for the max neighbours to return (clamped to
`irs--neighbors-limit-max') and the degrees of separation to reach: 1 is
the immediate neighbours; higher walks the graph breadth-first, tagging
each hit with the hop it was found on."
  (let* ((id (irs--node-id item))
         ;; may be invoked from within the search minibuffer (C-. n); embark's
         ;; default quit-after-action clears it first, but bind recursive
         ;; minibuffers so the prompts are safe either way
         (enable-recursive-minibuffers t)
         (limit (min (max 1 (read-number "max neighbours: " 50))
                     irs--neighbors-limit-max))
         (depth (read-number "degrees of separation: " 1)))
    (irs--post-cached
     "/v1/graph/neighbors" `((node_ids . ,(vector id))
                             (depth . ,depth)
                             (limit . ,limit)
                             (descend_containers . ,(irs--descend-flag)))
     (lambda (data)
       (let ((results (irs--neighbor-results data id)))
         (if (null results)
             (message "irs: no graph edges on node %s — has irs-graph run?" id)
           (irs--read-results (format "neighbors of %s: " (irs--seed-label item))
                              results)))))))

(defun irs-action-expand (item)
  "Expand context around ITEM — the flagship: seeds → graph → rerank.
The reranked frontier is re-presented in consult, each hit tagged with
the `via' edge it was reached through.

Prompts for the max results to return (clamped to `irs--expand-limit-max')
and the degrees of separation: 2 is the tuned base (linked notes, shared
concepts and sources); 1 keeps only the seed's direct edges, and higher
reaches further out before the whole neighbourhood is reranked."
  (let* ((id (irs--node-id item))
         ;; may be invoked from within the search minibuffer (C-. e); embark's
         ;; default quit-after-action clears it first, but bind recursive
         ;; minibuffers so the prompts are safe either way
         (enable-recursive-minibuffers t)
         (query (read-string "irs expand (query for reranking): "
                            (irs--result-label (irs--target item))))
         (limit (min (max 1 (read-number "max results: " 20))
                     irs--expand-limit-max))
         (depth (read-number "degrees of separation: " 2)))
    (message "irs: expanding around node %s…" id)
    (irs--post-cached
     "/v1/context/expand"
     `((query . ,query) (seeds . ,(vector id))
       (depth . ,depth)
       (limit . ,limit)
       (descend_containers . ,(irs--descend-flag)))
     (lambda (data)
       ;; /context/expand returns `id' (not `node_id') and carries `via' but
       ;; no snippet/heading_trail/line -- `irs--graph-result' folds both onto
       ;; the shared shape, so the same candidate/preview code renders it.
       (let ((results (mapcar (lambda (r)
                                (irs--graph-result
                                 r (format "%s" (or (alist-get 'via r) "?"))))
                              (append (alist-get 'results data) nil))))
         (if (null results)
             (message "irs: nothing to expand to from node %s" id)
           (irs--read-results (format "context around %s: " (irs--seed-label item))
                              results)))))))

(defun irs-action-node (item)
  "Show ITEM's node with its ancestors and children."
  (let ((id (irs--node-id item)))
    (irs--get
     (format "/v1/nodes/%s" id)
     (lambda (data)
       (let* ((node (alist-get 'node data))
              (body (or (alist-get 'body node) "")))
         (irs--present
          "*irs-node*"
          (append
           (list (format "%s  [%s]" (or (alist-get 'title node) "—")
                         (or (alist-get 'kind node) "?"))
                 (format "%s" (or (alist-get 'path node) "—"))
                 "")
           (when-let* ((parents (append (alist-get 'parents data) nil)))
             (append '("ancestors:") (mapcar #'irs--brief parents) '("")))
           (when-let* ((children (append (alist-get 'children data) nil)))
             (append '("children:") (mapcar #'irs--brief children) '("")))
           (list "body:" body))))))))

;; Defined inside the eval-after-load, not beside it: `:parent' EVALUATES
;; `embark-general-map' at load time, and this file is autoloaded by command,
;; so it can be loaded before embark is.  Defining it at top level makes
;; `M-x irs-search' a void-variable error in that order.
(defvar irs-embark-result-map)

(with-eval-after-load 'embark
  (defvar-keymap irs-embark-result-map
    :parent embark-general-map
    :doc "Embark actions on an irs search result."
    "n" #'irs-action-neighbors
    "e" #'irs-action-expand
    "d" #'irs-action-node
    "o" #'irs-action-open
    "s" #'irs-action-show-data)
  (add-to-list 'embark-keymap-alist '(irs-result . irs-embark-result-map)))


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
                 '(:name "depth" :type integer :optional t
                   :description "degrees of separation to reach (default 2, the tuned base; higher reaches further)")
                 limit-arg)
     :function (lambda (callback query &optional seeds depth limit)
                 (irs--tool-post
                  callback "/v1/context/expand"
                  `((query . ,query)
                    ,@(when seeds `((seeds . ,(append seeds nil))))
                    ,@(when depth `((depth . ,depth)))
                    (limit . ,(or limit 15)))
                  (lambda (data)
                    (concat (irs--tool-format data)
                            "\nvia: " (json-encode (alist-get 'via data)))))))
    (gptel-make-tool
     :name "irs_graph_neighbors" :category "irs" :async t
     :description "Typed graph edges around nodes: LINKS_TO, MENTIONS, SIMILAR_TO, DERIVED_FROM plus hierarchy."
     :args '((:name "node_ids" :type array :items (:type integer)
              :description "node ids to inspect")
             (:name "depth" :type integer :optional t
              :description "degrees of separation to walk (default 1)"))
     :function (lambda (callback node-ids &optional depth)
                 (irs--tool-post callback "/v1/graph/neighbors"
                                 `((node_ids . ,(append node-ids nil))
                                   ,@(when depth `((depth . ,depth))))
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
