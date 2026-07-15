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
  :commands (irs-search
             irs-status irs-ingest irs-embed irs-embed-images irs-graph irs-knn
             irs-pipeline irs-ensure-server irs-restart-server irs-show-log)
  :init
  ;; M8: one command over every retriever — narrow with l/f/s/h/i, scope with
  ;; `--root=blog --type=org'. The per-retriever commands are gone; they were
  ;; five ways to ask the same question.
  (when (and (boundp 'launch-map)
             (not (lookup-key launch-map "/")))
    (define-key launch-map "/" #'irs-search))
  ;; M6: the retrieval primitives as gptel tools (category "irs")
  (with-eval-after-load 'gptel
    (require 'irs)
    (irs-setup-gptel-tools)))

;;; tools/irs.el ends here
