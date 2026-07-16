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
  ;; M8: one command over every retriever — narrow with l/f/s/h/i, scope with
  ;; `--root=blog --type=org'. The per-retriever commands are gone; they were
  ;; five ways to ask the same question.
  ;;
  ;; `r' for retrieval, not `i': `, l i' is chiply-isr-semantic-read, and
  ;; irs/isr are one transposition apart already.
  :general
  (
   :keymaps 'menu-lookup-map
   "r" 'irs-search
   )
  :init
  ;; M6: the retrieval primitives as gptel tools (category "irs")
  (with-eval-after-load 'gptel
    (require 'irs)
    (irs-setup-gptel-tools)))

;;; tools/irs.el ends here
