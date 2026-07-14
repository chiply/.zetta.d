;;; tools/irs.el --- information-retrieval-service (irs) client -*- lexical-binding: t; -*-

;;; Commentary:
;; Search over the personal corpus (logseq pages/journals, hywiki, design
;; docs) via the irs FastAPI backend at
;; ~/source_code/information-retrieval-service.  Design doc:
;; text-search.org at the repo root.

;;; Code:

;; plz is the async HTTP layer irs.el is built on — declared explicitly
;; because it is otherwise only a transitive dependency of this config.
(use-package plz)

(use-package irs
  :ensure nil
  :load-path "source/zettapkg/irs"
  :commands (irs-search irs-search-semantic irs-search-hybrid irs-search-live
             irs-status irs-ingest irs-embed irs-graph irs-knn irs-pipeline
             irs-ensure-server irs-restart-server irs-show-log)
  :init
  ;; hybrid is the flagship: fuses fts + semantic, then reranks; it degrades
  ;; to fts-only when vectors aren't built yet, so it's always safe to bind
  (when (and (boundp 'launch-map)
             (not (lookup-key launch-map "/")))
    (define-key launch-map "/" #'irs-search-hybrid))
  ;; M6: the retrieval primitives as gptel tools (category "irs")
  (with-eval-after-load 'gptel
    (require 'irs)
    (irs-setup-gptel-tools)))

;;; tools/irs.el ends here
