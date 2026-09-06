;;; anki.el --- Configure anki.el flashcard reviewer -*- lexical-binding: t; -*-

;; Review Anki decks inside Emacs with anki.el (chenyanming/anki.el).
;; It reads a collection directory (collection.anki2 + collection.media),
;; not .apkg archives, so `zetta-anki-open-apkg' imports an .apkg into
;; `zetta-anki-cache-dir' (one subdir per deck), repairs the
;; system-design-primer's dead camo.githubusercontent.com image links,
;; and starts a review session.  `M-x anki' resumes the current deck.

(require 'hex-util)

(declare-function anki "anki")
(declare-function emacsql-close "emacsql")
(defvar anki-collection-dir)
(defvar anki-search-entries)
(defvar anki-full-entries)
(defvar anki-number)
(defvar anki-core-db-connection)

(defvar zetta-anki-cache-dir (expand-file-name "~/.cache/emacs-anki/")
  "Directory where .apkg archives are extracted, one subdir per deck.")

(defun zetta-anki--emacsql-shim ()
  "Give anki.el the `emacsql-sqlite' constructor it calls.
In emacsql 4.x (installed for forge) the feature `emacsql-sqlite'
still exists — so guard on `fboundp', not `featurep'; forge loads
the feature long before this module runs — but the file defines
`emacsql-sqlite-open' instead of a function named `emacsql-sqlite'.
Alias whichever modern constructor is available."
  (unless (fboundp 'emacsql-sqlite)
    (if (require 'emacsql-sqlite nil t)
        (defalias 'emacsql-sqlite #'emacsql-sqlite-open)
      ;; emacsql 4.0 shipped no emacsql-sqlite.el at all.
      (require 'emacsql-sqlite-builtin)
      (defalias 'emacsql-sqlite #'emacsql-sqlite-builtin)
      (provide 'emacsql-sqlite))))

(defun zetta-anki--repair-media (db-file media-dir)
  "Localize remote card images in DB-FILE into MEDIA-DIR.
anki.el resolves every <img src> against collection.media, so remote
URLs can never render.  Rewrite each remote src (including the
primer's dead camo.githubusercontent.com proxy links, whose hex
payload decodes to the real imgur URL) to a bare filename and
download the image into MEDIA-DIR.  Return (NOTES-CHANGED . FILES)."
  (let ((db (sqlite-open db-file))
        (urls nil)                      ; filename -> source url
        (fixed 0))
    (unwind-protect
        (dolist (row (sqlite-select db "SELECT id, flds FROM notes"))
          (let* ((id (car row))
                 (flds (cadr row))
                 (new (with-temp-buffer
                        (insert flds)
                        ;; Camo proxy links: recover the original URL.
                        (goto-char (point-min))
                        (while (re-search-forward
                                "https?://camo\\.githubusercontent\\.com/[0-9a-f]+/\\([0-9a-f]+\\)"
                                nil t)
                          (replace-match (decode-hex-string (match-string 1))
                                         t t))
                        ;; Any remote src: note it for download, then
                        ;; refer to it by bare filename.
                        (goto-char (point-min))
                        (while (re-search-forward
                                "src=\"\\(https?://[^\"]+/\\([^\"/?]+\\)\\)\""
                                nil t)
                          (let ((url (replace-regexp-in-string
                                      "\\`http://" "https://" (match-string 1)))
                                (name (match-string 2)))
                            (push (cons name url) urls)
                            (replace-match (format "src=\"%s\"" name) t t)))
                        (buffer-string))))
            (unless (equal new flds)
              (sqlite-execute db "UPDATE notes SET flds = ? WHERE id = ?"
                              (list new id))
              (setq fixed (1+ fixed)))))
      (sqlite-close db))
    (let ((files 0))
      (pcase-dolist (`(,name . ,url) (delete-dups urls))
        (let ((target (expand-file-name name media-dir)))
          (unless (file-exists-p target)
            (message "anki: fetching %s..." name)
            (when (ignore-errors (url-copy-file url target) t)
              (setq files (1+ files))))))
      (cons fixed files))))

(defun zetta-anki-open-apkg (apkg)
  "Import APKG into `zetta-anki-cache-dir' and start reviewing it.
An already-imported deck is reused as-is (delete its subdir under
`zetta-anki-cache-dir' to force a fresh import).  Each .apkg is a
separate collection; run this command again to switch decks."
  (interactive
   (list (read-file-name "Open .apkg: " nil nil t nil
                         (lambda (f)
                           (or (file-directory-p f)
                               (string-suffix-p ".apkg" f t))))))
  (zetta-anki--emacsql-shim)
  (require 'anki)
  (let* ((slug (replace-regexp-in-string "[^[:alnum:]]+" "-"
                                         (downcase (file-name-base apkg))))
         (dest (expand-file-name slug zetta-anki-cache-dir))
         (db (expand-file-name "collection.anki2" dest)))
    (unless (file-exists-p db)
      (make-directory dest t)
      (with-temp-buffer
        (unless (zerop (call-process "unzip" nil t nil "-o"
                                     (expand-file-name apkg) "-d" dest))
          (error "unzip failed: %s" (buffer-string))))
      (make-directory (expand-file-name "collection.media" dest) t)
      (pcase-let ((`(,notes . ,files)
                   (zetta-anki--repair-media
                    db (expand-file-name "collection.media" dest))))
        (when (> notes 0)
          (message "anki: localized images in %d notes (%d files fetched)"
                   notes files))))
    (make-directory (expand-file-name "collection.media" dest) t)
    ;; Reset per-collection state so switching decks doesn't leak the
    ;; previous collection's cards or write review history to its db.
    (when (bound-and-true-p anki-core-db-connection)
      (ignore-errors (emacsql-close anki-core-db-connection))
      (setq anki-core-db-connection nil))
    (setq anki-search-entries nil
          anki-full-entries nil
          anki-number 0)
    (setq anki-collection-dir dest)
    (anki)))

(use-package anki
  ;; anki-core.el requires emacsql-sqlite at compile time, which no
  ;; longer exists as a library; skip byte-compilation and rely on the
  ;; runtime shim instead.
  :ensure (:host github :repo "chenyanming/anki.el"
           :build (:not elpaca--byte-compile))
  :commands (anki anki-browser anki-list-decks)
  :init
  (with-eval-after-load 'emacsql (zetta-anki--emacsql-shim))
  :config
  (setq sql-sqlite-program (or (executable-find "sqlite3") "/usr/bin/sqlite3"))
  (setq anki-audio-player (executable-find "afplay")))

;; The review buffers bind plain keys (f, 1-4, n/p, q) on their mode
;; maps; start them in emacs state so evil doesn't shadow them.
(with-eval-after-load 'evil
  (evil-set-initial-state 'anki-mode 'emacs)
  (evil-set-initial-state 'anki-card-mode 'emacs)
  (evil-set-initial-state 'anki-search-mode 'emacs))

(with-eval-after-load 'anki-core
  ;; anki-core-query shells out to the sqlite3 CLI, but sqlite3 >= 3.41
  ;; caret-escapes control characters in its output (terminal-injection
  ;; defense), so the 0x1f field separators inside `flds' arrive as the
  ;; two literal characters "^_".  anki.el then can't split front from
  ;; back and renders the whole note as the question.  Query through the
  ;; built-in sqlite instead, emitting the same separator/newline-
  ;; delimited text the parser expects, with control bytes intact.
  (defun zetta-anki--core-query (sql-query)
    "Run SQL-QUERY on the collection via built-in sqlite."
    (let ((file (expand-file-name "collection.anki2" anki-collection-dir)))
      (when (file-exists-p file)
        (let ((db (sqlite-open file)))
          (unwind-protect
              (mapconcat
               (lambda (row)
                 (mapconcat (lambda (col)
                              (cond ((null col) "")
                                    ((numberp col) (number-to-string col))
                                    (t col)))
                            row anki-core-sql-separator))
               (sqlite-select db sql-query)
               anki-core-sql-newline)
            (sqlite-close db))))))
  (advice-add 'anki-core-query :override #'zetta-anki--core-query))

(with-eval-after-load 'anki-card
  ;; Upstream bug: anki-render-img funcalls this for external image
  ;; URLs, but no code ever defines it.  Capture the real renderer
  ;; here, before anki's cl-letf override is in effect.
  (defvar anki-original-shr-tag-img-function (symbol-function 'shr-tag-img))

  ;; Upstream bug: anki-insert-image destructures with dash's -let*
  ;; without requiring dash, so the shipped definition is broken (and
  ;; compiles to garbage when dash isn't on the build load-path).
  ;; Replace it with a dash-free equivalent.
  (defun anki-insert-image (path alt)
    "Insert the image at PATH, falling back to ALT text."
    (let* ((edges (and (display-images-p)
                       (file-exists-p path)
                       (window-inside-pixel-edges
                        (get-buffer-window (current-buffer) t))))
           (image (and edges
                       (ignore-errors
                         (create-image
                          path nil nil
                          :ascent 100
                          :max-width (truncate (* shr-max-image-proportion
                                                  (- (nth 2 edges) (nth 0 edges))))
                          :max-height (truncate (* shr-max-image-proportion
                                                   (- (nth 3 edges) (nth 1 edges)))))))))
      (if image
          (insert-image image)
        (insert alt)))))
;;; anki.el ends here
