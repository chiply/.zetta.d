;;; hywiki-graph.el --- Text graph view of HyWiki word links -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; URL: https://github.com/<TBD>/hywiki-graph
;; Version: 0.2.0
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
;; Two rendering styles (toggle with `v'):
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
;; To get the `graph' style, install graph-easy once, e.g. with a user-local
;; Perl lib (no sudo):
;;
;;   brew install cpanminus
;;   cpanm --local-lib=~/perl5 Graph::Easy
;;
;; then ensure `hywiki-graph-graph-easy-program' / `-lib' point at it
;; (the defaults probe ~/perl5 and the PATH).
;;
;; In the display buffer:
;;   1-9  re-render at that many degrees from the current centre
;;   v    toggle between the graph and tree styles
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

(defun hywiki-graph--bfs (center adj degree)
  "Breadth-first search from CENTER over ADJ up to DEGREE hops.
Return a plist (:dist HASH :parent HASH :order LIST) covering the nodes
within DEGREE of CENTER, in first-visit order."
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
            (unless (gethash nbr dist)
              (puthash nbr (1+ d) dist)
              (puthash nbr node parent)
              (push nbr order)
              (setq queue (nconc queue (list nbr))))))))
    (list :dist dist :parent parent :order (nreverse order))))

(defun hywiki-graph--induced (center degree adj)
  "Return (NODES . EDGES) for the CENTER neighbourhood within DEGREE over ADJ.
NODES is sorted; EDGES is a list of (A . B) cons cells with A string< B."
  (let* ((bfs (hywiki-graph--bfs center adj degree))
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
  "Insert the buffer header line(s) for CENTER, DEGREE, NODES, EDGES, STYLE."
  (insert (propertize (format "HyWiki graph: %s\n" center) 'face 'hywiki-graph-center)
          (propertize
           (format "%s · degree %d · %d node%s · %d edge%s   [1-9] degree · v style · RET recenter · o open · g refresh · q quit\n\n"
                   style degree
                   nodes (if (= nodes 1) "" "s")
                   edges (if (= edges 1) "" "s"))
           'face 'shadow)))

;;;; Tree rendering

;; Dynamic state bound for the duration of a single tree render.
(defvar hywiki-graph--r-children nil)
(defvar hywiki-graph--r-parent nil)
(defvar hywiki-graph--r-idx nil)
(defvar hywiki-graph--r-adj nil)

(defvar-local hywiki-graph--center nil
  "WikiWord at the centre of the currently displayed graph.")
(defvar-local hywiki-graph--degree 1
  "Number of link hops currently displayed.")
(defvar-local hywiki-graph--style 'graph
  "Current rendering style, `graph' or `tree'.")

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

(defun hywiki-graph--render-tree (center degree adj &optional note)
  "Render the tree view for CENTER/DEGREE over ADJ.
Optional NOTE is an extra shadow line inserted under the header."
  (let* ((bfs (hywiki-graph--bfs center adj degree))
         (dist (plist-get bfs :dist))
         (parent (plist-get bfs :parent))
         (order (plist-get bfs :order))
         (idx (make-hash-table :test 'equal))
         (children (make-hash-table :test 'equal))
         (edges (cdr (hywiki-graph--induced center degree adj))))
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

(defun hywiki-graph--render-graph-easy (center degree adj)
  "Render CENTER/DEGREE over ADJ as a graph-easy diagram.
Fall back to the tree view when graph-easy is unavailable, the
neighbourhood exceeds `hywiki-graph-graph-easy-max-edges', or the program
fails."
  (pcase-let* ((`(,nodes . ,edges) (hywiki-graph--induced center degree adj))
               (n-edges (length edges)))
    (cond
     ((not (hywiki-graph--graph-easy-available-p))
      (hywiki-graph--render-tree
       center degree adj
       "graph-easy not found — showing tree (see hywiki-graph-graph-easy-program)"))
     ((> n-edges hywiki-graph-graph-easy-max-edges)
      (hywiki-graph--render-tree
       center degree adj
       (format "%d edges > hywiki-graph-graph-easy-max-edges (%d) — showing tree (try a lower degree)"
               n-edges hywiki-graph-graph-easy-max-edges)))
     (t
      (let ((out (hywiki-graph--run-graph-easy
                  (hywiki-graph--dot center nodes edges))))
        (if (null out)
            (hywiki-graph--render-tree
             center degree adj "graph-easy failed — showing tree")
          (hywiki-graph--insert-header center degree (length nodes) n-edges 'graph)
          (let ((start (point)))
            (insert out "\n")
            (save-restriction
              (narrow-to-region start (point))
              (hywiki-graph--fontify-nodes nodes)))))))))

;;;; Render dispatch

(defun hywiki-graph--render ()
  "Render the graph for the buffer-local centre, degree and style."
  (let ((inhibit-read-only t)
        (center hywiki-graph--center)
        (degree hywiki-graph--degree)
        (adj (hywiki-graph--get-adjacency)))
    (erase-buffer)
    (if (eq hywiki-graph--style 'graph)
        (hywiki-graph--render-graph-easy center degree adj)
      (hywiki-graph--render-tree center degree adj))
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

(defun hywiki-graph-toggle-style ()
  "Toggle between the graph (graph-easy) and tree rendering styles."
  (interactive)
  (setq hywiki-graph--style (if (eq hywiki-graph--style 'graph) 'tree 'graph))
  (hywiki-graph--render)
  (message "HyWiki graph style: %s" hywiki-graph--style))

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

(defvar hywiki-graph-mode-map
  (let ((map (make-sparse-keymap)))
    (dotimes (i 9)
      (define-key map (number-to-string (1+ i)) #'hywiki-graph-set-degree))
    (define-key map (kbd "v")   #'hywiki-graph-toggle-style)
    (define-key map (kbd "RET") #'hywiki-graph-recenter)
    (define-key map (kbd "o")   #'hywiki-graph-visit)
    (define-key map (kbd "g")   #'hywiki-graph-refresh)
    (define-key map [mouse-1]   #'hywiki-graph-recenter-mouse)
    map)
  "Keymap for `hywiki-graph-mode'.")

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
            hywiki-graph--style hywiki-graph-default-style)
      (hywiki-graph--render))
    (pop-to-buffer buf)))

(provide 'hywiki-graph)
;;; hywiki-graph.el ends here
