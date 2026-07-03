;;; hywiki-alias.el --- Derived case/space aliases for HyWikiWords -*- lexical-binding: t; -*-

;; Highlight and activate case- and space-variants of existing HyWikiWords
;; without typing any aliases.  A HyWikiWord like `DataModelTesting' is split at
;; its CamelCase boundaries (Data | Model | Testing); the mode then highlights
;; any case-insensitive occurrence with optional single spaces at those
;; boundaries -- "Data Model Testing", "data model testing", "DaTa moDel
;; TESTING" -- and the Action Key (M-RET) on such a phrase jumps to the
;; `DataModelTesting' page, exactly as on the real WikiWord.  The alias set is
;; derived from your live HyWiki pages, so there is nothing to maintain.
;;
;; This is an EDITING-TIME convenience only: highlighting + Action-Key jump.
;; It does NOT feed HyWiki's data model, so backlinks, publishing, the
;; hywiki-graph, cross-file grep and completion do not see these aliases.  See
;; hywiki-alias.README.md for the full list and the rationale.
;;
;; Implementation is a thin, reversible layer over HyWiki: two pieces of advice
;; plus its own overlay pass.  Disabling the mode removes both and all overlays.
;; Off by default -- `M-x zetta-hywiki-alias-mode' to toggle.

(require 'cl-lib)

(declare-function hywiki-get-wikiword-list "hywiki")
(declare-function hywiki-active-in-current-buffer-p "hywiki")
(declare-function hywiki-word-at "hywiki")
(declare-function hywiki-maybe-highlight-references "hywiki")
(declare-function hywiki-add-referent "hywiki")
(declare-function hywiki-add-page "hywiki")
(defvar hywiki-word-face)
(defvar zetta-hywiki-alias-mode)

(defgroup zetta-hywiki-alias nil
  "Derived case/space aliases for HyWikiWords."
  :group 'hyperbole-hywiki)

(defcustom zetta-hywiki-alias-min-length 5
  "Only HyWikiWords at least this many characters get a derived alias."
  :type 'integer :group 'zetta-hywiki-alias)

(defcustom zetta-hywiki-alias-min-segments 2
  "Minimum CamelCase segments a HyWikiWord needs to get a derived alias.
The default, 2, skips single-word pages like `Emacs' -- matching those
case-insensitively would light up ordinary prose.  Set to 1 to include them."
  :type 'integer :group 'zetta-hywiki-alias)

(defcustom zetta-hywiki-alias-deny-list nil
  "HyWikiWords that should never get a derived alias (e.g. common phrases)."
  :type '(repeat string) :group 'zetta-hywiki-alias)

(defvar zetta-hywiki-alias--index nil
  "Hash mapping a downcased, space-stripped alias form to its canonical WikiWord.")
(defvar zetta-hywiki-alias--regexp nil
  "Cached alternation regexp matching every derived alias form.")
(defvar zetta-hywiki-alias--generation 0
  "Counter bumped whenever the alias set changes.
Part of the `post-command' refresh-guard key, so adding a HyWikiWord forces
the next command to re-scan even when buffer text and scroll are unchanged.")

(defun zetta-hywiki-alias--segments (word)
  "Split WORD at CamelCase boundaries into a list of segments.
Handles acronym runs, so \"HTMLParser\" -> (\"HTML\" \"Parser\")."
  (let* ((case-fold-search nil)
         (s (replace-regexp-in-string
             "\\([[:upper:]]\\)\\([[:upper:]][[:lower:]]\\)" "\\1\0\\2" word))
         (s (replace-regexp-in-string
             "\\([[:lower:][:digit:]]\\)\\([[:upper:]]\\)" "\\1\0\\2" s)))
    (split-string s "\0" t)))

(defun zetta-hywiki-alias--rebuild ()
  "Rebuild the alias index and matching regexp from existing HyWikiWords."
  (let ((index (make-hash-table :test 'equal))
        (patterns nil))
    (dolist (word (and (fboundp 'hywiki-get-wikiword-list)
                       (hywiki-get-wikiword-list)))
      (when (stringp word)
        (let ((segs (zetta-hywiki-alias--segments word)))
          (when (and (>= (length segs) zetta-hywiki-alias-min-segments)
                     (>= (length word) zetta-hywiki-alias-min-length)
                     (not (member word zetta-hywiki-alias-deny-list)))
            (puthash (downcase (apply #'concat segs)) word index)
            (push (mapconcat #'regexp-quote segs "[ \t]?") patterns)))))
    ;; Longer phrases first so a short alias cannot pre-empt a longer one.
    (setq patterns (sort patterns (lambda (a b) (> (length a) (length b)))))
    (setq zetta-hywiki-alias--index index
          zetta-hywiki-alias--regexp
          (and patterns
               (concat "\\b\\(?:" (mapconcat #'identity patterns "\\|") "\\)\\b")))))

(defun zetta-hywiki-alias--ensure ()
  "Build the index and regexp if they are not current."
  (unless zetta-hywiki-alias--index (zetta-hywiki-alias--rebuild)))

(defun zetta-hywiki-alias--invalidate (&rest _)
  "Drop the cached index/regexp and bump the generation counter.
Advised onto the HyWikiWord-adding commands so a newly created word's derived
aliases appear immediately: the bumped generation is part of the `post-command'
change-guard key, so the next command re-scans even though creating a WikiWord
changes neither the buffer text nor the scroll position."
  (setq zetta-hywiki-alias--index nil
        zetta-hywiki-alias--regexp nil)
  (cl-incf zetta-hywiki-alias--generation))

(defun zetta-hywiki-alias--hywiki-face-at (pos)
  "Return non-nil if a HyWiki highlight overlay already covers POS."
  (seq-find (lambda (o) (eq (overlay-get o 'face) hywiki-word-face))
            (overlays-at pos)))

(defun zetta-hywiki-alias--highlight-region (start end)
  "Highlight derived HyWikiWord aliases between START and END."
  (zetta-hywiki-alias--ensure)
  (when zetta-hywiki-alias--regexp
    (remove-overlays start end 'zetta-hywiki-alias-p t)
    (save-excursion
      (goto-char start)
      (let ((case-fold-search t))
        (while (re-search-forward zetta-hywiki-alias--regexp end t)
          (let* ((mb (match-beginning 0))
                 (me (match-end 0))
                 (text (match-string-no-properties 0))
                 (key (downcase (replace-regexp-in-string "[ \t]+" "" text)))
                 (canon (gethash key zetta-hywiki-alias--index)))
            (when (and canon
                       ;; HyWiki itself owns the exact WikiWord form.
                       (not (string= text canon))
                       (not (zetta-hywiki-alias--hywiki-face-at mb)))
              (let ((ov (make-overlay mb me)))
                (overlay-put ov 'zetta-hywiki-alias canon)
                (overlay-put ov 'zetta-hywiki-alias-p t)
                ;; A DISTINCT (anonymous) face -- looks identical to
                ;; `hywiki-word-face' but is not `eq' to it, so HyWiki's own
                ;; per-command dehighlight (which clears overlays *by* that face
                ;; value) does not sweep our alias overlays away.
                (overlay-put ov 'face (list :inherit hywiki-word-face))
                (overlay-put ov 'evaporate t)
                (overlay-put ov 'help-echo (format "HyWiki alias -> %s" canon))))))))))

(defvar-local zetta-hywiki-alias--last nil
  "Cache key (tick window-start window-end) of the last visible-region refresh.
Skips redundant rescans so `post-command-hook' stays cheap and flicker-free.")

(defun zetta-hywiki-alias--post-command ()
  "Refresh alias highlighting in the selected window's visible region.
Driven off `post-command-hook' so highlights appear promptly and survive
HyWiki's own per-command dehighlight passes.  Only rescans when the buffer
was modified or the window scrolled since the last refresh."
  (when (and (bound-and-true-p zetta-hywiki-alias-mode)
             (fboundp 'hywiki-active-in-current-buffer-p)
             (hywiki-active-in-current-buffer-p))
    (let* ((win (selected-window))
           (ws (window-start win))
           (we (window-end win t))
           (key (list zetta-hywiki-alias--generation
                      (buffer-chars-modified-tick) ws we)))
      (unless (equal key zetta-hywiki-alias--last)
        (setq zetta-hywiki-alias--last key)
        (zetta-hywiki-alias--highlight-region
         (save-excursion (goto-char ws) (line-beginning-position))
         (save-excursion (goto-char (min we (point-max))) (line-end-position)))))))

(defun zetta-hywiki-alias--refresh-windows ()
  "Force an alias refresh in every visible window (used on mode enable)."
  (dolist (frame (frame-list))
    (dolist (win (window-list frame))
      (with-selected-window win
        (with-current-buffer (window-buffer win)
          (setq zetta-hywiki-alias--last nil)
          (zetta-hywiki-alias--post-command))))))

(defun zetta-hywiki-alias--word-at-advice (orig &optional range-flag hash-sign-only-flag)
  "Make `hywiki-word-at' recognise a derived alias at point.
When point is on an alias overlay, return its canonical WikiWord -- as a
\(WORD START END) list when RANGE-FLAG is set; otherwise defer to ORIG."
  (let ((canon (and (bound-and-true-p zetta-hywiki-alias-mode)
                    (get-char-property (point) 'zetta-hywiki-alias))))
    (if canon
        (if range-flag
            (let ((ov (seq-find (lambda (o) (overlay-get o 'zetta-hywiki-alias))
                                (overlays-at (point)))))
              (list canon (and ov (overlay-start ov)) (and ov (overlay-end ov))))
          canon)
      (funcall orig range-flag hash-sign-only-flag))))

;;;###autoload
(define-minor-mode zetta-hywiki-alias-mode
  "Global mode: highlight and activate case/space variants of HyWikiWords.
Aliases are derived from your existing HyWiki pages; see hywiki-alias.README.md
for what this does and (deliberately) does not cover."
  :global t
  :group 'zetta-hywiki-alias
  (if zetta-hywiki-alias-mode
      (if (not (require 'hywiki nil t))
          (progn
            (setq zetta-hywiki-alias-mode nil)
            (user-error "Load GNU Hyperbole/HyWiki before enabling %s"
                        'zetta-hywiki-alias-mode))
        (zetta-hywiki-alias--rebuild)
        (advice-add 'hywiki-word-at :around #'zetta-hywiki-alias--word-at-advice)
        (advice-add 'hywiki-add-referent :after #'zetta-hywiki-alias--invalidate)
        (advice-add 'hywiki-add-page :after #'zetta-hywiki-alias--invalidate)
        (add-hook 'post-command-hook #'zetta-hywiki-alias--post-command)
        (zetta-hywiki-alias--refresh-windows))
    (remove-hook 'post-command-hook #'zetta-hywiki-alias--post-command)
    (advice-remove 'hywiki-word-at #'zetta-hywiki-alias--word-at-advice)
    (advice-remove 'hywiki-add-referent #'zetta-hywiki-alias--invalidate)
    (advice-remove 'hywiki-add-page #'zetta-hywiki-alias--invalidate)
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (remove-overlays (point-min) (point-max) 'zetta-hywiki-alias-p t)))
    (zetta-hywiki-alias--invalidate)))

;; Enable automatically once HyWiki is available.  This file loads at startup,
;; before Hyperbole's deferred load, so the mode turns on as soon as HyWiki
;; provides.  Toggle it off any time with `M-x zetta-hywiki-alias-mode'.
(with-eval-after-load 'hywiki
  (zetta-hywiki-alias-mode 1))

(provide 'hywiki-alias)
;;; hywiki-alias.el ends here
