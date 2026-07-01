;;; hywiki-graph.el --- Text graph view of HyWiki links -*- lexical-binding: t; -*-

;; Thin wrapper around the in-tree `hywiki-graph' package (under
;; `source/zettapkg/').  When it is factored out to its own repo, swap
;; `:ensure nil' + `:load-path' for `:ensure t'.
;;
;; `hywiki-graph' prompts for a WikiWord and renders its link neighbourhood
;; as a text graph; the numeric prefix arg sets how many degrees out to show
;; (`C-u 3 M-x hywiki-graph').  In the buffer, 1-9 change the degree, RET
;; recenters on the node at point, o opens its page, g rebuilds from disk.
;;
;; Bound to {, G} (the `launch-map' prefix) when available.  The command is
;; autoloaded, so the binding pulls in the package (and Hyperbole) on first
;; use.

;; Optional view backends.  `hywiki-graph' soft-requires each; when absent,
;; that view is simply omitted (the built-in text views always work).
(use-package graph-fa2
  :ensure (graph-fa2 :type git :host github :repo "elij/graph-fa2")
  :defer t)

;; Layered DAG flowchart view (the `layered' style).
(use-package dag-draw
  :ensure (dag-draw :type git :host codeberg :repo "Trevoke/dag-draw.el"
                    :branch "congruence")
  :defer t)

(use-package hywiki-graph
  :ensure nil
  :load-path "source/zettapkg/hywiki-graph"
  :commands (hywiki-graph)
  :init
  (when (boundp 'launch-map)
    (define-key launch-map "G" #'hywiki-graph)))

;;; hywiki-graph.el ends here
