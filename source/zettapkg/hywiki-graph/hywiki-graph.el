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
;; Logseq's local graph.  WikiWords are nodes; a directed edge A -> B exists
;; when page A's text mentions B.
;;
;; `hywiki-graph' prompts for a WikiWord (with completion) and renders the
;; neighbourhood around it.  The numeric prefix argument sets how many link
;; hops ("degrees") out to include -- `C-u 3 M-x hywiki-graph' shows three
;; degrees; the default is one.
;;
;; The neighbourhood is drawn as a git-log style rail diagram (the `dag'
;; view): every node on its own row, its label indented one level per hop
;; from the centre, and each edge a vertical rail in a colour-coded lane.
;; An arrowhead marks the page each link points to (`<'/`>' where a rail
;; turns into a node, `^'/`v' where it rides a lane past a crossing).  It is
;; drawn entirely in Emacs Lisp -- no external programs.
;;
;; Densely-connected "index" hubs (a page linked from nearly everywhere)
;; explode a neighbourhood.  `hywiki-graph-prune-hubs' (default on) drops
;; nodes whose global degree exceeds `hywiki-graph-hub-threshold', keeping
;; the neighbourhood local; toggle and tune it live with `h' / `[' / `]'.
;;
;; In the display buffer:
;;   1-9  re-render at that many degrees from the current centre
;;   h    toggle hub pruning on/off
;;   [ ]  lower / raise the hub-degree threshold (also enables pruning)
;;   r    toggle inclusion of HyRolo-sourced nodes
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
(require 'ansi-color)
(require 'hywiki)

(declare-function hywiki-get-page-list "hywiki")
(declare-function hywiki-get-singular-wikiword "hywiki")
(declare-function hywiki-find-page "hywiki")
(declare-function hywiki-word-at "hywiki")
(declare-function hyrolo-get-file-list "hyrolo")
(defvar hywiki-word-regexp)
(defvar hywiki-allow-plurals-flag)
(defvar hywiki-directory)
(defvar hywiki-file-suffix)
(defvar hyrolo-file-list)

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

(defcustom hywiki-graph-include-rolo nil
  "When non-nil, include HyRolo files that reference WikiWords as nodes.
Each readable file in `hyrolo-file-list' becomes a (non-WikiWord) node
linked to every WikiWord its text mentions -- a second class of nodes with
the same mention relationship.  Toggle live with
\\<hywiki-graph-mode-map>\\[hywiki-graph-toggle-rolo]."
  :type 'boolean)

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
  "Face for dimmed (horizontal) rail segments in the dag view.")

(defface hywiki-graph-rolo-node
  '((t :inherit font-lock-string-face :slant italic))
  "Face for HyRolo-sourced (non-WikiWord) nodes.")

(defcustom hywiki-graph-dag-lane-colors
  '("#89b4fa" "#a6e3a1" "#f9e2af" "#fab387" "#cba6f7" "#94e2d5" "#f38ba8" "#74c7ec")
  "Foreground colours cycled across lanes in the `dag' view.
Each vertical rail is coloured by its lane so crossing rails stay
distinguishable."
  :type '(repeat color))

(defcustom hywiki-graph-dag-indent 2
  "Spaces of node-name indentation per hop from the centre in the `dag' view.
Each node's label is shifted right by this many spaces times its distance
from the centre, so the centre sits flush, its direct links indent one level,
theirs two, and so on -- turning the rail diagram into a depth outline.  The
rails themselves are unchanged.  Set to 0 to align every label as before."
  :type 'natnum)

(defcustom hywiki-graph-dag-labels-left t
  "When non-nil, the `dag' view puts node labels on the left, rails on the right.
Every label then sits near the left margin -- always readable -- with the edge
rails extending rightward, so a node with very many edges spills its rails off
the right rather than shoving its name off the page.  Set to nil for the
classic git-log arrangement: rails on the left, labels on the right."
  :type 'boolean)

(defcustom hywiki-graph-dag-arrows t
  "When non-nil, the `dag' view marks each edge's target end with an arrowhead.
HyWiki links are directed: if page A's file mentions B, the edge points A->B,
and the corner where the rail meets B carries an arrowhead (mutual links get
one at each end).  To keep crossings legible, an arrowhead is drawn only where
the target corner is clean; at busy hubs, a corner shared with another edge's
crossing rail keeps its plain box-drawing glyph.  Set to nil for undecorated
rails."
  :type 'boolean)

;;;; Graph construction

(defvar hywiki-graph--adjacency nil
  "Cached adjacency hash: WikiWord -> list of neighbour WikiWords.
Undirected; rebuilt by `hywiki-graph--get-adjacency' with FORCE non-nil.")

;;;; Per-buffer display state

(defvar-local hywiki-graph--center nil
  "WikiWord at the centre of the currently displayed graph.")
(defvar-local hywiki-graph--degree 1
  "Number of link hops currently displayed.")
(defvar-local hywiki-graph--prune-hubs nil
  "Whether high-degree hub nodes are pruned from the current display.")
(defvar-local hywiki-graph--hub-threshold 30
  "Degree above which a node is pruned as a hub in the current display.")
(defvar-local hywiki-graph--include-rolo nil
  "Whether the current display includes HyRolo-sourced nodes.")

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

(defvar hywiki-graph--dir-adjacency nil
  "Cached DIRECTED-link hash: page A -> list of pages A's file links to.
Rebuilt together with `hywiki-graph--adjacency'.  Used only to orient the
`dag' view's arrows; the undirected adjacency drives layout and BFS.")

(defun hywiki-graph--build-adjacency ()
  "Scan every HyWiki page and return an undirected adjacency hash.
Also refresh `hywiki-graph--dir-adjacency' with the directed (A links to B)
links found while scanning."
  (let ((pageset (hywiki-graph--page-set))
        (adj (make-hash-table :test 'equal))
        (dir (make-hash-table :test 'equal))
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
            (cl-pushnew w (gethash nbr adj) :test #'equal)
            (cl-pushnew nbr (gethash w dir) :test #'equal)))))  ; w -> nbr
    (setq hywiki-graph--dir-adjacency dir)
    adj))

(defun hywiki-graph--links-to-p (a b)
  "Return non-nil when page A directly links to page B (A's file mentions B)."
  (and hywiki-graph--dir-adjacency
       (and (member b (gethash a hywiki-graph--dir-adjacency)) t)))

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

;;;; Optional HyRolo-sourced nodes

(defvar hywiki-graph--rolo-adjacency nil
  "Cached hash of HyRolo edges: rolo-node / WikiWord -> neighbours.")
(defvar hywiki-graph--rolo-nodes nil
  "Hash set of the HyRolo-sourced node names in the rolo adjacency.")

(defun hywiki-graph--rolo-files ()
  "Return the expanded list of HyRolo files from `hyrolo-file-list'.
Directory entries expand to their text files; wildcard entries expand to
their matches; plain file entries pass through."
  (when (and (boundp 'hyrolo-file-list) hyrolo-file-list)
    (let ((suffix-re "\\.\\(org\\|otl\\|md\\|markdown\\|kotl\\)\\'")
          files)
      (dolist (entry (if (listp hyrolo-file-list)
                         hyrolo-file-list
                       (list hyrolo-file-list)))
        (let ((ep (expand-file-name entry)))
          (cond
           ((file-directory-p ep)
            (setq files (nconc files (directory-files ep t suffix-re))))
           ((string-match-p "[*?]" ep)
            (setq files (nconc files (file-expand-wildcards ep t))))
           ((file-readable-p ep) (push ep files)))))
      (delete-dups files))))

(defun hywiki-graph--build-rolo-adjacency ()
  "Scan HyRolo files for WikiWord mentions; return the rolo adjacency hash.
Each file becomes a node (its base name) linked to the WikiWords it
mentions.  Populates `hywiki-graph--rolo-nodes'."
  (let ((pageset (hywiki-graph--page-set))
        (adj (make-hash-table :test 'equal))
        (nodes (make-hash-table :test 'equal)))
    (dolist (file (hywiki-graph--rolo-files))
      (when (and (stringp file) (file-readable-p file))
        (let ((name (file-name-base file)))
          ;; Skip files whose name already is a WikiWord (avoids node collision).
          (unless (gethash name pageset)
            (let ((links (hywiki-graph--links-in-file file pageset name)))
              (when links
                (puthash name t nodes)
                (dolist (w links)
                  (cl-pushnew w (gethash name adj) :test #'equal)
                  (cl-pushnew name (gethash w adj) :test #'equal))))))))
    (setq hywiki-graph--rolo-nodes nodes)
    adj))

(defun hywiki-graph--get-rolo-adjacency (&optional force)
  "Return the cached HyRolo adjacency, building it when FORCE or empty."
  (when (or force (null hywiki-graph--rolo-adjacency))
    (message "HyWiki graph: scanning HyRolo files for WikiWord references...")
    (setq hywiki-graph--rolo-adjacency (hywiki-graph--build-rolo-adjacency)))
  hywiki-graph--rolo-adjacency)

(defun hywiki-graph--rolo-node-p (name)
  "Return non-nil if NAME is a HyRolo-sourced node."
  (and hywiki-graph--rolo-nodes (gethash name hywiki-graph--rolo-nodes)))

(defun hywiki-graph--effective-adjacency ()
  "Return the adjacency for the current display.
With `hywiki-graph--include-rolo' non-nil, merge the WikiWord adjacency
with the HyRolo-sourced edges; otherwise return the WikiWord adjacency."
  (if (not hywiki-graph--include-rolo)
      (hywiki-graph--get-adjacency)
    (let ((combined (make-hash-table :test 'equal)))
      (maphash (lambda (k v) (puthash k (copy-sequence v) combined))
               (hywiki-graph--get-adjacency))
      (maphash (lambda (k v)
                 (puthash k (cl-union (gethash k combined) v :test #'equal) combined))
               (hywiki-graph--get-rolo-adjacency))
      combined)))

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

(defun hywiki-graph--insert-header (center degree nodes edges)
  "Insert the buffer header lines for CENTER, DEGREE, NODES and EDGES."
  (insert
   (propertize (format "HyWiki graph: %s\n" center) 'face 'hywiki-graph-center)
   (propertize
    (format "dag · degree %d · %d node%s · %d edge%s · %s%s\n"
            degree
            nodes (if (= nodes 1) "" "s")
            edges (if (= edges 1) "" "s")
            (if hywiki-graph--prune-hubs
                (format "hubs>%d pruned" hywiki-graph--hub-threshold)
              "hubs shown")
            (if hywiki-graph--include-rolo " · +rolo" ""))
    'face 'shadow)
   (propertize
    "[1-9] degree · h hubs · [ ] threshold · r rolo · RET recenter · o open · g refresh · q quit\n\n"
    'face 'shadow)))

;;;; Node display

(defun hywiki-graph--node-face (node)
  "Return the display face for NODE (centre, HyRolo node, or WikiWord)."
  (cond ((equal node hywiki-graph--center) 'hywiki-graph-center)
        ((hywiki-graph--rolo-node-p node) 'hywiki-graph-rolo-node)
        (t 'hywiki-graph-node)))

(defun hywiki-graph--node-display (node)
  "Return NODE as a propertized, clickable string."
  (propertize node
              'face (hywiki-graph--node-face node)
              'hywiki-graph-node node
              'mouse-face 'highlight
              'help-echo "RET/mouse-1: recenter   o: open page"))

;;;; DAG rendering (git-log style: nodes in one column, edges as side rails)

(defconst hywiki-graph--dag-glyphs
  [?\s ?│ ?│ ?│ ?─ ?╯ ?╮ ?┤ ?─ ?╰ ?╭ ?├ ?─ ?┴ ?┬ ?┼]
  "Box-drawing glyph for each 4-bit cell mask (U=1 D=2 L=4 R=8).")

(defun hywiki-graph--dag-cell (m c palette np mirror &optional arrow)
  "Return the propertized rail glyph for mask M drawn in lane C.
With MIRROR non-nil, swap the left/right bits so the cell reads correctly when
the lanes are drawn to the right of the node column instead of the left.
Vertical rails are coloured by lane C (from PALETTE of length NP); pure
horizontals are dimmed.

ARROW, when non-nil, is a pre-resolved arrowhead directive placed upstream
only on a clean cell (so drawing it never breaks a crossing): `node' turns
horizontally into the node column -- ASCII `<'/`>' by side, keeping the rails
monospace-aligned where the Unicode arrow glyphs would not -- while `up'/`down'
ride a vertical rail toward a target whose own corner was crossed."
  (let* ((mask (if mirror
                   (logior (logand m 3)           ; keep up/down
                           (ash (logand m 4) 1)   ; left (4) -> right (8)
                           (ash (logand m 8) -1)) ; right (8) -> left (4)
                 m))
         (glyph (cond
                 ((eq arrow 'node) (if mirror "<" ">"))
                 ((eq arrow 'up)   "^")
                 ((eq arrow 'down) "v")
                 (t (char-to-string (aref hywiki-graph--dag-glyphs mask))))))
    (cond ((zerop mask) glyph)
          ((/= 0 (logand mask 3))
           (propertize glyph 'face (list :foreground (nth (mod c np) palette))))
          (t (propertize glyph 'face 'hywiki-graph-edge)))))

(defun hywiki-graph--dag-place-arrow (arrows grid i j lane end)
  "Mark an arrowhead in the ARROWS grid for the edge in LANE from row I to J.
END is `upper' (target is the node at row I) or `lower' (row J).  Prefer the
target's own corner -- a clean ╭ (mask 10) up top or ╰ (mask 9) at the bottom,
drawn as a `node' arrow turning into the node column.  When that corner has
been crossed by another edge, ride the nearest clean vertical rail cell (mask 3
= │) toward the target instead, marking `up'/`down'.  GRID holds the finished
pre-mirror masks; only clean cells are ever marked, so no crossing is broken."
  (if (eq end 'upper)
      (cond ((= (aref (aref grid i) lane) 10)
             (aset (aref arrows i) lane 'node))
            (t (cl-loop for r from (1+ i) to (1- j)
                        when (= (aref (aref grid r) lane) 3)
                        return (aset (aref arrows r) lane 'up))))
    (cond ((= (aref (aref grid j) lane) 9)
           (aset (aref arrows j) lane 'node))
          (t (cl-loop for r from (1- j) downto (1+ i)
                      when (= (aref (aref grid r) lane) 3)
                      return (aset (aref arrows r) lane 'down))))))

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
Every node sits on its own row; each edge is a vertical rail in its own lane,
joining its two nodes.  Labels are indented one level per hop from the centre
\(`hywiki-graph-dag-indent').  By default (`hywiki-graph-dag-labels-left') the
labels are on the left and the rails on the right, so a node with very many
edges spills its rails off the page rather than its name; set that option to
nil for the classic rails-left arrangement.  EXCLUDE nodes are omitted."
  (pcase-let* ((`(,all . ,edges) (hywiki-graph--induced center degree adj exclude))
               (nodeset (let ((h (make-hash-table :test 'equal)))
                          (dolist (nd all) (puthash nd t h)) h))
               (nodes (hywiki-graph--dfs-order center adj nodeset))
               (dist (plist-get (hywiki-graph--bfs center adj degree exclude) :dist))
               (n (length nodes))
               (idx (make-hash-table :test 'equal)))
    (cl-loop for nd in nodes for i from 0 do (puthash nd i idx))
    (hywiki-graph--insert-header center degree n (length edges))
    ;; Edges as row intervals (i . j), i<j; assign each a lane by greedy
    ;; interval colouring (lowest lane whose previous edge ended STRICTLY
    ;; above this one's start).  The strict gap matters: two edges that merely
    ;; touch at a shared node row -- e.g. A-B ending where B-C begins -- must
    ;; not share a lane, or they merge into one continuous rail that reads as a
    ;; direct A-C link.  Longest-span edges first so they take the leftmost
    ;; lanes; short edges then land in lanes nearest the node column,
    ;; minimising the crossings their connectors make.
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
          (while (and (< lane nlanes) (>= (aref lane-free lane) (car iv)))
            (setq lane (1+ lane)))
          (when (= lane nlanes) (setq nlanes (1+ nlanes)))
          (aset lane-free lane (cdr iv))
          (push (list (car iv) (cdr iv) lane) assign)))
      ;; Build a mask grid: N rows x (nlanes + 1) cols; col `nlanes' is the node.
      ;; `arrows' is a parallel grid of arrowhead directives (see the arrow pass
      ;; below and `hywiki-graph--dag-place-arrow') so directed links show which
      ;; page each edge points to.
      (let* ((ncol nlanes)
             (width (1+ nlanes))
             (grid (make-vector n nil))
             (arrows (make-vector n nil))
             (node-vec (vconcat nodes))
             (arrows-on hywiki-graph-dag-arrows))
        (dotimes (r n)
          (aset grid r (make-vector width 0))
          (aset arrows r (make-vector width nil)))
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
                (addm r ncol 4))))                             ; left into node
          ;; Arrow pass: with every rail and crossing now in the grid, mark each
          ;; directed edge's target end.  Upper node i is a target when lower
          ;; node j links up to it; lower node j when upper node i links down.
          ;; Mutual links get an arrowhead at each end.
          (when arrows-on
            (dolist (a assign)
              (let* ((i (nth 0 a)) (j (nth 1 a)) (lane (nth 2 a))
                     (ni (aref node-vec i)) (nj (aref node-vec j)))
                (when (hywiki-graph--links-to-p nj ni)
                  (hywiki-graph--dag-place-arrow arrows grid i j lane 'upper))
                (when (hywiki-graph--links-to-p ni nj)
                  (hywiki-graph--dag-place-arrow arrows grid i j lane 'lower))))))
        (let* ((palette hywiki-graph-dag-lane-colors)
               (np (length palette))
               (labels-left hywiki-graph-dag-labels-left)
               ;; Label = one indent level per hop from the centre + node name,
               ;; so the diagram doubles as a depth outline.
               (label-of (lambda (node)
                           (concat (make-string (* hywiki-graph-dag-indent
                                                   (or (gethash node dist) 0))
                                                ?\s)
                                   (hywiki-graph--node-display node))))
               (bullet-of (lambda (node)
                            (propertize "●" 'face (if (equal node center)
                                                      'hywiki-graph-center
                                                    'hywiki-graph-node)
                                        'hywiki-graph-node node 'mouse-face 'highlight)))
               ;; When labels are on the left, pad them to a common width so the
               ;; bullets -- and thus every rail -- still line up in a column.
               (label-width (and labels-left
                                 (cl-loop for node in nodes
                                          maximize (string-width
                                                    (funcall label-of node))))))
          (dotimes (r n)
            (let* ((node (nth r nodes))
                   (row (aref grid r))
                   (arow (aref arrows r)))
              (if labels-left
                  ;; label · bullet · rails (drawn right-to-left, mirrored).
                  (let* ((label (funcall label-of node))
                         (pad (max 0 (- label-width (string-width label)))))
                    (insert label (make-string pad ?\s) " " (funcall bullet-of node))
                    (cl-loop for c from (1- nlanes) downto 0 do
                             (insert (hywiki-graph--dag-cell (aref row c) c
                                                             palette np t
                                                             (aref arow c))))
                    (insert "\n"))
                ;; Classic git-log: rails (left-to-right) · bullet · label.
                (dotimes (c nlanes)
                  (insert (hywiki-graph--dag-cell (aref row c) c palette np nil
                                                  (aref arow c))))
                (insert (funcall bullet-of node) " " (funcall label-of node)
                        "\n")))))))))

;;;; Render dispatch

(defun hywiki-graph--render ()
  "Render the graph for the buffer-local centre, degree and hub pruning."
  (let* ((inhibit-read-only t)
         (center hywiki-graph--center)
         (degree hywiki-graph--degree)
         (adj (hywiki-graph--effective-adjacency))
         (exclude (and hywiki-graph--prune-hubs
                       (hywiki-graph--hub-set adj hywiki-graph--hub-threshold center))))
    (erase-buffer)
    (hywiki-graph--render-dag center degree adj exclude)
    (goto-char (point-min))))

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

(defun hywiki-graph-toggle-rolo ()
  "Toggle inclusion of HyRolo-sourced nodes."
  (interactive)
  (setq hywiki-graph--include-rolo (not hywiki-graph--include-rolo))
  (when hywiki-graph--include-rolo (hywiki-graph--get-rolo-adjacency))
  (hywiki-graph--render)
  (message "HyWiki graph: HyRolo nodes %s%s"
           (if hywiki-graph--include-rolo "ON" "OFF")
           (if hywiki-graph--include-rolo
               (format " (%d rolo nodes)" (hash-table-count hywiki-graph--rolo-nodes))
             "")))

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
          ((hywiki-graph--rolo-node-p node)
           (user-error "%S is a HyRolo node, not a WikiWord page" node))
          ((fboundp 'hywiki-find-page) (hywiki-find-page node))
          (t (find-file (expand-file-name (concat node hywiki-file-suffix)
                                          hywiki-directory))))))

(defun hywiki-graph-refresh ()
  "Rebuild the link graph from the HyWiki pages and re-render.
Also rebuilds the HyRolo adjacency when rolo nodes are included."
  (interactive)
  (hywiki-graph--get-adjacency t)
  (when hywiki-graph--include-rolo (hywiki-graph--get-rolo-adjacency t))
  (hywiki-graph--render)
  (message "HyWiki graph refreshed (%d pages%s)"
           (hash-table-count hywiki-graph--adjacency)
           (if hywiki-graph--include-rolo
               (format ", %d rolo nodes" (hash-table-count hywiki-graph--rolo-nodes))
             "")))

(defvar hywiki-graph-mode-map (make-sparse-keymap)
  "Keymap for `hywiki-graph-mode'.")

;; Bind at top level (not inside the defvar) so reloading the file refreshes
;; the bindings on the existing keymap object instead of being skipped.
(dotimes (i 9)
  (define-key hywiki-graph-mode-map (number-to-string (1+ i))
              #'hywiki-graph-set-degree))
(define-key hywiki-graph-mode-map (kbd "h")   #'hywiki-graph-toggle-hubs)
(define-key hywiki-graph-mode-map (kbd "r")   #'hywiki-graph-toggle-rolo)
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

;; Read-only display buffer whose own keymap (digits, RET, o, g) must win.
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
            hywiki-graph--prune-hubs hywiki-graph-prune-hubs
            hywiki-graph--hub-threshold hywiki-graph-hub-threshold
            hywiki-graph--include-rolo hywiki-graph-include-rolo)
      (hywiki-graph--render))
    (pop-to-buffer buf)))

(provide 'hywiki-graph)
;;; hywiki-graph.el ends here
