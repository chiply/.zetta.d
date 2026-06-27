;;; hywiki-graph.el --- Text graph view of HyWiki word links -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; URL: https://github.com/<TBD>/hywiki-graph
;; Version: 0.3.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: hypermedia, outlines, convenience

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; A plain-text "graph view" for GNU Hyperbole's HyWiki, in the spirit of
;; Logseq's local graph.  WikiWords are nodes; an (undirected) edge joins two
;; WikiWords when one page's text mentions the other.
;;
;; `hywiki-graph' prompts for a WikiWord (with completion) and renders the
;; neighbourhood around it.  The numeric prefix argument sets how many link
;; hops ("degrees") out to include -- `C-u 3 M-x hywiki-graph' shows three
;; degrees; the default is one.
;;
;; Three text rendering styles, cycled with `v':
;;
;;   graph  A real node-and-line diagram drawn as text, via the external
;;          `graph-easy' program (which reads Graphviz DOT).  This is the
;;          default when graph-easy is available.  Best on sparse
;;          neighbourhoods; very dense ones (hubs) are capped -- see
;;          `hywiki-graph-graph-easy-max-edges' -- and fall back to the tree.
;;
;;   tree   A breadth-first spanning tree (indentation = distance from the
;;          centre) plus the remaining edges shown inline as `╌╌' cross-links.
;;          No external dependency; always available.
;;
;;   matrix An adjacency matrix (centre first): read a node's row or column
;;          to see every node it connects to.  Never tangles, whatever the
;;          density.  No external dependency.
;;
;;   dag    A git-log style rail diagram: every node on its own row in one
;;          column, each edge a vertical rail in a lane to the left.  Narrow
;;          and clean on sparse/tree-like graphs (busier on dense clusters).
;;          No external dependency.
;;
;; To get the `graph' style, install graph-easy once, e.g. with a user-local
;; Perl lib (no sudo):
;;
;;   brew install cpanminus
;;   cpanm --local-lib=~/perl5 Graph::Easy
;;
;; then ensure `hywiki-graph-graph-easy-program' / `-lib' point at it
;; (the defaults probe ~/perl5 and the PATH).
;;
;; Densely-connected "index" hubs (a page linked from nearly everywhere)
;; explode a neighbourhood and force the graph style to fall back to the
;; tree.  `hywiki-graph-prune-hubs' (default on) drops nodes whose global
;; degree exceeds `hywiki-graph-hub-threshold', keeping the neighbourhood
;; local enough to draw.  Toggle and tune it live with `h' / `[' / `]'.
;;
;; A fourth view, `svg', opens a force-directed diagram (via the optional
;; `graph-fa2' package) in its own buffer with the `s' key -- a settled
;; node-and-line layout rendered as an inline image; click a node to
;; recentre.  It is separate from the `v' cycle because graph-fa2 manages
;; its own (image) buffer.
;;
;; In the display buffer:
;;   1-9  re-render at that many degrees from the current centre
;;   v    cycle the text view style (graph -> tree -> matrix -> dag)
;;   s    open the force-directed SVG view (graph-fa2, separate buffer)
;;   h    toggle hub pruning on/off
;;   [ ]  lower / raise the hub-degree threshold (also enables pruning)
;;   RET  recentre the graph on the node at point
;;   o    open the WikiWord page at point
;;   g    rebuild the link graph from disk and re-render
;;   q    quit
;;
;; The link graph is scanned once and cached; press `g' after editing pages.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'thingatpt)
(require 'hywiki)

(declare-function hywiki-get-page-list "hywiki")
(declare-function hywiki-get-singular-wikiword "hywiki")
(declare-function hywiki-find-page "hywiki")
(declare-function hywiki-word-at "hywiki")
(defvar hywiki-word-regexp)
(defvar hywiki-allow-plurals-flag)
(defvar hywiki-directory)
(defvar hywiki-file-suffix)

;;;; Customization

(defgroup hywiki-graph nil
  "Plain-text graph view of HyWiki word links."
  :group 'hyperbole
  :prefix "hywiki-graph-")

(defcustom hywiki-graph-buffer-name "*HyWiki Graph*"
  "Name of the buffer used to display the HyWiki link graph."
  :type 'string)

(defcustom hywiki-graph-default-degree 1
  "Default number of link hops to display when no prefix argument is given."
  :type 'integer)

(defcustom hywiki-graph-default-style 'graph
  "Initial rendering style.
`graph' draws a node-and-line diagram via graph-easy (falling back to
`tree' when graph-easy is unavailable); `tree' draws a spanning tree with
inline cross-links."
  :type '(choice (const :tag "graph-easy diagram" graph)
                 (const :tag "spanning tree" tree)))

(defcustom hywiki-graph-graph-easy-program
  (or (executable-find "graph-easy")
      (let ((p (expand-file-name "perl5/bin/graph-easy" "~")))
        (and (file-executable-p p) p)))
  "Path to the `graph-easy' program, or nil if it is not available."
  :type '(choice (const :tag "Not available" nil) (file :must-match t)))

(defcustom hywiki-graph-graph-easy-lib
  (let ((p (expand-file-name "perl5/lib/perl5" "~")))
    (and (file-directory-p p) p))
  "Directory prepended to PERL5LIB when invoking graph-easy, or nil.
Needed when Graph::Easy was installed into a user-local Perl lib."
  :type '(choice (const :tag "None" nil) directory))

(defcustom hywiki-graph-graph-easy-format "boxart"
  "Output format passed to graph-easy as `--as=FORMAT'."
  :type '(choice (const "boxart") (const "ascii")))

(defcustom hywiki-graph-graph-easy-max-edges 70
  "Edge ceiling for the graph style.
Neighbourhoods with more edges fall back to the tree view, since
graph-easy tangles and slows badly on dense graphs."
  :type 'integer)

(defcustom hywiki-graph-prune-hubs t
  "When non-nil, omit high-degree hub nodes from rendered neighbourhoods.
A node counts as a hub when its global degree exceeds
`hywiki-graph-hub-threshold'.  The centre node is never pruned.  Pruning
index-style hubs (e.g. a page linked from everywhere) keeps a
neighbourhood local enough to draw as a graph.  Toggle live in the
display buffer with \\<hywiki-graph-mode-map>\\[hywiki-graph-toggle-hubs]."
  :type 'boolean)

(defcustom hywiki-graph-hub-threshold 30
  "Global degree above which a node is treated as a hub and may be pruned.
Adjust live in the display buffer with \\<hywiki-graph-mode-map>\\[hywiki-graph-hub-threshold-down] / \\[hywiki-graph-hub-threshold-up].
See `hywiki-graph-prune-hubs'."
  :type 'integer)

(defface hywiki-graph-center
  '((t :inherit bold))
  "Face for the centre WikiWord of the graph.")

(defface hywiki-graph-node
  '((t :inherit link :underline nil))
  "Face for WikiWord nodes in the graph.")

(defface hywiki-graph-edge
  '((t :inherit shadow))
  "Face for tree branches and cross-link annotations.")

;;;; Graph construction

(defvar hywiki-graph--adjacency nil
  "Cached adjacency hash: WikiWord -> list of neighbour WikiWords.
Undirected; rebuilt by `hywiki-graph--get-adjacency' with FORCE non-nil.")

;;;; Per-buffer display state

(defvar-local hywiki-graph--center nil
  "WikiWord at the centre of the currently displayed graph.")
(defvar-local hywiki-graph--degree 1
  "Number of link hops currently displayed.")
(defvar-local hywiki-graph--style 'graph
  "Current rendering style, `graph' or `tree'.")
(defvar-local hywiki-graph--prune-hubs nil
  "Whether high-degree hub nodes are pruned from the current display.")
(defvar-local hywiki-graph--hub-threshold 30
  "Degree above which a node is pruned as a hub in the current display.")

(defun hywiki-graph--page-set ()
  "Return a hash set (equal test) of all existing HyWiki page names."
  (let ((h (make-hash-table :test 'equal)))
    (dolist (w (hywiki-get-page-list)) (puthash w t h))
    h))

(defun hywiki-graph--canonical (token pageset)
  "Return the page name TOKEN denotes given PAGESET, or nil.
Resolves a plural TOKEN to its singular page when plurals are enabled."
  (cond ((gethash token pageset) token)
        ((and hywiki-allow-plurals-flag
              (let ((s (ignore-errors (hywiki-get-singular-wikiword token))))
                (and (stringp s) (gethash s pageset) s))))
        (t nil)))

(defun hywiki-graph--links-in-file (file pageset self)
  "Return the page names referenced in FILE, excluding SELF.
PAGESET is the hash set of valid page names; tokens matching
`hywiki-word-regexp' are intersected with it."
  (let ((found (make-hash-table :test 'equal)))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (re-search-forward hywiki-word-regexp nil t)
        (let* ((token (match-string-no-properties 1))
               (name (and token (hywiki-graph--canonical token pageset))))
          (when (and name (not (equal name self)))
            (puthash name t found)))))
    (hash-table-keys found)))

(defun hywiki-graph--build-adjacency ()
  "Scan every HyWiki page and return an undirected adjacency hash."
  (let ((pageset (hywiki-graph--page-set))
        (adj (make-hash-table :test 'equal))
        (pages (hywiki-get-page-list)))
    ;; Seed every page so isolated nodes still exist as keys.
    (dolist (w pages) (puthash w nil adj))
    (dolist (w pages)
      ;; Build the path explicitly within `hywiki-directory'.  Avoid
      ;; `hywiki-get-page-file', whose first branch returns a bare name when
      ;; it is readable relative to `default-directory' -- which, on a
      ;; case-insensitive filesystem, can resolve to an unrelated directory.
      (let ((file (expand-file-name (concat w hywiki-file-suffix)
                                    hywiki-directory)))
        (when (file-readable-p file)
          (dolist (nbr (hywiki-graph--links-in-file file pageset w))
            (cl-pushnew nbr (gethash w adj) :test #'equal)
            (cl-pushnew w (gethash nbr adj) :test #'equal)))))
    adj))

(defun hywiki-graph--get-adjacency (&optional force)
  "Return the cached adjacency hash, rebuilding it when FORCE or empty."
  (when (or force (null hywiki-graph--adjacency))
    (setq hywiki-graph--adjacency (hywiki-graph--build-adjacency)))
  hywiki-graph--adjacency)

(defun hywiki-graph--node-p (word)
  "Return non-nil if WORD is a node (page) in the cached graph."
  (and (stringp word)
       (let ((adj (hywiki-graph--get-adjacency)))
         (not (eq (gethash word adj :absent) :absent)))))

(defun hywiki-graph--hub-set (adj threshold center)
  "Return a hash set of hub nodes over ADJ, excluding CENTER.
A node is a hub when its degree (neighbour count) exceeds THRESHOLD."
  (let ((h (make-hash-table :test 'equal)))
    (maphash (lambda (n nbrs)
               (when (and (> (length nbrs) threshold) (not (equal n center)))
                 (puthash n t h)))
             adj)
    h))

(defun hywiki-graph--bfs (center adj degree &optional exclude)
  "Breadth-first search from CENTER over ADJ up to DEGREE hops.
Nodes in the EXCLUDE hash set are never visited or traversed through (the
CENTER is always kept).  Return a plist (:dist HASH :parent HASH :order
LIST) covering the reached nodes, in first-visit order."
  (let ((dist (make-hash-table :test 'equal))
        (parent (make-hash-table :test 'equal))
        (order '())
        (queue (list center)))
    (puthash center 0 dist)
    (push center order)
    (while queue
      (let* ((node (pop queue))
             (d (gethash node dist)))
        (when (< d degree)
          (dolist (nbr (sort (copy-sequence (gethash node adj)) #'string<))
            (unless (or (gethash nbr dist)
                        (and exclude (gethash nbr exclude)))
              (puthash nbr (1+ d) dist)
              (puthash nbr node parent)
              (push nbr order)
              (setq queue (nconc queue (list nbr))))))))
    (list :dist dist :parent parent :order (nreverse order))))

(defun hywiki-graph--induced (center degree adj &optional exclude)
  "Return (NODES . EDGES) for the CENTER neighbourhood within DEGREE over ADJ.
Nodes in the EXCLUDE hash set are omitted.  NODES is sorted; EDGES is a
list of (A . B) cons cells with A string< B."
  (let* ((bfs (hywiki-graph--bfs center adj degree exclude))
         (dist (plist-get bfs :dist))
         (nodes (sort (hash-table-keys dist) #'string<))
         (nodeset (let ((h (make-hash-table :test 'equal)))
                    (dolist (n nodes) (puthash n t h)) h))
         (edges '()))
    (dolist (n nodes)
      (dolist (m (sort (copy-sequence (gethash n adj)) #'string<))
        (when (and (gethash m nodeset) (string< n m))
          (push (cons n m) edges))))
    (cons nodes (nreverse edges))))

;;;; Header

(defun hywiki-graph--insert-header (center degree nodes edges style)
  "Insert the buffer header lines for CENTER, DEGREE, NODES, EDGES, STYLE."
  (insert
   (propertize (format "HyWiki graph: %s\n" center) 'face 'hywiki-graph-center)
   (propertize
    (format "%s · degree %d · %d node%s · %d edge%s · %s\n"
            style degree
            nodes (if (= nodes 1) "" "s")
            edges (if (= edges 1) "" "s")
            (if hywiki-graph--prune-hubs
                (format "hubs>%d pruned" hywiki-graph--hub-threshold)
              "hubs shown"))
    'face 'shadow)
   (propertize
    "[1-9] degree · v view · s svg · h hubs · [ ] threshold · RET recenter · o open · g refresh · q quit\n\n"
    'face 'shadow)))

;;;; Tree rendering

;; Dynamic state bound for the duration of a single tree render.
(defvar hywiki-graph--r-children nil)
(defvar hywiki-graph--r-parent nil)
(defvar hywiki-graph--r-idx nil)
(defvar hywiki-graph--r-adj nil)

(defun hywiki-graph--node-display (node)
  "Return NODE as a propertized, clickable string."
  (propertize node
              'face (if (equal node hywiki-graph--center)
                        'hywiki-graph-center
                      'hywiki-graph-node)
              'hywiki-graph-node node
              'mouse-face 'highlight
              'help-echo "RET/mouse-1: recenter   o: open page"))

(defun hywiki-graph--annotation (node)
  "Return the inline cross-link annotation string for NODE, or \"\".
Lists displayed neighbours of NODE that were visited earlier and are not
NODE's tree parent -- i.e. every non-tree edge, shown once on its later
endpoint."
  (let* ((my-idx (gethash node hywiki-graph--r-idx))
         (parent (gethash node hywiki-graph--r-parent))
         (cross (sort
                 (cl-remove-if-not
                  (lambda (m)
                    (let ((mi (gethash m hywiki-graph--r-idx)))
                      (and mi (< mi my-idx) (not (equal m parent)))))
                  (copy-sequence (gethash node hywiki-graph--r-adj)))
                 #'string<)))
    (if (null cross)
        ""
      (concat (propertize "  ╌╌ " 'face 'hywiki-graph-edge)
              (mapconcat (lambda (m)
                           (propertize m
                                       'face 'hywiki-graph-edge
                                       'hywiki-graph-node m
                                       'mouse-face 'highlight))
                         cross ", ")))))

(defun hywiki-graph--print-tree (node prefix is-root is-last)
  "Insert NODE and its subtree.
PREFIX is the accumulated indentation; IS-ROOT and IS-LAST select the
branch glyphs."
  (let ((branch (cond (is-root "")
                      (is-last "└─ ")
                      (t "├─ "))))
    (insert prefix
            (propertize branch 'face 'hywiki-graph-edge)
            (hywiki-graph--node-display node)
            (hywiki-graph--annotation node)
            "\n")
    (let* ((children (gethash node hywiki-graph--r-children))
           (child-prefix (concat prefix
                                 (cond (is-root "")
                                       (is-last "   ")
                                       (t (propertize "│  " 'face 'hywiki-graph-edge)))))
           (n (length children)))
      (cl-loop for c in children
               for i from 1
               do (hywiki-graph--print-tree c child-prefix nil (= i n))))))

(defun hywiki-graph--render-tree (center degree adj exclude &optional note)
  "Render the tree view for CENTER/DEGREE over ADJ, omitting EXCLUDE nodes.
Optional NOTE is an extra shadow line inserted under the header."
  (let* ((bfs (hywiki-graph--bfs center adj degree exclude))
         (dist (plist-get bfs :dist))
         (parent (plist-get bfs :parent))
         (order (plist-get bfs :order))
         (idx (make-hash-table :test 'equal))
         (children (make-hash-table :test 'equal))
         (edges (cdr (hywiki-graph--induced center degree adj exclude))))
    (cl-loop for n in order for i from 0 do (puthash n i idx))
    (maphash (lambda (n p) (push n (gethash p children))) parent)
    (maphash (lambda (p kids) (puthash p (sort kids #'string<) children)) children)
    (hywiki-graph--insert-header center degree (hash-table-count dist)
                                 (length edges) 'tree)
    (when note (insert (propertize (concat note "\n\n") 'face 'warning)))
    (let ((hywiki-graph--r-children children)
          (hywiki-graph--r-parent parent)
          (hywiki-graph--r-idx idx)
          (hywiki-graph--r-adj adj))
      (hywiki-graph--print-tree center "" t t))))

;;;; Graph (graph-easy) rendering

(defun hywiki-graph--graph-easy-available-p ()
  "Return non-nil when the graph-easy program is configured and executable."
  (and hywiki-graph-graph-easy-program
       (file-executable-p hywiki-graph-graph-easy-program)))

(defun hywiki-graph--dot (center nodes edges)
  "Return Graphviz DOT for CENTER over NODES and EDGES.
WikiWords are valid bare DOT identifiers (capitalised, alphabetic)."
  (concat (format "graph %s {\n" center)
          (mapconcat (lambda (n) (format "  %s;" n)) nodes "\n")
          (when edges "\n")
          (mapconcat (lambda (e) (format "  %s -- %s;" (car e) (cdr e))) edges "\n")
          "\n}\n"))

(defun hywiki-graph--run-graph-easy (dot)
  "Run graph-easy on DOT and return its text rendering, or nil on failure."
  (with-temp-buffer
    (let* ((lib hywiki-graph-graph-easy-lib)
           (process-environment
            (if lib
                (cons (concat "PERL5LIB=" lib
                              (let ((cur (getenv "PERL5LIB")))
                                (when (and cur (not (string-empty-p cur)))
                                  (concat ":" cur))))
                      process-environment)
              process-environment))
           (status (ignore-errors
                     (call-process-region
                      dot nil hywiki-graph-graph-easy-program nil t nil
                      "--from=dot" (concat "--as=" hywiki-graph-graph-easy-format)))))
      ;; graph-easy prints diagnostics to stderr (merged here); drop them.
      (flush-lines "^Warning:" (point-min) (point-max))
      (flush-lines "^.* at .*line [0-9]+\\.$" (point-min) (point-max))
      (let ((out (string-trim (buffer-string))))
        (when (and (memq status '(0 nil)) (not (string-empty-p out)))
          out)))))

(defun hywiki-graph--fontify-nodes (nodes)
  "Propertize whole-word occurrences of NODES in the buffer as clickable."
  (save-excursion
    (dolist (n nodes)
      (goto-char (point-min))
      (let ((re (concat "\\_<" (regexp-quote n) "\\_>")))
        (while (re-search-forward re nil t)
          (add-text-properties
           (match-beginning 0) (match-end 0)
           (list 'face (if (equal n hywiki-graph--center)
                           'hywiki-graph-center 'hywiki-graph-node)
                 'hywiki-graph-node n
                 'mouse-face 'highlight
                 'help-echo "RET/mouse-1: recenter   o: open page")))))))

(defun hywiki-graph--render-graph-easy (center degree adj exclude)
  "Render CENTER/DEGREE over ADJ as a graph-easy diagram, omitting EXCLUDE nodes.
Fall back to the tree view when graph-easy is unavailable, the
neighbourhood exceeds `hywiki-graph-graph-easy-max-edges', or the program
fails."
  (pcase-let* ((`(,nodes . ,edges) (hywiki-graph--induced center degree adj exclude))
               (n-edges (length edges)))
    (cond
     ((not (hywiki-graph--graph-easy-available-p))
      (hywiki-graph--render-tree
       center degree adj exclude
       "graph-easy not found — showing tree (see hywiki-graph-graph-easy-program)"))
     ((> n-edges hywiki-graph-graph-easy-max-edges)
      (hywiki-graph--render-tree
       center degree adj exclude
       (format "%d edges > cap (%d)%s — showing tree"
               n-edges hywiki-graph-graph-easy-max-edges
               (if hywiki-graph--prune-hubs "" "; try h to prune hubs"))))
     (t
      (let ((out (hywiki-graph--run-graph-easy
                  (hywiki-graph--dot center nodes edges))))
        (if (null out)
            (hywiki-graph--render-tree
             center degree adj exclude "graph-easy failed — showing tree")
          (hywiki-graph--insert-header center degree (length nodes) n-edges 'graph)
          (let ((start (point)))
            (insert out "\n")
            (save-restriction
              (narrow-to-region start (point))
              (hywiki-graph--fontify-nodes nodes)))))))))

;;;; Matrix rendering

(defun hywiki-graph--render-matrix (center degree adj exclude)
  "Render the CENTER/DEGREE neighbourhood over ADJ as an adjacency matrix.
Rows and columns are the neighbourhood's nodes (CENTRE first); a filled
cell marks an edge.  Read a node's row -- or its column -- to see all its
connections.  EXCLUDE nodes are omitted."
  (pcase-let* ((`(,all . ,edges) (hywiki-graph--induced center degree adj exclude))
               (nodes (cons center (sort (remove center (copy-sequence all)) #'string<)))
               (vnodes (vconcat nodes))
               (n (length nodes))
               (eset (make-hash-table :test 'equal)))
    (dolist (e edges)
      (puthash (cons (car e) (cdr e)) t eset)
      (puthash (cons (cdr e) (car e)) t eset))
    (hywiki-graph--insert-header center degree n (length edges) 'matrix)
    (if (= n 1)
        (insert (propertize "  (no links)\n" 'face 'shadow))
      ;; Column-index header (column j corresponds to row j's node).
      (insert (make-string 4 ?\s))
      (dotimes (j n)
        (insert (propertize (format "%2d" (1+ j))
                            'face (if (zerop j) 'hywiki-graph-center 'shadow))))
      (insert "\n")
      (dotimes (i n)
        (let ((row (aref vnodes i)))
          (insert (propertize (format "%2d " (1+ i))
                              'face (if (zerop i) 'hywiki-graph-center 'shadow))
                  (if (zerop i) (propertize "▸" 'face 'hywiki-graph-center) " "))
          (dotimes (j n)
            (insert " "
                    (cond ((= i j) (propertize "╲" 'face 'shadow))
                          ((gethash (cons row (aref vnodes j)) eset) "●")
                          (t (propertize "·" 'face 'shadow)))))
          (insert "  " (hywiki-graph--node-display row) "\n"))))))

;;;; DAG rendering (git-log style: nodes in one column, edges as side rails)

(defconst hywiki-graph--dag-glyphs
  [?\s ?│ ?│ ?│ ?─ ?╯ ?╮ ?┤ ?─ ?╰ ?╭ ?├ ?─ ?┴ ?┬ ?┼]
  "Box-drawing glyph for each 4-bit cell mask (U=1 D=2 L=4 R=8).")

(defun hywiki-graph--dfs-order (center adj nodeset)
  "Return a depth-first ordering of NODESET from CENTER over ADJ.
DFS keeps most edges short, which narrows the rail diagram."
  (let ((visited (make-hash-table :test 'equal)) (order '()))
    (cl-labels ((visit (n)
                  (unless (gethash n visited)
                    (puthash n t visited)
                    (push n order)
                    (dolist (m (sort (copy-sequence (gethash n adj)) #'string<))
                      (when (gethash m nodeset) (visit m))))))
      (visit center))
    (nreverse order)))

(defun hywiki-graph--render-dag (center degree adj exclude)
  "Render the CENTER/DEGREE neighbourhood as a git-log style rail diagram.
Every node sits on its own row in a single column; each edge is a vertical
rail in a lane to the left, joining its two nodes.  EXCLUDE nodes are
omitted."
  (pcase-let* ((`(,all . ,edges) (hywiki-graph--induced center degree adj exclude))
               (nodeset (let ((h (make-hash-table :test 'equal)))
                          (dolist (nd all) (puthash nd t h)) h))
               (nodes (hywiki-graph--dfs-order center adj nodeset))
               (n (length nodes))
               (idx (make-hash-table :test 'equal)))
    (cl-loop for nd in nodes for i from 0 do (puthash nd i idx))
    (hywiki-graph--insert-header center degree n (length edges) 'dag)
    ;; Edges as row intervals (i . j), i<j; assign each a lane by greedy
    ;; interval colouring (lowest lane whose previous edge has ended).
    ;; Longest-span edges first so they take the leftmost lanes; short edges
    ;; then land in lanes nearest the node column, minimising the crossings
    ;; their connectors make.
    (let* ((ivs (sort (delq nil
                            (mapcar (lambda (e)
                                      (let ((a (gethash (car e) idx))
                                            (b (gethash (cdr e) idx)))
                                        (when (and a b (/= a b))
                                          (cons (min a b) (max a b)))))
                                    edges))
                      (lambda (x y)
                        (let ((sx (- (cdr x) (car x))) (sy (- (cdr y) (car y))))
                          (or (> sx sy)
                              (and (= sx sy) (< (car x) (car y))))))))
           (lane-free (make-vector (max 1 (length ivs)) 0))
           (nlanes 0)
           (assign '()))
      (dolist (iv ivs)
        (let ((lane 0))
          (while (and (< lane nlanes) (> (aref lane-free lane) (car iv)))
            (setq lane (1+ lane)))
          (when (= lane nlanes) (setq nlanes (1+ nlanes)))
          (aset lane-free lane (cdr iv))
          (push (list (car iv) (cdr iv) lane) assign)))
      ;; Build a mask grid: N rows x (nlanes + 1) cols; col `nlanes' is the node.
      (let* ((ncol nlanes)
             (width (1+ nlanes))
             (grid (make-vector n nil)))
        (dotimes (r n) (aset grid r (make-vector width 0)))
        (cl-flet ((addm (r c bits)
                    (when (and (>= r 0) (< r n) (>= c 0) (< c width))
                      (aset (aref grid r) c (logior (aref (aref grid r) c) bits)))))
          (dolist (a assign)
            (let ((i (nth 0 a)) (j (nth 1 a)) (lane (nth 2 a)))
              (addm i lane 2)                                  ; rail goes down
              (cl-loop for r from (1+ i) to (1- j) do (addm r lane 3)) ; passing
              (addm j lane 1)                                  ; rail ends (up)
              (dolist (r (list i j))                           ; join to node col
                (addm r lane 8)                                ; right toward node
                (cl-loop for c from (1+ lane) to (1- ncol) do (addm r c 12))
                (addm r ncol 4)))))                            ; left into node
        (dotimes (r n)
          (let ((node (nth r nodes)))
            (dotimes (c nlanes)
              (insert (char-to-string
                       (aref hywiki-graph--dag-glyphs (aref (aref grid r) c)))))
            (insert (propertize "●" 'face (if (equal node center)
                                              'hywiki-graph-center 'hywiki-graph-node)
                                'hywiki-graph-node node 'mouse-face 'highlight)
                    " " (hywiki-graph--node-display node) "\n")))))))

;;;; Render dispatch

(defun hywiki-graph--render ()
  "Render the graph for the buffer-local centre, degree, style and pruning."
  (let* ((inhibit-read-only t)
         (center hywiki-graph--center)
         (degree hywiki-graph--degree)
         (adj (hywiki-graph--get-adjacency))
         (exclude (and hywiki-graph--prune-hubs
                       (hywiki-graph--hub-set adj hywiki-graph--hub-threshold center))))
    (erase-buffer)
    (pcase hywiki-graph--style
      ('graph  (hywiki-graph--render-graph-easy center degree adj exclude))
      ('matrix (hywiki-graph--render-matrix center degree adj exclude))
      ('dag    (hywiki-graph--render-dag center degree adj exclude))
      (_       (hywiki-graph--render-tree center degree adj exclude)))
    (goto-char (point-min))))

;;;; SVG view (force-directed, via graph-fa2)

(declare-function graph-fa2-start "graph-fa2")
(defvar graph-fa2-simulation-frames)
(defvar graph-fa2-node-clicked-functions)

(defcustom hywiki-graph-svg-buffer-name "*HyWiki Graph SVG*"
  "Buffer used for the force-directed SVG view."
  :type 'string)

(defcustom hywiki-graph-svg-frames 240
  "ForceAtlas2 simulation frames for the SVG view.
Bound to `graph-fa2-simulation-frames' while rendering.  Lower settles
faster with less background work; higher relaxes the layout further."
  :type 'integer)

(defvar-local hywiki-graph--svg-center nil
  "Centre WikiWord of an SVG buffer; non-nil marks the buffer as ours.")
(defvar-local hywiki-graph--svg-degree 1)
(defvar-local hywiki-graph--svg-prune-hubs nil)
(defvar-local hywiki-graph--svg-hub-threshold 30)

(defun hywiki-graph--graph-fa2-available-p ()
  "Return non-nil when the graph-fa2 package can be loaded."
  (and (require 'graph-fa2 nil t) (fboundp 'graph-fa2-start)))

(defun hywiki-graph--fa2-data (center degree adj exclude)
  "Return (NODES . EDGES) in graph-fa2 form for the CENTER neighbourhood.
NODES are plists (:id :label :colour :radius); EDGES are (src . tgt)."
  (pcase-let* ((`(,nodes . ,edges) (hywiki-graph--induced center degree adj exclude)))
    (cons
     (mapcar (lambda (n)
               (list :id n :label n
                     :colour (if (equal n center) "#f38ba8" "#89b4fa")
                     :radius (if (equal n center) 16.0 11.0)))
             nodes)
     (copy-sequence edges))))

(defun hywiki-graph--svg-render (center degree prune threshold)
  "Render the CENTER/DEGREE neighbourhood as a graph-fa2 SVG.
PRUNE and THRESHOLD control hub pruning.  Displays (and selects) the SVG
buffer so graph-fa2's playback, which only draws in a visible window, runs."
  (let* ((adj (hywiki-graph--get-adjacency))
         (exclude (and prune (hywiki-graph--hub-set adj threshold center)))
         (data (hywiki-graph--fa2-data center degree adj exclude))
         (buf (get-buffer-create hywiki-graph-svg-buffer-name))
         (graph-fa2-simulation-frames hywiki-graph-svg-frames))
    (with-current-buffer buf
      (setq hywiki-graph--svg-center center
            hywiki-graph--svg-degree degree
            hywiki-graph--svg-prune-hubs prune
            hywiki-graph--svg-hub-threshold threshold))
    (pop-to-buffer buf)
    (graph-fa2-start buf (car data) (cdr data))
    (message "HyWiki SVG: %s (degree %d, %d nodes)"
             center degree (length (car data)))))

(defun hywiki-graph--svg-node-clicked (node-id)
  "Recenter the SVG view on NODE-ID when it is clicked in our SVG buffer."
  (when (and (stringp node-id) hywiki-graph--svg-center)
    (hywiki-graph--svg-render node-id
                              hywiki-graph--svg-degree
                              hywiki-graph--svg-prune-hubs
                              hywiki-graph--svg-hub-threshold)))

(with-eval-after-load 'graph-fa2
  (add-hook 'graph-fa2-node-clicked-functions #'hywiki-graph--svg-node-clicked))

;;;###autoload
(defun hywiki-graph-svg ()
  "Show the current neighbourhood as a force-directed SVG via graph-fa2.
Uses the centre, degree and hub-pruning of the current `hywiki-graph-mode'
buffer, or prompts for a WikiWord.  Click a node to recentre."
  (interactive)
  (unless (hywiki-graph--graph-fa2-available-p)
    (user-error "graph-fa2 is not installed"))
  (let ((center (or hywiki-graph--center
                    (completing-read "HyWiki SVG graph for word: "
                                     (hywiki-get-page-list) nil t)))
        (degree (or (and hywiki-graph--center hywiki-graph--degree)
                    hywiki-graph-default-degree))
        (prune (if (local-variable-p 'hywiki-graph--prune-hubs)
                   hywiki-graph--prune-hubs hywiki-graph-prune-hubs))
        (threshold (if (local-variable-p 'hywiki-graph--hub-threshold)
                       hywiki-graph--hub-threshold hywiki-graph-hub-threshold)))
    (unless (member center (hywiki-get-page-list))
      (user-error "No HyWiki page for %S" center))
    (hywiki-graph--svg-render center degree prune threshold)))

;;;; Commands

(defun hywiki-graph--node-at-point ()
  "Return the WikiWord node at point, or nil."
  (or (get-text-property (point) 'hywiki-graph-node)
      (let ((w (thing-at-point 'symbol t)))
        (and (hywiki-graph--node-p w) w))))

(defun hywiki-graph-set-degree ()
  "Re-render the graph at the degree given by the pressed digit key."
  (interactive)
  (let ((d (- last-command-event ?0)))
    (when (<= 1 d 9)
      (setq hywiki-graph--degree d)
      (hywiki-graph--render)
      (message "HyWiki graph: %s, degree %d" hywiki-graph--center d))))

(defun hywiki-graph--available-styles ()
  "Return the list of selectable text rendering styles, in cycle order."
  '(graph tree matrix dag))

(defun hywiki-graph-cycle-style ()
  "Switch to the next text rendering style (graph -> tree -> matrix -> dag)."
  (interactive)
  (let* ((styles (hywiki-graph--available-styles))
         (next (or (cadr (member hywiki-graph--style styles)) (car styles))))
    (setq hywiki-graph--style next)
    (hywiki-graph--render)
    (message "HyWiki graph style: %s" next)))

(defun hywiki-graph-toggle-hubs ()
  "Toggle pruning of high-degree hub nodes from the display."
  (interactive)
  (setq hywiki-graph--prune-hubs (not hywiki-graph--prune-hubs))
  (hywiki-graph--render)
  (message "HyWiki graph: hub pruning %s%s"
           (if hywiki-graph--prune-hubs "ON" "OFF")
           (if hywiki-graph--prune-hubs
               (format " (degree > %d)" hywiki-graph--hub-threshold) "")))

(defun hywiki-graph--adjust-hub-threshold (delta)
  "Change the hub-pruning threshold by DELTA, enable pruning, and re-render."
  (setq hywiki-graph--hub-threshold (max 1 (+ hywiki-graph--hub-threshold delta))
        hywiki-graph--prune-hubs t)
  (hywiki-graph--render)
  (message "HyWiki graph: hub threshold %d (pruning ON)" hywiki-graph--hub-threshold))

(defun hywiki-graph-hub-threshold-down ()
  "Lower the hub-pruning threshold (prune more nodes)."
  (interactive)
  (hywiki-graph--adjust-hub-threshold -2))

(defun hywiki-graph-hub-threshold-up ()
  "Raise the hub-pruning threshold (prune fewer nodes)."
  (interactive)
  (hywiki-graph--adjust-hub-threshold 2))

(defun hywiki-graph-recenter ()
  "Recenter the graph on the HyWiki node at point."
  (interactive)
  (let ((node (hywiki-graph--node-at-point)))
    (if node
        (progn
          (setq hywiki-graph--center node)
          (hywiki-graph--render)
          (message "HyWiki graph centered on %s" node))
      (user-error "No HyWiki node at point"))))

(defun hywiki-graph-recenter-mouse (event)
  "Recenter on the node clicked by EVENT, if any."
  (interactive "e")
  (mouse-set-point event)
  (when (hywiki-graph--node-at-point)
    (hywiki-graph-recenter)))

(defun hywiki-graph-visit ()
  "Open the HyWiki page for the node at point."
  (interactive)
  (let ((node (hywiki-graph--node-at-point)))
    (cond ((null node) (user-error "No HyWiki node at point"))
          ((fboundp 'hywiki-find-page) (hywiki-find-page node))
          (t (find-file (expand-file-name (concat node hywiki-file-suffix)
                                          hywiki-directory))))))

(defun hywiki-graph-refresh ()
  "Rebuild the link graph from the HyWiki pages and re-render."
  (interactive)
  (hywiki-graph--get-adjacency t)
  (hywiki-graph--render)
  (message "HyWiki graph refreshed (%d pages)"
           (hash-table-count hywiki-graph--adjacency)))

(defvar hywiki-graph-mode-map (make-sparse-keymap)
  "Keymap for `hywiki-graph-mode'.")

;; Bind at top level (not inside the defvar) so reloading the file refreshes
;; the bindings on the existing keymap object instead of being skipped.
(dotimes (i 9)
  (define-key hywiki-graph-mode-map (number-to-string (1+ i))
              #'hywiki-graph-set-degree))
(define-key hywiki-graph-mode-map (kbd "v")   #'hywiki-graph-cycle-style)
(define-key hywiki-graph-mode-map (kbd "s")   #'hywiki-graph-svg)
(define-key hywiki-graph-mode-map (kbd "h")   #'hywiki-graph-toggle-hubs)
(define-key hywiki-graph-mode-map (kbd "[")   #'hywiki-graph-hub-threshold-down)
(define-key hywiki-graph-mode-map (kbd "]")   #'hywiki-graph-hub-threshold-up)
(define-key hywiki-graph-mode-map (kbd "RET") #'hywiki-graph-recenter)
(define-key hywiki-graph-mode-map (kbd "o")   #'hywiki-graph-visit)
(define-key hywiki-graph-mode-map (kbd "g")   #'hywiki-graph-refresh)
(define-key hywiki-graph-mode-map [mouse-1]   #'hywiki-graph-recenter-mouse)

(define-derived-mode hywiki-graph-mode special-mode "HyWiki-Graph"
  "Major mode for the HyWiki link-graph display."
  (setq-local truncate-lines t)
  (buffer-disable-undo))

;; Read-only display buffer whose own keymap (digits, RET, o, g, v) must win.
;; Modal editors otherwise shadow those keys -- evil's motion state rebinds
;; digits to `digit-argument' and RET to `evil-ret'.  Start in emacs state.
(with-eval-after-load 'evil
  (when (fboundp 'evil-set-initial-state)
    (evil-set-initial-state 'hywiki-graph-mode 'emacs)))

;;;###autoload
(defun hywiki-graph (wikiword &optional degree)
  "Display a plain-text graph of HyWiki links around WIKIWORD.
DEGREE is the numeric prefix argument: how many link hops out from
WIKIWORD to include (default `hywiki-graph-default-degree').  So
`C-u 3 \\[hywiki-graph]' shows three degrees of neighbours."
  (interactive
   (list (completing-read "HyWiki graph for word: "
                          (hywiki-get-page-list) nil t
                          (let ((w (and (fboundp 'hywiki-word-at)
                                        (hywiki-word-at))))
                            (and (stringp w) w)))
         (and current-prefix-arg (prefix-numeric-value current-prefix-arg))))
  (unless (member wikiword (hywiki-get-page-list))
    (user-error "No HyWiki page for %S" wikiword))
  (let ((buf (get-buffer-create hywiki-graph-buffer-name)))
    (with-current-buffer buf
      (unless (derived-mode-p 'hywiki-graph-mode)
        (hywiki-graph-mode))
      (setq hywiki-graph--center wikiword
            hywiki-graph--degree (max 1 (or degree hywiki-graph-default-degree))
            hywiki-graph--style hywiki-graph-default-style
            hywiki-graph--prune-hubs hywiki-graph-prune-hubs
            hywiki-graph--hub-threshold hywiki-graph-hub-threshold)
      (hywiki-graph--render))
    (pop-to-buffer buf)))

(provide 'hywiki-graph)
;;; hywiki-graph.el ends here
