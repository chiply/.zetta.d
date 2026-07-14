;;; pdfnote.el --- One-way sync of native PDF annotations to notes -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Charlie Holland

;; Author: Charlie Holland <charliebkr707@gmail.com>
;; Maintainer: Charlie Holland <charliebkr707@gmail.com>
;; URL: https://github.com/<TBD>/pdfnote
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (pdf-tools "1.0"))
;; Keywords: convenience, hypermedia, tools, wp

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Extract the *native* annotations embedded in a PDF (highlights,
;; underlines, strike-outs, squigglies, and text/note stickies) and
;; render them into an Org notes page that links back to the PDF.  The
;; sync is strictly one-way: the PDF is the source of truth, the notes
;; page is regenerated from it.
;;
;; This is deliberately designed for the "annotate anywhere" workflow:
;; you highlight on an iPad (or any reader that writes standard PDF
;; markup annotations), and those highlights become an Org page in a
;; Logseq graph -- something Logseq's own in-app highlighter cannot
;; consume, because it stores highlights in an .edn sidecar rather than
;; in the PDF itself.
;;
;; Highlighted *text* is recovered from the annotation's quad geometry
;; via `pdf-info-gettext' (iPad highlights carry no text of their own),
;; then reflowed into a single clean paragraph per highlight.
;;
;; Idempotency: re-running a sync regenerates the managed section.
;; Anything you write under the `pdfnote-user-heading' ("* Notes") is
;; carried across syncs verbatim, so your own commentary is never lost.
;; A page that exists but was not created by pdfnote is refused unless
;; forced, so you cannot clobber a hand-authored page by accident.
;;
;; Entry points:
;;   `pdfnote-sync-file'    sync one PDF -> its notes page
;;   `pdfnote-sync-buffer'  sync the PDF in the current pdf-view buffer
;;   `pdfnote-sync-all'     sync every annotated PDF in the assets dir
;;   `pdfnote-preview'      show the generated page without writing it
;;   `pdfnote-visit-notes'  open (creating if needed) a PDF's notes page
;;
;; The generated per-highlight backlink is a `pdf:' Org link
;; (registered by this package) that opens the PDF at the right page in
;; pdf-tools.  In Logseq the page-level `file::' property opens the
;; asset.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(declare-function pdf-info-getannots "pdf-info" (&optional pages file-or-buffer))
(declare-function pdf-info-gettext "pdf-info" (page edges &optional selection-style file-or-buffer))
(declare-function pdf-view-goto-page "pdf-view" (page &optional window))
(declare-function org-link-set-parameters "ol" (type &rest parameters))

(defgroup pdfnote nil
  "One-way sync of native PDF annotations into Org notes pages."
  :group 'pdf-tools
  :prefix "pdfnote-")

(defcustom pdfnote-assets-directory (expand-file-name "~/logseq/assets/")
  "Directory holding the annotated PDFs (Logseq `assets/')."
  :type 'directory)

(defcustom pdfnote-pages-directory (expand-file-name "~/logseq/pages/")
  "Directory the notes pages are written to (Logseq `pages/')."
  :type 'directory)

(defcustom pdfnote-file-prefix "(highlights pdfnote) "
  "Prefix for generated notes filenames (and the Logseq page title).
Keeps generated pages grouped and avoids colliding with hand-authored
pages.  The default follows the Logseq \"(highlights SOURCE) TITLE\"
naming convention used by the eww / readwise highlight imports, so PDF
notes sort alongside them.  Set to \"\" for bare names matching the PDF
basename."
  :type 'string)

(defcustom pdfnote-asset-link-directory "../assets"
  "Path prefix used in links from a notes page back to the PDF.
Relative to a page in `pdfnote-pages-directory'.  The Logseq default of
sibling `pages/' and `assets/' directories makes \"../assets\" correct."
  :type 'string)

(defcustom pdfnote-annotation-types
  '(highlight underline strike-out squiggly text free-text)
  "Annotation types to export, as returned by `pdf-info-getannots'."
  :type '(repeat symbol))

(defcustom pdfnote-selection-style 'word
  "Granularity `pdf-info-gettext' uses when recovering highlighted text.
`word' rounds the selection to whole words at both ends, which avoids
clipping a partial leading/trailing glyph; `glyph' is exact but can
clip; `line' captures whole lines."
  :type '(choice (const word) (const glyph) (const line)))

(defcustom pdfnote-user-heading "Notes"
  "Top-level heading marking the start of the user-owned region.
Everything from this heading to end-of-file is preserved verbatim
across syncs.  The generated highlights live above it."
  :type 'string)

(defcustom pdfnote-page-file-function nil
  "Optional function mapping a PDF path to its notes file path.
When nil, the default naming (`pdfnote-file-prefix' + slug under
`pdfnote-pages-directory') is used."
  :type '(choice (const nil) function))

(defcustom pdfnote-color-palette
  '(("yellow" . "#ffd400") ("green"  . "#63c563") ("blue"   . "#4aa3f0")
    ("pink"   . "#ff8fb1") ("red"    . "#ff5c5c") ("orange" . "#ff9500")
    ("purple" . "#c06be6") ("gray"   . "#b0b0b0"))
  "Named colors highlight hex values are snapped to (nearest RGB).
Tuned toward the default iPad/iOS highlighter swatches so, e.g., the
common amber highlight `#ffd100' reads as \"yellow\" rather than
\"orange\"."
  :type '(alist :key-type string :value-type string))

;;;; Text extraction

(defun pdfnote--reflow (s)
  "Collapse PDF layout whitespace in S into one clean line.
De-hyphenates words broken across lines and folds newlines to spaces."
  (when s
    (let ((s (replace-regexp-in-string
              "\\([[:alpha:]]\\)-[ \t]*\n[ \t]*\\([[:alpha:]]\\)" "\\1\\2" s)))
      (string-trim (replace-regexp-in-string "[ \t\n]+" " " s)))))

(defun pdfnote--sort-quads (quads)
  "Return QUADS sorted top-to-bottom, then left-to-right.
Each quad is (LEFT TOP RIGHT BOTTOM) in relative [0,1] coordinates."
  (sort (copy-sequence quads)
        (lambda (a b)
          (if (< (abs (- (nth 1 a) (nth 1 b))) 0.012)
              (< (nth 0 a) (nth 0 b))
            (< (nth 1 a) (nth 1 b))))))

(defun pdfnote--quad-height (q)
  "Relative height of quad Q, floored so it is never zero."
  (max 0.001 (- (nth 3 q) (nth 1 q))))

(defun pdfnote--group-lines (quads)
  "Group QUADS into visual text lines, ordered top-to-bottom.
Two quads share a line when their tops differ by less than 60% of the
smallest quad height, so sub-pixel jitter never splits a line."
  (let* ((tol (* 0.6 (apply #'min (mapcar #'pdfnote--quad-height quads))))
         (sorted (pdfnote--sort-quads quads))
         lines cur curtop)
    (dolist (q sorted)
      (if (and curtop (< (abs (- (nth 1 q) curtop)) tol))
          (push q cur)
        (when cur (push (nreverse cur) lines))
        (setq cur (list q) curtop (nth 1 q))))
    (when cur (push (nreverse cur) lines))
    (nreverse lines)))

(defun pdfnote--line-center (line)
  "Return the vertical center of LINE (a list of quads)."
  (/ (+ (apply #'min (mapcar (lambda (q) (nth 1 q)) line))
        (apply #'max (mapcar (lambda (q) (nth 3 q)) line)))
     2.0))

(defun pdfnote--region-text (file page quads)
  "Extract the highlighted text on PAGE of FILE covered by QUADS.
Selects one flowing region from the start of the topmost highlighted
line to the end of the bottommost -- mirroring how the highlight was
drawn.  The horizontal endpoints come from line geometry (min-left of
the top line, max-right of the bottom line), so a line split across
several quads or annotations is captured whole.  The VERTICAL endpoints
use each line's center, not its top/bottom edge: `pdf-info-gettext' maps
a quad's top edge to the line above and its bottom edge to the line
below, which otherwise pulls in adjacent un-highlighted text."
  (when quads
    (let* ((lines (pdfnote--group-lines quads))
           (top-line (car lines))
           (bot-line (car (last lines)))
           (p1-left (apply #'min (mapcar (lambda (q) (nth 0 q)) top-line)))
           (p2-right (apply #'max (mapcar (lambda (q) (nth 2 q)) bot-line)))
           (p1-y (pdfnote--line-center top-line))
           (p2-y (pdfnote--line-center bot-line)))
      (ignore-errors
        (pdf-info-gettext page (list p1-left p1-y p2-right p2-y)
                          pdfnote-selection-style file)))))

(defun pdfnote--color-name (hex)
  "Snap HEX (\"#rrggbb\") to the nearest name in `pdfnote-color-palette'."
  (if (and (stringp hex) (string-match-p "\\`#[0-9a-fA-F]\\{6\\}\\'" hex))
      (cl-loop with r = (string-to-number (substring hex 1 3) 16)
               with g = (string-to-number (substring hex 3 5) 16)
               with b = (string-to-number (substring hex 5 7) 16)
               for (name . h) in pdfnote-color-palette
               for pr = (string-to-number (substring h 1 3) 16)
               for pg = (string-to-number (substring h 3 5) 16)
               for pb = (string-to-number (substring h 5 7) 16)
               for d = (+ (expt (- r pr) 2) (expt (- g pg) 2) (expt (- b pb) 2))
               with best = nil with bestd = nil
               when (or (null bestd) (< d bestd)) do (setq best name bestd d)
               finally return best)
    (or hex "")))

(defun pdfnote--quads-adjacent-p (as bs)
  "Non-nil if any quad in AS is on the same line as, and horizontally
touching or overlapping, some quad in BS.  This is the signature of a
single visual highlight the reader split into separate annotations."
  (cl-some
   (lambda (a)
     (let ((line-tol (* 0.6 (pdfnote--quad-height a))))
       (cl-some
        (lambda (b)
          (and (< (abs (- (nth 1 a) (nth 1 b))) line-tol)   ; same line
               ;; horizontal gap (negative => overlap); < ~2 spaces => adjacent
               (< (max (- (nth 0 b) (nth 2 a))
                       (- (nth 0 a) (nth 2 b)))
                  0.03)))
        bs)))
   as))

(defun pdfnote--coalesce (records)
  "Merge same-page, same-color, spatially-adjacent RECORDS to a fixpoint.
Each record is a plist carrying at least :page :color :quads :note (all
keys present so `plist-put' mutates in place).  Pools quads and joins
notes of merged records."
  (let ((groups (mapcar #'copy-sequence records))
        (changed t))
    (while changed
      (setq changed nil)
      (cl-block scan
        (dotimes (i (length groups))
          (cl-loop for j from (1+ i) below (length groups) do
                   (let ((a (nth i groups)) (b (nth j groups)))
                     (when (and (= (plist-get a :page) (plist-get b :page))
                                (equal (plist-get a :color) (plist-get b :color))
                                (pdfnote--quads-adjacent-p (plist-get a :quads)
                                                           (plist-get b :quads)))
                       (plist-put a :quads (append (plist-get a :quads)
                                                   (plist-get b :quads)))
                       (let ((na (plist-get a :note)) (nb (plist-get b :note)))
                         (when nb
                           (plist-put a :note
                                      (string-trim (concat (or na "") (if na " " "") nb)))))
                       (setq groups (append (cl-subseq groups 0 j)
                                            (cl-subseq groups (1+ j)))
                             changed t)
                       (cl-return-from scan))))))
      )
    groups))

(defun pdfnote--annotations (pdf)
  "Return the exported annotations of PDF as a sorted list of plists.
Each plist has :type :page :color :text :note :top :left.  Contiguous
same-color markup annotations are coalesced into one logical highlight
first.  Requires the epdfinfo server (pdf-tools) but does not open a
pdf-view buffer."
  (require 'pdf-info)
  (let* ((file (expand-file-name pdf))
         (raw (ignore-errors (pdf-info-getannots nil file)))
         records)
    ;; 1. Collect exported annotations as records (all keys present).
    (dolist (a raw)
      (let ((type (cdr (assq 'type a))))
        (when (memq type pdfnote-annotation-types)
          (let* ((edges (cdr (assq 'edges a)))
                 (markup (memq type '(highlight underline strike-out squiggly)))
                 (contents (cdr (assq 'contents a))))
            (push (list :type type
                        :page (cdr (assq 'page a))
                        :color (cdr (assq 'color a))
                        :edges edges
                        :quads (when markup
                                 (or (cdr (assq 'markup-edges a))
                                     (and edges (list edges))))
                        :note (and (stringp contents)
                                   (not (string-empty-p (string-trim contents)))
                                   (pdfnote--reflow contents)))
                  records)))))
    ;; 2. Coalesce contiguous markup; note-only annotations pass through.
    (let* ((markups (cl-remove-if-not (lambda (r) (plist-get r :quads)) records))
           (notes   (cl-remove-if     (lambda (r) (plist-get r :quads)) records))
           (groups  (append (pdfnote--coalesce markups) notes))
           result)
      ;; 3. Extract text and build the final plists.
      (dolist (g groups)
        (let* ((quads (plist-get g :quads))
               (edges (plist-get g :edges))
               (text (and quads (pdfnote--reflow
                                 (pdfnote--region-text file (plist-get g :page) quads)))))
          (push (list :type (plist-get g :type)
                      :page (plist-get g :page)
                      :color (plist-get g :color)
                      :text text
                      :note (plist-get g :note)
                      :top (if quads (apply #'min (mapcar (lambda (q) (nth 1 q)) quads))
                             (nth 1 edges))
                      :left (if quads (apply #'min (mapcar (lambda (q) (nth 0 q)) quads))
                              (nth 0 edges)))
                result)))
      ;; 4. Reading order: page, then top (line), then left.
      (sort (nreverse result)
            (lambda (x y)
              (let ((px (plist-get x :page)) (py (plist-get y :page)))
                (cond
                 ((/= px py) (< px py))
                 ((> (abs (- (plist-get x :top) (plist-get y :top))) 0.008)
                  (< (plist-get x :top) (plist-get y :top)))
                 (t (< (plist-get x :left) (plist-get y :left))))))))))

;;;; Naming / links

(defun pdfnote--slug (pdf)
  "Return the notes slug for PDF (its basename without extension)."
  (file-name-sans-extension (file-name-nondirectory pdf)))

(defun pdfnote--page-file (pdf)
  "Return the absolute notes file path for PDF."
  (if pdfnote-page-file-function
      (funcall pdfnote-page-file-function pdf)
    (expand-file-name (concat pdfnote-file-prefix (pdfnote--slug pdf) ".org")
                      pdfnote-pages-directory)))

(defun pdfnote--asset-link (pdf)
  "Return the page-relative link string pointing at PDF."
  (concat (file-name-as-directory pdfnote-asset-link-directory)
          (file-name-nondirectory pdf)))

;;;; Rendering

(defun pdfnote--render-annotation (a link)
  "Render annotation plist A as an Org block backlinking via LINK."
  (let* ((page (plist-get a :page))
         (type (plist-get a :type))
         (text (plist-get a :text))
         (note (plist-get a :note))
         (label (if (memq type '(text free-text))
                    "note"
                  (pdfnote--color-name (plist-get a :color)))))
    (concat
     (format "** p.%d · %s\n" page label)
     (if (and text (not (string-empty-p text)))
         (format "\"%s\"\n" text)
       "")
     (if note (format "NOTE: %s\n" note) "")
     (format "[[pdf:%s::%d][open @ p.%d]]\n" link page page))))

(defun pdfnote--render (pdf annots)
  "Render the managed highlights section for PDF from ANNOTS."
  (let* ((link (pdfnote--asset-link pdf))
         (title (pdfnote--slug pdf))
         (n (length annots)))
    (concat
     (format "* [[%s][%s]] — %d highlight%s\n" link title n (if (= n 1) "" "s"))
     (mapconcat (lambda (a) (pdfnote--render-annotation a link)) annots "\n"))))

(defun pdfnote--compose (pdf annots user-block)
  "Return the full notes-file contents for PDF.
ANNOTS is the annotation list; USER-BLOCK is preserved trailing text
\(or nil for a fresh empty user section)."
  (let ((link (pdfnote--asset-link pdf)))
    (concat
     ":PROPERTIES:\n"
     (format ":title: %s\n" (concat pdfnote-file-prefix (pdfnote--slug pdf)))
     (format ":pdfnote-source: %s\n" link)
     (format ":pdfnote-synced: %s\n" (format-time-string "[%Y-%m-%d %a %H:%M]"))
     (format ":pdfnote-count: %d\n" (length annots))
     ":END:\n"
     (format "file:: %s\n\n" link)
     (pdfnote--render pdf annots)
     "\n"
     (or user-block (format "* %s\n" pdfnote-user-heading)))))

;;;; Sync

(defun pdfnote--user-block (file)
  "Return the user-owned region of FILE, or nil if none/absent."
  (when (file-exists-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (when (re-search-forward
             (format "^\\* %s\\(?:[ \t]\\|$\\)" (regexp-quote pdfnote-user-heading))
             nil t)
        (buffer-substring-no-properties (line-beginning-position) (point-max))))))

(defun pdfnote--managed-p (file)
  "Return non-nil if FILE was generated by pdfnote."
  (when (file-exists-p file)
    (with-temp-buffer
      (insert-file-contents file nil 0 1000)
      (goto-char (point-min))
      (re-search-forward "^:pdfnote-source:" nil t))))

(defun pdfnote--sync-1 (pdf &optional force)
  "Sync one PDF.  Return a plist (:file :count :status).
STATUS is `written', `no-annotations', or `refused-unmanaged'.
With FORCE, overwrite a page even if it is not pdfnote-managed."
  (let* ((pdf (expand-file-name pdf))
         (annots (pdfnote--annotations pdf))
         (file (pdfnote--page-file pdf)))
    (cond
     ((null annots)
      (list :file file :count 0 :status 'no-annotations))
     ((and (file-exists-p file) (not (pdfnote--managed-p file)) (not force))
      (list :file file :count (length annots) :status 'refused-unmanaged))
     (t
      (let ((user (pdfnote--user-block file)))
        (make-directory (file-name-directory file) t)
        (with-temp-file file
          (insert (pdfnote--compose pdf annots user)))
        (list :file file :count (length annots) :status 'written))))))

;;;###autoload
(defun pdfnote-sync-file (pdf &optional force)
  "Sync a single PDF's native annotations into its Org notes page.
With prefix arg FORCE, overwrite even a non-pdfnote-managed page."
  (interactive
   (list (read-file-name "PDF: " (file-name-as-directory pdfnote-assets-directory)
                         nil t nil
                         (lambda (n) (or (file-directory-p n)
                                         (string-suffix-p ".pdf" (downcase n)))))
         current-prefix-arg))
  (let ((r (pdfnote--sync-1 pdf force)))
    (pcase (plist-get r :status)
      ('written
       (message "pdfnote: wrote %d highlight%s → %s"
                (plist-get r :count) (if (= 1 (plist-get r :count)) "" "s")
                (abbreviate-file-name (plist-get r :file))))
      ('no-annotations
       (message "pdfnote: no exportable annotations in %s"
                (file-name-nondirectory pdf)))
      ('refused-unmanaged
       (message "pdfnote: %s exists and is not pdfnote-managed; C-u to force"
                (abbreviate-file-name (plist-get r :file)))))
    r))

;;;###autoload
(defun pdfnote-sync-buffer (&optional force)
  "Sync the PDF visited by the current buffer (e.g. a pdf-view buffer)."
  (interactive "P")
  (let ((f (buffer-file-name)))
    (unless (and f (string-suffix-p ".pdf" (downcase f)))
      (user-error "Current buffer is not visiting a PDF"))
    (pdfnote-sync-file f force)))

;;;###autoload
(defun pdfnote-sync-all (&optional force)
  "Sync every annotated PDF in `pdfnote-assets-directory'.
Return the list of written files."
  (interactive "P")
  (let ((pdfs (directory-files pdfnote-assets-directory t "\\.pdf\\'"))
        (written 0) (empty 0) (refused 0) files)
    (dolist (pdf pdfs)
      (let ((r (ignore-errors (pdfnote--sync-1 pdf force))))
        (pcase (and r (plist-get r :status))
          ('written (cl-incf written) (push (plist-get r :file) files))
          ('refused-unmanaged (cl-incf refused))
          (_ (cl-incf empty)))))
    (message "pdfnote: %d written, %d without annotations, %d refused (unmanaged)"
             written empty refused)
    (nreverse files)))

;;;###autoload
(defun pdfnote-preview (pdf)
  "Show the notes page pdfnote would generate for PDF, without writing."
  (interactive
   (list (read-file-name "PDF: " (file-name-as-directory pdfnote-assets-directory)
                         nil t nil
                         (lambda (n) (or (file-directory-p n)
                                         (string-suffix-p ".pdf" (downcase n)))))))
  (let* ((pdf (expand-file-name pdf))
         (annots (pdfnote--annotations pdf))
         (file (pdfnote--page-file pdf))
         (buf (get-buffer-create "*pdfnote preview*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (pdfnote--compose pdf annots (pdfnote--user-block file)))
        ;; Anchor to the pages dir so `../assets/...' links resolve even
        ;; though this preview buffer is not visiting a file.
        (setq default-directory (file-name-as-directory pdfnote-pages-directory))
        (when (fboundp 'org-mode) (delay-mode-hooks (org-mode)))
        (goto-char (point-min))))
    (pop-to-buffer buf)
    (message "pdfnote: %d annotation%s → %s"
             (length annots) (if (= 1 (length annots)) "" "s")
             (abbreviate-file-name file))))

;;;###autoload
(defun pdfnote-visit-notes (&optional pdf)
  "Open the notes page for PDF (or the current PDF buffer), syncing first
if it does not yet exist."
  (interactive)
  (let* ((pdf (or pdf (buffer-file-name)))
         (file (and pdf (pdfnote--page-file pdf))))
    (unless (and pdf (string-suffix-p ".pdf" (downcase pdf)))
      (user-error "Not visiting a PDF"))
    (unless (file-exists-p file) (pdfnote-sync-file pdf))
    (find-file file)))

;;;; Backlink: the `pdf:' Org link type

(defun pdfnote--resolve-link-path (path)
  "Resolve a possibly-relative asset PATH from a `pdf:' link to a file.
Links are authored relative to a notes page in `pdfnote-pages-directory'
\(e.g. \"../assets/foo.pdf\"), so relative paths resolve against the
visited notes file's directory when available, else against
`pdfnote-pages-directory' -- which matters when following a link from
the unsaved `*pdfnote preview*' buffer, where `buffer-file-name' is nil
and `default-directory' would otherwise mislead.  Falls back to the
basename under `pdfnote-assets-directory'."
  (if (file-name-absolute-p path)
      path
    (let* ((base (if buffer-file-name
                     (file-name-directory buffer-file-name)
                   (file-name-as-directory pdfnote-pages-directory)))
           (candidates
            (list (expand-file-name path base)
                  (expand-file-name path (file-name-as-directory
                                          pdfnote-pages-directory))
                  (expand-file-name (file-name-nondirectory path)
                                    (file-name-as-directory
                                     pdfnote-assets-directory)))))
      (or (seq-find #'file-exists-p candidates)
          (car candidates)))))

;;;###autoload
(defun pdfnote-follow-link (link &optional _arg)
  "Follow a `pdf:PATH::PAGE' Org LINK by opening PATH at PAGE in pdf-tools."
  (require 'pdf-tools)
  (let* ((parts (split-string link "::"))
         (path (pdfnote--resolve-link-path (car parts)))
         (page (and (cadr parts) (string-to-number (cadr parts)))))
    (find-file path)
    (when (and page (> page 0) (derived-mode-p 'pdf-view-mode))
      (pdf-view-goto-page page))))

(with-eval-after-load 'org
  (org-link-set-parameters "pdf" :follow #'pdfnote-follow-link))

(provide 'pdfnote)
;;; pdfnote.el ends here
