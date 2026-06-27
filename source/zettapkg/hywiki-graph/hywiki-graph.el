;;; hywiki-graph.el --- Text graph view of HyWiki word links -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; URL: https://github.com/<TBD>/hywiki-graph
;; Version: 0.1.0
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
;; The neighbourhood is drawn as a breadth-first spanning tree (indentation =
;; distance from the centre) plus the remaining edges shown inline as
;; `╌╌ Other' cross-links -- i.e. a tree costs zero syntax and you pay only
;; for the graph's independent cycles.
;;
;; In the display buffer:
;;   1-9  re-render at that many degrees from the current centre
;;   RET  recentre the graph on the node at point
;;   o    open the WikiWord page at point
;;   g    rebuild the link graph from disk and re-render
;;   q    quit
;;
;; The link graph is scanned once and cached; press `g' after editing pages.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'hywiki)

(declare-function hywiki-get-page-list "hywiki")
(declare-function hywiki-get-page-file "hywiki")
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

;;;; Rendering

;; Dynamic state bound for the duration of a single render pass.
(defvar hywiki-graph--r-children nil)
(defvar hywiki-graph--r-parent nil)
(defvar hywiki-graph--r-idx nil)
(defvar hywiki-graph--r-adj nil)

(defvar-local hywiki-graph--center nil
  "WikiWord at the centre of the currently displayed graph.")
(defvar-local hywiki-graph--degree 1
  "Number of link hops currently displayed.")

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
NODE's tree parent -- i.e. every non-tree edge, shown exactly once on its
later endpoint."
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

(defun hywiki-graph--render ()
  "Render the graph for the buffer-local centre and degree."
  (let* ((inhibit-read-only t)
         (center hywiki-graph--center)
         (degree hywiki-graph--degree)
         (adj (hywiki-graph--get-adjacency))
         (bfs (hywiki-graph--bfs center adj degree))
         (dist (plist-get bfs :dist))
         (parent (plist-get bfs :parent))
         (order (plist-get bfs :order))
         (idx (make-hash-table :test 'equal))
         (children (make-hash-table :test 'equal))
         (count (hash-table-count dist)))
    (cl-loop for n in order for i from 0 do (puthash n i idx))
    (maphash (lambda (n p) (push n (gethash p children))) parent)
    (maphash (lambda (p kids) (puthash p (sort kids #'string<) children)) children)
    (erase-buffer)
    (insert (propertize (format "HyWiki graph: %s\n" center) 'face 'hywiki-graph-center)
            (propertize
             (format "degree %d · %d node%s   [1-9] degree · RET recenter · o open · g refresh · q quit\n\n"
                     degree count (if (= count 1) "" "s"))
             'face 'shadow))
    (let ((hywiki-graph--r-children children)
          (hywiki-graph--r-parent parent)
          (hywiki-graph--r-idx idx)
          (hywiki-graph--r-adj adj))
      (hywiki-graph--print-tree center "" t t))
    (goto-char (point-min))))

;;;; Commands

(defun hywiki-graph-set-degree ()
  "Re-render the graph at the degree given by the pressed digit key."
  (interactive)
  (let ((d (- last-command-event ?0)))
    (when (<= 1 d 9)
      (setq hywiki-graph--degree d)
      (hywiki-graph--render)
      (message "HyWiki graph: %s, degree %d" hywiki-graph--center d))))

(defun hywiki-graph-recenter ()
  "Recenter the graph on the HyWiki node at point."
  (interactive)
  (let ((node (get-text-property (point) 'hywiki-graph-node)))
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
  (when (get-text-property (point) 'hywiki-graph-node)
    (hywiki-graph-recenter)))

(defun hywiki-graph-visit ()
  "Open the HyWiki page for the node at point."
  (interactive)
  (let ((node (get-text-property (point) 'hywiki-graph-node)))
    (cond ((null node) (user-error "No HyWiki node at point"))
          ((fboundp 'hywiki-find-page) (hywiki-find-page node))
          (t (find-file (hywiki-get-page-file node))))))

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

;; This is a read-only display buffer whose own keymap (digits, RET, o, g)
;; must win.  Modal editors otherwise shadow those keys -- evil's motion
;; state rebinds digits to `digit-argument' and RET to `evil-ret'.  Start the
;; buffer in a pass-through state for whichever modal system is present.
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
            hywiki-graph--degree (max 1 (or degree hywiki-graph-default-degree)))
      (hywiki-graph--render))
    (pop-to-buffer buf)))

(provide 'hywiki-graph)
;;; hywiki-graph.el ends here
