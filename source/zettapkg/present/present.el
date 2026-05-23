;;; present.el --- CLIM-style typed-presentation picker -*- lexical-binding: t; -*-
;;
;; Author: Charlie Holland <charliebkr707@gmail.com>
;; URL: https://github.com/<TBD>/present
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience, completion, tools
;;
;;; Commentary:
;;
;; CLIM-style presentation types for Emacs.  Open a minibuffer prompt
;; that expects type T, press `M-i', and every visible "presentation"
;; whose type is a subtype of T gets an avy label.  Pick one to insert
;; the value into the prompt.
;;
;; Inspired by CLIM (Common Lisp Interface Manager) where typed output
;; on the screen is automatically clickable from typed input prompts.
;;
;; Standalone: depends only on Emacs.  Transparently uses `avy',
;; `embark', `consult', and `marginalia' when they are loaded.
;;
;; Quick start:
;;
;;   (define-key minibuffer-local-map (kbd "M-i") #'present-pick-avy)
;;   (define-key minibuffer-local-map (kbd "C-c i")
;;               #'present-pick-completing-read)
;;
;; Then in any minibuffer prompt: M-i picks a visible presentation
;; matching the inferred type and inserts it.
;;
;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'thingatpt)

;; Forward declarations for optional packages.
(defvar avy-action)
(defvar avy-pre-action)
(defvar avy-style)
(declare-function avy-process "avy" (candidates &optional overlay-fn cleanup-fn))

(defgroup present nil
  "CLIM-style presentation types."
  :group 'convenience
  :prefix "present-")


;;;; Layer 1: Type registry
;; ----------------------------------------------------------------

(defconst present--re-url
  "\\b\\(?:https?\\|ftp\\|file\\)://[^ \t\n\r<>\"'`]+[^ \t\n\r<>\"'`.,;:!?)]"
  "Regex for URLs.")

(defconst present--re-email
  "\\b[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[[:alpha:]]\\{2,\\}\\b"
  "Regex for email addresses.")

(defconst present--re-uuid
  "\\b[0-9a-fA-F]\\{8\\}-[0-9a-fA-F]\\{4\\}-[0-9a-fA-F]\\{4\\}-[0-9a-fA-F]\\{4\\}-[0-9a-fA-F]\\{12\\}\\b"
  "Regex for UUIDs.")

(defconst present--re-integer
  "\\b[+-]?[0-9]+\\b"
  "Regex for integers.")

(defconst present--re-number
  "\\b[+-]?[0-9]+\\(?:\\.[0-9]+\\)?\\(?:[eE][+-]?[0-9]+\\)?\\b"
  "Regex for numbers (integer or floating-point).")

(defcustom present-types
  '((string         :parent nil)
    (url            :parent string  :embark url
                    :finder present--find-urls
                    :regex present--re-url)
    (file-path      :parent string  :embark file    :thing filename)
    (existing-file  :parent file-path :predicate file-exists-p)
    (buffer-name    :parent string  :embark buffer)
    (symbol         :parent string  :embark identifier)
    (function-name  :parent symbol  :embark function :symbol-predicate fboundp)
    (variable-name  :parent symbol  :embark variable :symbol-predicate boundp)
    (command-name   :parent symbol  :embark command  :symbol-predicate commandp)
    (number         :parent string  :regex present--re-number)
    (integer        :parent number  :regex present--re-integer)
    (email          :parent string  :embark email   :regex present--re-email)
    (uuid           :parent string                  :regex present--re-uuid)
    (line           :parent string  :thing line)
    (sentence       :parent string  :thing sentence)
    (paragraph      :parent string  :thing paragraph))
  "Presentation type lattice.
Each entry is (TYPE PROP VAL PROP VAL ...).  Recognized props:

  :finder           Fn (WINDOW BUFFER BEG END) -> list of presentation
                    plists.  Highest-priority source; supersedes the
                    other source props when present.
  :parent           Parent type symbol, or nil for root.
  :embark           Embark target type for pull-mode finding when
                    `embark' is loaded.
  :thing            `thing-at-point' thing for fallback scanning.
  :regex            Symbol naming a regex string (or the regex itself).
  :symbol-predicate Predicate fn called on an interned symbol;
                    matches in any visible buffer.
  :predicate        Extra filter applied to the extracted text.
  :extractor        Fn (BEG END BUFFER) -> typed value.  Default:
                    `buffer-substring-no-properties'.
  :inserter         Fn (PRESENTATION) -> string to insert.  Default:
                    presentation's :value, fallback :text.
  :parser           Fn (STRING) -> typed value for `present-read'."
  :type '(alist :key-type symbol :value-type plist)
  :group 'present)

(defcustom present-category-type-map
  '((file       . file-path)
    (buffer     . buffer-name)
    (symbol     . symbol)
    (identifier . symbol)
    (function   . function-name)
    (variable   . variable-name)
    (command    . command-name)
    (face       . symbol)
    (url        . url)
    (email      . email))
  "Map `completion-metadata' category symbols to presentation types."
  :type '(alist :key-type symbol :value-type symbol)
  :group 'present)

(defcustom present-heuristic-prompt-detection nil
  "Non-nil to infer presentation type from prompt-text keywords.
Heuristics are fragile; off by default."
  :type 'boolean
  :group 'present)

(defcustom present-pick-highlight t
  "Non-nil to highlight candidate regions while the picker is active.

For `present-pick-avy', paints `present-match-face' on every candidate
so the user can see which regions are clickable (CLIM-style: every
accepting presentation lights up).  For `present-pick-completing-read',
paints a preview overlay on the currently-focused candidate as the user
narrows in the minibuffer (matches the consult `:state' pattern of
`zetta-embark-pick-target-type').

Overlays are installed inside `unwind-protect' and cleared on exit, so
no churn persists past the picker."
  :type 'boolean
  :group 'present)

(defcustom present-avy-style 'de-bruijn
  "Override for `avy-style' during `present-pick-avy'.

`de-bruijn' uses a fixed-length label sequence: each candidate gets a
stable multi-char label assigned upfront, and each keystroke
deterministically advances to the next char.  Labels do not reshuffle
as you narrow — which is the behavior CLIM-style picking wants.

Set to nil to inherit avy's global `avy-style' (which defaults to
`at-full' and relabels survivors after each keystroke)."
  :type '(choice (const :tag "De Bruijn (stable, recommended)" de-bruijn)
                 (const :tag "At" at)
                 (const :tag "At-full" at-full)
                 (const :tag "Pre" pre)
                 (const :tag "Post" post)
                 (const :tag "Words" words)
                 (const :tag "Inherit avy default" nil))
  :group 'present)

(defcustom present-command-type-map
  '((browse-url            . url)
    (browse-url-of-buffer  . url)
    (browse-url-of-file    . file-path)
    (browse-url-emacs      . url)
    (eww                   . url)
    (find-file             . file-path)
    (find-file-other-window . file-path)
    (find-file-other-frame . file-path)
    (find-file-read-only   . file-path)
    (write-file            . file-path)
    (insert-file           . file-path)
    (load-file             . file-path)
    (load-library          . file-path)
    (kill-buffer           . buffer-name)
    (switch-to-buffer      . buffer-name)
    (switch-to-buffer-other-window . buffer-name)
    (switch-to-buffer-other-frame  . buffer-name)
    (describe-function     . function-name)
    (describe-variable     . variable-name)
    (describe-command      . command-name)
    (describe-symbol       . symbol)
    (find-function         . function-name)
    (find-variable         . variable-name)
    (apropos-command       . command-name)
    (apropos-function      . function-name)
    (apropos-variable      . variable-name))
  "Map a calling command (symbol) to the presentation type it accepts.
Consulted by `present--detect-expected-type' for prompts that do not
carry a `completion-metadata' category (e.g. bare `read-string')."
  :type '(alist :key-type symbol :value-type symbol)
  :group 'present)

(defcustom present-prompt-keyword-map
  '(("url"      . url)
    ("URL"      . url)
    ("file"     . file-path)
    ("path"     . file-path)
    ("buffer"   . buffer-name)
    ("function" . function-name)
    ("variable" . variable-name)
    ("command"  . command-name)
    ("email"    . email)
    ("uuid"     . uuid))
  "Keywords to look for in minibuffer prompt text when
`present-heuristic-prompt-detection' is non-nil."
  :type '(alist :key-type string :value-type symbol)
  :group 'present)

(defmacro present-deftype (name &rest props)
  "Add or update NAME in `present-types' with PROPS.

PROPS are quoted literally (this is a declarative form).  Example:

  (present-deftype http-url :parent url)"
  (declare (indent 1))
  `(setf (alist-get ',name present-types) ',props))

(defun present-type-prop (type prop)
  "Return PROP value for TYPE in `present-types', or nil."
  (plist-get (alist-get type present-types) prop))

(defun present-subtype-p (sub super)
  "Return non-nil if SUB is SUPER or a descendant via :parent chain."
  (let ((seen nil)
        (cur sub)
        (found nil))
    (while (and cur (not (memq cur seen)) (not found))
      (if (eq cur super)
          (setq found t)
        (push cur seen)
        (setq cur (present-type-prop cur :parent))))
    found))

(defun present--all-subtypes-of (super)
  "Return all types in `present-types' that are subtypes of SUPER (inclusive)."
  (cl-loop for entry in present-types
           for type = (car entry)
           when (present-subtype-p type super)
           collect type))


;;;; Layer 2: Collection — scan visible windows
;; ----------------------------------------------------------------

(defvar present-collect-extra-fn nil
  "Optional fn called as (EXPECTED-TYPE WINDOW BUFFER BEG END).
Should return a list of presentation plists.  Useful for wiring in
richer external collectors (e.g. embark-based) without modifying
this package.")

(defun present--scan-windows (fn)
  "Call FN with (WINDOW BUFFER WIN-START WIN-END) for each visible
non-minibuffer window.  Collect and concatenate the results."
  (let ((mini (active-minibuffer-window))
        results)
    (walk-windows
     (lambda (win)
       (unless (eq win mini)
         (let* ((buf (window-buffer win))
                (start (window-start win))
                (end (window-end win t)))
           (with-current-buffer buf
             (push (funcall fn win buf start end) results)))))
     nil 'visible)
    (apply #'append (nreverse results))))

(defun present--make-presentation (type value buffer window beg end &optional text)
  "Build a presentation plist."
  (list :type type
        :value value
        :buffer buffer
        :window window
        :beg beg
        :end end
        :text (or text value)))

(defun present--collect-push (window buffer beg end expected)
  "Collect text-property presentations in BUFFER between BEG and END.
Returns presentations whose declared type is EXPECTED or a subtype
(when EXPECTED is non-nil); otherwise all."
  (let (results)
    (save-excursion
      (goto-char beg)
      (while (< (point) end)
        (let* ((next (or (next-single-char-property-change
                          (point) 'present-type buffer end)
                         end))
               (raw (get-char-property (point) 'present-type)))
          (when raw
            (let* ((type (if (consp raw) (car raw) raw))
                   (extra (and (consp raw) (cdr raw)))
                   (text (buffer-substring-no-properties (point) next))
                   (value (or (plist-get extra :value) text)))
              (when (or (null expected)
                        (present-subtype-p type expected))
                (push (present--make-presentation
                       type value buffer window (point) next text)
                      results))))
          (goto-char next))))
    (nreverse results)))

(defun present--regex-for (props)
  "Resolve PROPS' :regex prop to an actual regex string, or nil."
  (let ((r (plist-get props :regex)))
    (cond ((stringp r) r)
          ((symbolp r) (and (boundp r) (symbol-value r))))))

(defun present--scan-regex (type props window buffer beg end)
  "Scan BUFFER between BEG and END for matches of TYPE's :regex."
  (let ((re (present--regex-for props))
        (predicate (plist-get props :predicate))
        results)
    (when re
      (save-excursion
        (goto-char beg)
        (while (re-search-forward re end t)
          (let ((match (match-string-no-properties 0)))
            (when (or (null predicate) (funcall predicate match))
              (push (present--make-presentation
                     type match buffer window
                     (match-beginning 0) (match-end 0))
                    results))))))
    (nreverse results)))

(defun present--scan-thing (type props window buffer beg end)
  "Scan BUFFER between BEG and END for thing-at-point of TYPE's :thing."
  (let ((thing (plist-get props :thing))
        (predicate (plist-get props :predicate))
        results last-end)
    (when thing
      (save-excursion
        (goto-char beg)
        (while (< (point) end)
          (let ((bounds (ignore-errors (bounds-of-thing-at-point thing))))
            (cond
             ((and bounds (> (cdr bounds) (or last-end 0)))
              (let ((text (buffer-substring-no-properties
                           (car bounds) (cdr bounds))))
                (when (or (null predicate) (funcall predicate text))
                  (push (present--make-presentation
                         type text buffer window
                         (car bounds) (cdr bounds))
                        results))
                (setq last-end (cdr bounds))
                (goto-char (cdr bounds))))
             (t (forward-char 1)))))))
    (nreverse results)))

(defun present--scan-symbols (type props window buffer beg end)
  "Walk symbols in BUFFER between BEG and END, keep those matching
TYPE's :symbol-predicate."
  (let ((pred (plist-get props :symbol-predicate))
        results last-end)
    (when pred
      (save-excursion
        (goto-char beg)
        (while (< (point) end)
          (let ((bounds (ignore-errors (bounds-of-thing-at-point 'symbol))))
            (cond
             ((and bounds (> (cdr bounds) (or last-end 0)))
              (let* ((name (buffer-substring-no-properties
                            (car bounds) (cdr bounds)))
                     (sym (intern-soft name)))
                (when (and sym (funcall pred sym))
                  (push (present--make-presentation
                         type name buffer window
                         (car bounds) (cdr bounds))
                        results))
                (setq last-end (cdr bounds))
                (goto-char (cdr bounds))))
             (t (forward-char 1)))))))
    (nreverse results)))

;; URL finders: mode-aware sources for the `url' type.
;; ----------------------------------------------------------------

(defconst present--re-org-link
  "\\[\\[\\(\\(?:https?\\|ftp\\|file\\|mailto\\):[^]]+\\)\\]\\(?:\\[\\([^]]+\\)\\]\\)?\\]"
  "Regex matching an org-mode link with a URL-like target.
Group 1 is the URL; group 2 is the optional description.")

(defconst present--shr-url-rendering-modes
  '(eww-mode nov-mode devdocs-mode elfeed-show-mode helpful-mode
             Info-mode notmuch-show-mode)
  "Major modes that render hyperlinks via shr-style text properties
rather than as raw URLs in buffer text.  In these buffers the
plain-text URL regex is skipped (it would find nothing useful).")

(defun present--find-urls-via-shr (window buffer beg end)
  "Find URL presentations via the `shr-url' text property.

Works in eww, nov.el, devdocs, elfeed, and any package layering on
`shr'.  The visible text is taken as the presentation's :text (link
description); the URL stored in the property becomes :value, so
picking inserts the URL and not the description."
  (let (results)
    (save-excursion
      (goto-char beg)
      (while (< (point) end)
        (let* ((next (or (next-single-char-property-change
                          (point) 'shr-url buffer end)
                         end))
               (url (get-char-property (point) 'shr-url)))
          (when (and url (stringp url))
            (push (list :type 'url
                        :value url
                        :buffer buffer
                        :window window
                        :beg (point)
                        :end next
                        :text (buffer-substring-no-properties
                               (point) next))
                  results))
          (goto-char next))))
    (nreverse results)))

(defun present--find-urls-org (window buffer beg end)
  "Find URL presentations from org-mode link syntax.

Matches `[[URL][DESC]]' and `[[URL]]' where URL has a URI scheme.
:value is the URL; :text is the description (or the URL).  Bounds are
deliberately positioned on the *visible* portion of the link so the
avy label renders on visible text even when `org-link-descriptive' is
non-nil (which hides the `[[URL][' / `]]' brackets):

  - `[[URL][DESC]]' → bounds cover DESC.
  - `[[URL]]'       → bounds cover the URL (no description; the URL
                      itself is what the user sees rendered).

Each returned plist also carries `:link-bounds' — the full bracket
region — so `present--find-urls' can suppress plain-regex matches that
fall inside an org link (avoiding double-counting bracketed URLs)."
  (let (results)
    (save-excursion
      (goto-char beg)
      (while (re-search-forward present--re-org-link end t)
        (let* ((url       (match-string-no-properties 1))
               (desc      (match-string-no-properties 2))
               (desc-beg  (match-beginning 2))
               (desc-end  (match-end 2))
               (url-beg   (match-beginning 1))
               (url-end   (match-end 1))
               (link-beg  (match-beginning 0))
               (link-end  (match-end 0))
               (visible-beg (or desc-beg url-beg))
               (visible-end (or desc-end url-end)))
          (push (list :type 'url
                      :value url
                      :buffer buffer
                      :window window
                      :beg visible-beg
                      :end visible-end
                      :text (or desc url)
                      :link-bounds (cons link-beg link-end))
                results))))
    (nreverse results)))

(defun present--find-urls (window buffer beg end)
  "Mode-aware URL finder; the URL type's :finder.

Layers, concatenated and deduped by exact bounds at the top level:

1. `shr-url' text properties (eww, nov, devdocs, elfeed, helpful, Info).
2. Org-mode link syntax (only in org buffers): `[[URL][DESC]]'.
3. Plain-text URL regex.  In shr-rendered buffers, skipped entirely
   (no raw URLs to find).  In org-mode buffers, plain matches whose
   bounds fall *inside* an org link's bracket region are dropped —
   that avoids double-counting `[[https://x][text]]' as both an
   org-link presentation and a raw `https://x' presentation, while
   still picking up bare URLs that appear outside any org link."
  (with-current-buffer buffer
    (let (results org-results)
      ;; Layer 1: shr-url text property.
      (setq results
            (nconc results
                   (present--find-urls-via-shr window buffer beg end)))
      ;; Layer 2: org-link syntax.  Capture results separately so we
      ;; can extract link-bound zones for layer-3 filtering.
      (when (derived-mode-p 'org-mode 'org-agenda-mode)
        (setq org-results (present--find-urls-org window buffer beg end))
        (setq results (nconc results org-results)))
      ;; Layer 3: plain-text URL regex.
      (unless (apply #'derived-mode-p present--shr-url-rendering-modes)
        (let* ((plain (present--scan-regex
                       'url '(:regex present--re-url)
                       window buffer beg end))
               (zones (delq nil (mapcar
                                 (lambda (p) (plist-get p :link-bounds))
                                 org-results)))
               (filtered (if zones
                             (cl-remove-if
                              (lambda (p)
                                (let ((pb (plist-get p :beg))
                                      (pe (plist-get p :end)))
                                  (cl-some
                                   (lambda (z)
                                     (and (>= pb (car z))
                                          (<= pe (cdr z))))
                                   zones)))
                              plain)
                           plain)))
          (setq results (nconc results filtered))))
      results)))

(defun present--collect-type-in-window (type window buffer beg end)
  "Collect presentations of TYPE in WINDOW between BEG and END.
Dispatches on the first matching source prop in priority order:
:finder, :regex, :thing, :symbol-predicate."
  (let ((props (alist-get type present-types)))
    (cond
     ((plist-get props :finder)
      (funcall (plist-get props :finder) window buffer beg end))
     ((plist-get props :regex)
      (present--scan-regex type props window buffer beg end))
     ((plist-get props :thing)
      (present--scan-thing type props window buffer beg end))
     ((plist-get props :symbol-predicate)
      (present--scan-symbols type props window buffer beg end)))))

(defun present--dedupe (presentations)
  "Dedupe PRESENTATIONS by (buffer beg end)."
  (let ((seen (make-hash-table :test 'equal))
        result)
    (dolist (p presentations)
      (let ((key (list (plist-get p :buffer)
                       (plist-get p :beg)
                       (plist-get p :end))))
        (unless (gethash key seen)
          (puthash key t seen)
          (push p result))))
    (nreverse result)))

(defun present--sort (presentations)
  "Sort by (window-order, buffer-position)."
  (let ((window-order
         (let ((i 0) ord)
           (walk-windows (lambda (w) (push (cons w i) ord) (cl-incf i))
                         nil 'visible)
           ord)))
    (sort presentations
          (lambda (a b)
            (let ((oa (cdr (assq (plist-get a :window) window-order)))
                  (ob (cdr (assq (plist-get b :window) window-order))))
              (cond
               ((and oa ob (/= oa ob)) (< oa ob))
               (t (< (plist-get a :beg) (plist-get b :beg)))))))))

(defun present-collect-visible (&optional expected)
  "Scan all visible non-minibuffer windows for presentations.
With EXPECTED (a presentation type), restrict to EXPECTED and its
subtypes; otherwise return all detectable presentations."
  (let ((types (if expected
                   (present--all-subtypes-of expected)
                 (mapcar #'car present-types))))
    (present--sort
     (present--dedupe
      (present--scan-windows
       (lambda (win buf beg end)
         (let (acc)
           (setq acc (present--collect-push win buf beg end expected))
           (dolist (type types)
             (setq acc (nconc acc (present--collect-type-in-window
                                   type win buf beg end))))
           (when present-collect-extra-fn
             (setq acc (nconc acc (ignore-errors
                                    (funcall present-collect-extra-fn
                                             expected win buf beg end)))))
           acc)))))))


;;;; Layer 3: Pickers
;; ----------------------------------------------------------------

(defface present-label-face
  '((t :inherit highlight :weight bold))
  "Face for fallback picker labels (used when `avy' is not loaded)."
  :group 'present)

(defface present-match-face
  '((t :inherit lazy-highlight))
  "Face for presentation matches in the fallback picker."
  :group 'present)

(defconst present--fallback-label-alphabet
  "asdfghjklqwertyuiopzxcvbnm"
  "Letters used for fallback picker labels (home-row-first).")

(defun present--label-for-index (i)
  "Return a label string for index I (single char up to length of alphabet)."
  (let ((alpha present--fallback-label-alphabet))
    (if (< i (length alpha))
        (char-to-string (aref alpha i))
      (format "%d" i))))

(defun present--install-highlights (presentations)
  "Paint `present-match-face' overlays on each presentation's bounds.
Returns the overlay list for later `present--remove-highlights'."
  (mapcar
   (lambda (p)
     (let ((ov (make-overlay (plist-get p :beg)
                             (plist-get p :end)
                             (plist-get p :buffer))))
       (overlay-put ov 'face 'present-match-face)
       (overlay-put ov 'priority 100)
       (overlay-put ov 'present-highlight t)
       ov))
   presentations))

(defun present--remove-highlights (overlays)
  "Delete OVERLAYS installed by `present--install-highlights'."
  (mapc (lambda (ov) (when (overlayp ov) (delete-overlay ov)))
        overlays))

(defun present--pick-with-fallback (presentations)
  "Built-in picker: overlay labels + `read-char'.  Returns chosen presentation."
  (let ((overlays nil)
        (label->p nil)
        (i 0)
        chosen)
    (unwind-protect
        (progn
          (dolist (p presentations)
            (with-current-buffer (plist-get p :buffer)
              (let* ((label (present--label-for-index i))
                     (ov (make-overlay (plist-get p :beg)
                                       (plist-get p :end)
                                       (plist-get p :buffer))))
                (overlay-put ov 'before-string
                             (propertize label 'face 'present-label-face))
                (overlay-put ov 'face 'present-match-face)
                (push (cons label p) label->p)
                (push ov overlays)
                (cl-incf i))))
          (let* ((input (char-to-string
                         (read-char (format "Pick (%d): " i))))
                 (match (assoc input label->p)))
            (setq chosen (cdr match))))
      (mapc #'delete-overlay overlays))
    chosen))

(defun present--pick-with-avy (presentations)
  "Use `avy' to pick from PRESENTATIONS.  Returns chosen presentation.

Uses the dual-binding pattern: `avy-pre-action' captures the
selection (so we keep window info); `avy-action' is bound to
`ignore' so avy does not navigate point into the target window.

When `present-pick-highlight' is non-nil, paints `present-match-face'
overlays on all candidates while the picker is active (CLIM-style)."
  (let* ((candidates (mapcar
                      (lambda (p)
                        (cons (cons (plist-get p :beg) (plist-get p :end))
                              (plist-get p :window)))
                      presentations))
         (original-window (selected-window))
         (highlights (when present-pick-highlight
                       (present--install-highlights presentations)))
         picked)
    (unwind-protect
        (condition-case nil
            (let ((avy-pre-action (lambda (res) (setq picked res)))
                  (avy-action #'ignore)
                  (avy-style (or present-avy-style
                                 (and (boundp 'avy-style) avy-style))))
              (avy-process candidates))
          (quit nil)
          (error nil))
      (present--remove-highlights highlights))
    (when (window-live-p original-window)
      (select-window original-window))
    (when picked
      ;; PICKED has the shape that came from CANDIDATES — for multi-window
      ;; candidates that is `((BEG . END) . WIN)'.  Unwrap defensively.
      (let* ((bounds-and-win (if (consp (car-safe picked)) picked
                               (cons picked nil)))
             (bounds (car bounds-and-win))
             (win    (cdr bounds-and-win))
             (beg    (if (consp bounds) (car bounds) bounds)))
        (cl-find-if (lambda (p)
                      (and (= (plist-get p :beg) beg)
                           (or (null win)
                               (eq (plist-get p :window) win))))
                    presentations)))))

(defun present--candidate-for-completing-read (p)
  "Build a uniquely-propertized candidate string for presentation P."
  (let* ((text (plist-get p :text))
         ;; Disambiguate identical texts by appending invisible coords.
         (key (format "%s\0%s:%d"
                      text
                      (buffer-name (plist-get p :buffer))
                      (plist-get p :beg))))
    (propertize key 'display text 'present-presentation p)))

(defun present--annotate-candidate (cand)
  "Annotation function for the `present-target' completion category."
  (when-let* ((p (get-text-property 0 'present-presentation cand)))
    (let* ((type (plist-get p :type))
           (buf (buffer-name (plist-get p :buffer)))
           (beg (plist-get p :beg))
           (line (with-current-buffer (plist-get p :buffer)
                   (line-number-at-pos beg))))
      (concat "  "
              (propertize (format "[%s %s:%d]" type buf line)
                          'face 'completions-annotations)))))

(defun present--make-completion-table (presentations)
  "Build a completion table over PRESENTATIONS with present-target category."
  (let ((candidates
         (mapcar #'present--candidate-for-completing-read presentations)))
    (lambda (str pred action)
      (if (eq action 'metadata)
          `(metadata (category . present-target)
                     (annotation-function . present--annotate-candidate))
        (complete-with-action action candidates str pred)))))

(defun present--pick-with-completing-read (presentations)
  "Pick from PRESENTATIONS via `completing-read'.  Returns chosen.

When `consult--read' is available, uses its `:state' callback to paint
a preview overlay on the currently-focused candidate (matching
`zetta-embark-pick-target-type's UI).  Without consult, falls back to
plain `completing-read' with no preview."
  (let* ((table (present--make-completion-table presentations))
         (preview-overlay nil)
         (clear-preview
          (lambda ()
            (when (overlayp preview-overlay)
              (delete-overlay preview-overlay)
              (setq preview-overlay nil))))
         (state-fn
          (lambda (action cand)
            (when (eq action 'preview)
              (funcall clear-preview)
              (when (and present-pick-highlight (stringp cand))
                (when-let* ((p (get-text-property
                                0 'present-presentation cand)))
                  (let ((ov (make-overlay (plist-get p :beg)
                                          (plist-get p :end)
                                          (plist-get p :buffer))))
                    (overlay-put ov 'face 'present-match-face)
                    (overlay-put ov 'priority 100)
                    (overlay-put ov 'present-highlight t)
                    (setq preview-overlay ov))))))))
    (unwind-protect
        (let ((choice (if (fboundp 'consult--read)
                          (consult--read
                           table
                           :prompt "Insert: "
                           :require-match t
                           :sort nil
                           :category 'present-target
                           :state state-fn)
                        (completing-read "Insert: " table nil t))))
          (get-text-property 0 'present-presentation choice))
      (funcall clear-preview))))


;;;; Layer 4: Accept API + detection + insertion
;; ----------------------------------------------------------------

(defvar present--expected-type-override nil
  "Dynamic override consulted by `present--detect-expected-type'.
Set via `present-with-expected-type' or by `present-read'.")

(defvar-local present--minibuffer-opener nil
  "Command that triggered the current minibuffer.

Captured at `minibuffer-setup-hook' time by
`present--capture-minibuffer-opener', enabled by `present-mode'.
Consulted by `present--type-from-command' to look up an expected
presentation type for un-instrumented `read-string'-style prompts.")

(defun present--capture-minibuffer-opener ()
  "Record `this-command' into `present--minibuffer-opener' (local)."
  (setq-local present--minibuffer-opener this-command))

(defun present--type-from-command ()
  "Return a presentation type from `present--minibuffer-opener', or nil."
  (when (minibufferp)
    (alist-get present--minibuffer-opener present-command-type-map)))

(defun present--type-from-prompt (prompt)
  "Return a presentation type inferred from PROMPT text, or nil."
  (when prompt
    (cl-some (lambda (entry)
               (and (string-match-p (regexp-quote (car entry)) prompt)
                    (cdr entry)))
             present-prompt-keyword-map)))

(defun present--type-from-category ()
  "Return a presentation type derived from `completion-metadata' category."
  (when (and (minibufferp)
             (boundp 'minibuffer-completion-table)
             minibuffer-completion-table)
    (let* ((md (ignore-errors
                 (completion-metadata
                  (minibuffer-contents)
                  minibuffer-completion-table
                  minibuffer-completion-predicate)))
           (cat (and md (cdr (assq 'category md)))))
      (and cat (alist-get cat present-category-type-map)))))

(defun present--detect-expected-type ()
  "Cascade: override → category → command-map → prompt heuristic → nil.

Category is the most reliable signal (only present when the caller
went through `completing-read').  The command map fills the gap for
bare `read-string' prompts where the calling command implies a type
(e.g. `browse-url' → `url').  The prompt heuristic is a last-resort
fallback off by default — enable via `present-heuristic-prompt-detection'."
  (or present--expected-type-override
      (present--type-from-category)
      (present--type-from-command)
      (and present-heuristic-prompt-detection
           (minibufferp)
           (present--type-from-prompt (minibuffer-prompt)))))

(defmacro present-with-expected-type (type &rest body)
  "Run BODY with `present--expected-type-override' bound to TYPE."
  (declare (indent 1) (debug t))
  `(let ((present--expected-type-override ,type))
     ,@body))

(defun present--insert-value (p)
  "Insert presentation P's value at point in the current buffer."
  (let* ((type (plist-get p :type))
         (inserter (present-type-prop type :inserter))
         (s (if inserter
                (funcall inserter p)
              (or (plist-get p :value) (plist-get p :text)))))
    (insert s)))

;;;###autoload
(defun present-pick-avy ()
  "Pick a visible presentation via avy labels and insert its value.

Inferred type comes from (in order): `present--expected-type-override',
`completion-metadata' category, and (when
`present-heuristic-prompt-detection' is non-nil) prompt heuristics."
  (interactive)
  (let* ((expected (present--detect-expected-type))
         (presentations (present-collect-visible expected)))
    (cond
     ((null presentations)
      (message "present: no %s presentations visible"
               (or expected "matching")))
     (t
      (let ((chosen (if (fboundp 'avy-process)
                        (present--pick-with-avy presentations)
                      (present--pick-with-fallback presentations))))
        (when chosen (present--insert-value chosen)))))))

;;;###autoload
(defun present-pick-completing-read ()
  "Pick a visible presentation via `completing-read' and insert."
  (interactive)
  (let* ((expected (present--detect-expected-type))
         (presentations (present-collect-visible expected)))
    (cond
     ((null presentations)
      (message "present: no %s presentations visible"
               (or expected "matching")))
     (t
      (let ((chosen (present--pick-with-completing-read presentations)))
        (when chosen (present--insert-value chosen)))))))

;;;###autoload
(defun present-read (type prompt &optional initial history default)
  "Read a value of TYPE from the minibuffer with picker keys available.

Like `read-from-minibuffer' but typed: the prompt's expected type is
TYPE.  If TYPE has a :parser prop, the input is parsed through it."
  (let* ((raw (present-with-expected-type type
                (read-from-minibuffer prompt initial nil nil
                                      history default)))
         (parser (present-type-prop type :parser)))
    (if parser (funcall parser raw) raw)))

;;;###autoload
(defalias 'present-accept #'present-read
  "CLIM-style alias for `present-read'.")

;;;###autoload
(defun present-insert-typed (text type &optional value)
  "Insert TEXT into current buffer carrying TYPE as a presentation.

If VALUE is given, it overrides TEXT as the logical value of the
presentation (display text vs. typed value can differ)."
  (insert (propertize text 'present-type
                      (if value (cons type (list :value value)) type))))


;;;; Optional: highlight-on-prompt (opt-in)
;; ----------------------------------------------------------------

(defvar-local present--highlight-overlays nil
  "Overlays installed by `present-highlight-mode' in this buffer.")

(defun present--highlight-clear ()
  "Remove `present-highlight-mode' overlays from all buffers."
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when present--highlight-overlays
        (mapc #'delete-overlay present--highlight-overlays)
        (setq present--highlight-overlays nil)))))

(defun present--highlight-setup ()
  "Add overlays to visible presentations matching expected type."
  (let ((expected (present--detect-expected-type)))
    (when expected
      (let ((presentations (present-collect-visible expected))
            (mb-window (active-minibuffer-window)))
        (dolist (p presentations)
          ;; Fresh lexical binding so the keymap closure captures this P.
          (let ((this-p p))
            (with-current-buffer (plist-get this-p :buffer)
              (let ((ov (make-overlay (plist-get this-p :beg)
                                      (plist-get this-p :end))))
                (overlay-put ov 'face 'present-match-face)
                (overlay-put ov 'mouse-face 'highlight)
                (overlay-put ov 'help-echo "mouse-1: insert presentation")
                (overlay-put ov 'keymap
                             (let ((m (make-sparse-keymap)))
                               (define-key m [mouse-1]
                                           (lambda ()
                                             (interactive)
                                             (when (window-live-p mb-window)
                                               (with-selected-window mb-window
                                                 (present--insert-value this-p)
                                                 (exit-minibuffer)))))
                               m))
                (push ov present--highlight-overlays)))))))))

(defun present--highlight-on-setup ()
  "Hook for `minibuffer-setup-hook'."
  (when (bound-and-true-p present-highlight-mode)
    (present--highlight-setup)
    (add-hook 'minibuffer-exit-hook #'present--highlight-clear nil t)))

;;;###autoload
(define-minor-mode present-mode
  "Activate per-prompt presentation-type detection.

Installs a `minibuffer-setup-hook' that records `this-command' (the
opener) into a minibuffer-local variable, so `present--detect-expected-type'
can look up un-instrumented prompts (e.g. `browse-url') in
`present-command-type-map'.

Cheap (one `setq-local' per minibuffer); off by default in the package
so the standalone package has no load-time hooks."
  :global t
  :group 'present
  (if present-mode
      (add-hook 'minibuffer-setup-hook
                #'present--capture-minibuffer-opener)
    (remove-hook 'minibuffer-setup-hook
                 #'present--capture-minibuffer-opener)))

;;;###autoload
(define-minor-mode present-highlight-mode
  "Highlight all visible presentations matching the prompt's expected type.

Off by default — overlay churn on each minibuffer setup can be
non-trivial for buffers with many matches."
  :global t
  :group 'present
  (if present-highlight-mode
      (add-hook 'minibuffer-setup-hook #'present--highlight-on-setup)
    (remove-hook 'minibuffer-setup-hook #'present--highlight-on-setup)
    (present--highlight-clear)))


(provide 'present)
;;; present.el ends here
