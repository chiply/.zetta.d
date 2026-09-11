;;; org-remark.el --- Configure org-remark -*- lexical-binding: t; -*-

(use-package org-remark
  :demand t
  :after org

  :config
  (require 'org-remark-global-tracking)
  (org-remark-global-tracking-mode +1)

  (defun my-org-remark-transform-org-link-to-filename (&optional link-string)
    "Derive the notes filename from LINK-STRING (default: `org-store-link')."
    (let ((link-parts (split-string (or link-string (org-store-link nil))
                                    "\\]\\[")))
      (string-replace
       "#" ""
       (concat
        (nth 1 (split-string (nth 0 link-parts) "\\[\\["))
        ": "
        (nth 0 (split-string (nth 1 link-parts) "\\]\\]"))))))

  (defun my-org-remark-elfeed-link-string ()
    "Org bracket link for the shown elfeed entry, without `org-store-link'.
Several org link types can store from an elfeed-show buffer, so
`org-store-link' PROMPTS to pick one -- and the org-remark wiring made
that fire on every RET in elfeed-search (and every consult preview).
Builds the same string as elfeed's own store function: link
\"elfeed:FEED-ID#ENTRY-ID\", description the entry title."
    (let ((id (elfeed-entry-id elfeed-show-entry)))
      (org-link-make-string (format "elfeed:%s#%s" (car id) (cdr id))
                            (elfeed-entry-title elfeed-show-entry))))

  ;; wombag.el support
  (define-minor-mode org-remark-wombag-mode
    "Enable Org-remark to work with wombag.el"
    :global t
    :group 'org-remark-wombag
    (if org-remark-wombag-mode
        ;; Enable
        (progn
          (add-hook 'wombag-show-mode-hook #'org-remark-auto-on)
          (add-hook 'org-remark-source-find-file-name-functions
                    #'org-remark-wombag-find-file-name)
          (add-hook 'org-remark-highlight-link-to-source-functions
                    #'org-remark-wombag-highlight-link-to-source))
      ;; Disable
      (remove-hook 'wombag-show-mode-hook #'org-remark-auto-on)
      (remove-hook 'org-remark-source-find-file-name-functions
                   #'org-remark-wombag-find-file-name)
      (remove-hook 'org-remark-highlight-link-to-source-functions
                   #'org-remark-wombag-highlight-link-to-source)))

  (defun org-remark-wombag-find-file-name ()
    (when (equal major-mode 'wombag-show-mode)
      (my-org-remark-transform-org-link-to-filename)))

  (defun org-remark-wombag-highlight-link-to-source (filename _point)
    (when (equal major-mode 'wombag-show-mode) (org-store-link nil)))

  ;; pubmed.el support
  (define-minor-mode org-remark-pubmed-mode
    "Enable Org-remark to work with pubmed.el"
    :global t
    :group 'org-remark-pubmed
    (if org-remark-pubmed-mode
        ;; Enable
        (progn
          (add-hook 'pubmed-show-mode-hook #'org-remark-auto-on)
          (add-hook 'org-remark-source-find-file-name-functions
                    #'org-remark-pubmed-find-file-name)
          (add-hook 'org-remark-highlight-link-to-source-functions
                    #'org-remark-pubmed-highlight-link-to-source))
      ;; Disable
      (remove-hook 'pubmed-show-mode-hook #'org-remark-auto-on)
      (remove-hook 'org-remark-source-find-file-name-functions
                   #'org-remark-pubmed-find-file-name)
      (remove-hook 'org-remark-highlight-link-to-source-functions
                   #'org-remark-pubmed-highlight-link-to-source)))

  (defun org-remark-pubmed-find-file-name ()
    (when (equal major-mode 'pubmed-show-mode)
      (my-org-remark-transform-org-link-to-filename)))

  (defun org-remark-pubmed-highlight-link-to-source (filename _point)
    (when (equal major-mode 'pubmed-show-mode) (org-store-link nil)))

  ;; elfeed.el support
  (define-minor-mode org-remark-elfeed-mode
    "Enable Org-remark to work with elfeed.el"
    :global t
    :group 'org-remark-elfeed
    (if org-remark-elfeed-mode
        ;; Enable
        (progn
          (add-hook 'org-remark-source-find-file-name-functions
                    #'org-remark-elfeed-find-file-name)
          (add-hook 'org-remark-highlight-link-to-source-functions
                    #'org-remark-elfeed-highlight-link-to-source))
      ;; Disable
      (remove-hook 'org-remark-source-find-file-name-functions
                   #'org-remark-elfeed-find-file-name)
      (remove-hook 'org-remark-highlight-link-to-source-functions
                   #'org-remark-elfeed-highlight-link-to-source)))

  (defun my-advice-elfeed-show-mode-org-remark (&rest _args)
    (org-remark-auto-on))

  (advice-add #'elfeed-show-entry
              :after #'my-advice-elfeed-show-mode-org-remark)

  (defun org-remark-elfeed-find-file-name ()
    (when (equal major-mode 'elfeed-show-mode)
      (my-org-remark-transform-org-link-to-filename
       (my-org-remark-elfeed-link-string))))

  (defun org-remark-elfeed-highlight-link-to-source (_filename _point)
    (when (equal major-mode 'elfeed-show-mode)
      (my-org-remark-elfeed-link-string)))

  ;; mu4e support
  (defun my-org-remark-mu4e-link-string ()
    "Org bracket link for the viewed mu4e message, without `org-store-link'.
Message-ids are stable across re-syncs (unlike maildir paths, which
Gmail moves around), so they make a durable source identity."
    (let ((msg (mu4e-message-at-point)))
      (org-link-make-string
       (concat "mu4e:msgid:" (plist-get msg :message-id))
       (or (plist-get msg :subject) "No subject"))))

  (define-minor-mode org-remark-mu4e-mode
    "Enable Org-remark to work with mu4e's article view."
    :global t
    :group 'org-remark-mu4e
    (if org-remark-mu4e-mode
        ;; Enable
        (progn
          (add-hook 'mu4e-view-rendered-hook #'org-remark-auto-on)
          (add-hook 'org-remark-source-find-file-name-functions
                    #'org-remark-mu4e-find-file-name)
          (add-hook 'org-remark-highlight-link-to-source-functions
                    #'org-remark-mu4e-highlight-link-to-source))
      ;; Disable
      (remove-hook 'mu4e-view-rendered-hook #'org-remark-auto-on)
      (remove-hook 'org-remark-source-find-file-name-functions
                   #'org-remark-mu4e-find-file-name)
      (remove-hook 'org-remark-highlight-link-to-source-functions
                   #'org-remark-mu4e-highlight-link-to-source)))

  (defun org-remark-mu4e-find-file-name ()
    (when (equal major-mode 'mu4e-view-mode)
      (my-org-remark-transform-org-link-to-filename
       (my-org-remark-mu4e-link-string))))

  (defun org-remark-mu4e-highlight-link-to-source (_filename _point)
    (when (equal major-mode 'mu4e-view-mode)
      (my-org-remark-mu4e-link-string)))

  ;; Notes land in the synced kb tree, mirroring the readwise layout
  ;; (<source>/<middle-dimension>/<title-slug>.org) where it makes sense.
  (defvar my-org-remark-directory (expand-file-name "~/kb/org-remark/")
    "Root for org-remark notes files, inside the synced kb tree.")

  (defun my-org-remark-slugify (s &optional maxlen)
    "Lowercase-hyphenate S readwise-style; never empty."
    (let ((slug (string-trim (replace-regexp-in-string
                              "[^a-z0-9]+" "-" (downcase (or s "")))
                             "-+" "-+")))
      (if (string-empty-p slug)
          "untitled"
        (substring slug 0 (min (length slug) (or maxlen 80))))))

  (defun my-org-remark-url-notes-path (subdir url)
    "Notes path for URL under SUBDIR: <subdir>/<host>/<path-slug>.org."
    (let* ((u (url-generic-parse-url url))
           (host (or (url-host u) "unknown"))
           (path-slug (my-org-remark-slugify (url-filename u))))
      (expand-file-name
       (concat subdir "/" host "/"
               (if (string= path-slug "untitled") "index" path-slug)
               ".org")
       my-org-remark-directory)))

  (defun my-org-remark-notes-file-name ()
    (cond
     ;; mu4e: sender domain is the middle dimension
     ((eq major-mode 'mu4e-view-mode)
      (let* ((msg (mu4e-message-at-point))
             (from (mu4e-contact-email (car (mu4e-message-field msg :from))))
             (domain (or (cadr (split-string (or from "") "@")) "unknown")))
        (expand-file-name
         (concat "mail/" domain "/"
                 (my-org-remark-slugify (mu4e-message-field msg :subject))
                 ".org")
         my-org-remark-directory)))
     ;; Elfeed: feed domain is the middle dimension
     ((eq major-mode 'elfeed-show-mode)
      (let* ((id (elfeed-entry-id elfeed-show-entry))
             (feed-host (or (url-host (url-generic-parse-url (car id)))
                            "unknown")))
        (expand-file-name
         (concat "elfeed/" feed-host "/"
                 (my-org-remark-slugify (elfeed-entry-title elfeed-show-entry))
                 ".org")
         my-org-remark-directory)))
     ;; Wombag / Eww: page domain is the middle dimension
     ((eq major-mode 'wombag-show-mode)
      (my-org-remark-url-notes-path "wombag" (alist-get 'url wombag-show-entry)))
     ((eq major-mode 'eww-mode)
      (my-org-remark-url-notes-path "eww" (eww-current-url)))
     ;; Pubmed: pmid is already a unique flat id
     ((eq major-mode 'pubmed-show-mode)
      (expand-file-name (concat "pubmed/" (pubmed-extract-pmid) ".org")
                        my-org-remark-directory))
     ;; Info manuals: one notes file per manual
     ((eq major-mode 'Info-mode)
      (expand-file-name
       (concat "info/"
               (my-org-remark-slugify
                (file-name-sans-extension
                 (file-name-nondirectory Info-current-file)))
               ".org")
       my-org-remark-directory))
     ;; Epubs via nov.el
     ((eq major-mode 'nov-mode)
      (expand-file-name
       (concat "books/"
               (my-org-remark-slugify
                (file-name-sans-extension (file-name-nondirectory nov-file-name)))
               ".org")
       my-org-remark-directory))
     ;; kb's own notes: annotations live next to the file they annotate
     ((and buffer-file-name
           (string-prefix-p (expand-file-name "~/kb/") buffer-file-name))
      (concat (file-name-sans-extension buffer-file-name) "-annotations.org"))
     ;; any other file: marginalia.org in the file's own directory
     (buffer-file-name "marginalia.org")
     ;; otherwise: synced catch-all
     (t (expand-file-name "marginalia.org" my-org-remark-directory))))

  (setq org-remark-notes-file-name 'my-org-remark-notes-file-name)

  ;; The first highlight in a new domain hits two prompts: auto-on's
  ;; load path already visited the (nonexistent) notes file while its
  ;; parent directory didn't exist, so at highlight time the revisit
  ;; inside find-file-noselect sees file-writable-p nil → "read-only
  ;; on disk.  Make buffer read-only, too?", and then save-buffer asks
  ;; to create the directory.  Create the directory when a highlight
  ;; is actually MADE — not in the notes-file-name function, which the
  ;; load path calls for every page render and would litter the synced
  ;; kb with empty per-domain dirs for pages never highlighted.
  (defun my-org-remark-ensure-notes-dir (&rest _)
    "Create the notes file's directory before a highlight is saved."
    (when-let* ((path (org-remark-notes-get-file-name))
                (dir (file-name-directory path)))
      (unless (file-directory-p dir)
        (make-directory dir t))))
  (advice-add 'org-remark-highlight-mark :before #'my-org-remark-ensure-notes-dir)

  ;; EWW eww-readable integration
  (defun my-advice-eww-show-mode-org-remark (&rest _args)
    (org-remark-auto-on))

  (advice-add #'eww-readable :after #'my-advice-eww-show-mode-org-remark)

  ;; activate modes
  (org-remark-wombag-mode)
  (org-remark-elfeed-mode)
  (org-remark-pubmed-mode)
  (org-remark-mu4e-mode)
  (use-package org-remark-info :ensure nil :after info
    :config (org-remark-info-mode +1))
  (use-package org-remark-eww  :ensure nil :after eww
    :config (org-remark-eww-mode +1))
  (use-package org-remark-nov  :ensure nil :after nov
    :config (org-remark-nov-mode +1))

  (when (display-graphic-p)
    (setq org-remark-icon-notes
          (all-the-icons-file-icons "org"
                                    :face 'all-the-icons-blue
                                    :v-adjust 0.0
                                    :height 1.0)))

  ;; symbol-overlay's overlays sit at priority 90 (set in
  ;; modules/ui/symbol-overlay.el), while org-remark's carry none —
  ;; so symbol highlights painted over remark highlights.  The remark
  ;; highlight should win; 95 outranks symbol-overlay but org-remark
  ;; has no overlay keymap, so symbol-overlay's keys still work inside
  ;; a highlight.
  (defun zetta-org-remark--bump-priority (ov)
    (when (overlayp ov) (overlay-put ov 'priority 95))
    ov)
  (advice-add 'org-remark-highlight-make-overlay :filter-return
              #'zetta-org-remark--bump-priority)

  ;; custom pens
  (defun my/org-remark-get-date ()
    (let* ((day (string-to-number (format-time-string "%e")))
           (suffix (cond
                    ((and (> day 10) (< day 20)) "th") ; Special case for 11th, 12th, 13th
                    ((= (mod day 10) 1) "st")
                    ((= (mod day 10) 2) "nd")
                    ((= (mod day 10) 3) "rd")
                    (t "th")))
           (month-year (format-time-string "%b, %Y"))
           (date (format "%s %d%s, %s"
                         (format-time-string "%b")
                         day
                         suffix
                         (format-time-string "%Y"))))
      (concat "[[" date "]]")))

  (org-remark-create "default"
                     'org-remark-highlighter
                     `(
                       CATEGORY "important"
                       ;; can see a nice historical link... this also
                       ;; integrates with logseq's date formats.
                       ;; readwise also stores these kinds of date
                       ;; links in its highlights... Note the macro
                       ;; treats this dynamically, so we will get a
                       ;; new date every day
                       org-remark-highlight-date ,(my/org-remark-get-date)))

  ;; The one semantic pen beyond the generic default.  "question" marks
  ;; brush-up-on-this-later passages in study guides, and carries the
  ;; same date-link property as the default pen.
  ;;
  ;; There were three pens for a while, with an "important" pen between
  ;; these two, and two of the three could not be told apart.  A pen in
  ;; prose has nothing but its own appearance to say which one it is --
  ;; no letter, no glyph, no counts -- where the gutter marker, the modal
  ;; badge and the flycheck pill can all leave colour to encode
  ;; prominence alone because their shape or label has already named
  ;; them.  Two slabs both far enough off the page to read as inverted
  ;; are a couple of ladder rungs apart at most, and at that distance
  ;; they read as one mark drawn twice.  Ruling one of them was the other
  ;; way out and cost more than it returned: an overline is a single
  ;; hairline on the NS port (`ns_draw_text_decoration\=' fills one pixel
  ;; at the top of the row and ignores `overline-margin\='), and a box band
  ;; is a lot of furniture to carry one bit.  A wash and a slab need no
  ;; vocabulary at all.
  ;;
  ;; Highlights already made with the dropped pen still load:
  ;; `org-remark-highlight-load\=' falls back to `org-remark-mark\=' when a
  ;; stored label has no pen behind it, so they come back as regular
  ;; marks.
  ;;
  ;; The defface spec below is a cold-start fallback only -- the live
  ;; colours come from `zetta-org-remark-refresh-pens\=', off the theme's
  ;; own palette.
  (defface zetta-org-remark-question-face
    '((((background light)) :background "#353535" :foreground "#ffffff")
      (t :background "#b0b0b0" :foreground "#101010"))
    "Highlight for the org-remark question pen.")

  (defvar zetta-org-remark-question-rung 'brushup-fg-3
    "Ink-ladder rung the question pen fills its slab with.

The pen inverts the page: this rung fills, and the text is whatever reads
on it (`zetta-readable-on\='), so a marked passage comes out as a slab of
the theme\='s own ink rather than a tint the reader has to be told how to
decode.

Not the full foreground.  A slab at `brushup-fg\=' is the page inverted
outright -- 21:1 on a black-on-white theme -- a hard edge to read a
paragraph through, and louder than a highlight needs to be.  A few rungs
down still reads as inverted and stops shouting.

A symbol, not a colour: it is resolved per call, after a theme change has
rewritten the palette.")

  (defun zetta-org-remark-refresh-pens ()
    "Re-tint the org-remark pen faces from the current theme.

The default pen is the plain one -- `brushup-bg-2\=' filled, `brushup-bg-4\='
underlined, no hue at all.  It is the one in constant use, so it stays a
wash the text reads straight through, about what a marked region looks
like, and it sits a step down the gradient from
`symbol-overlay-default-face\=' (see modules/ui/symbol-overlay.el), the
other faint wash that turns up in the same buffers.

The question pen inverts instead, off the ink ladder at
`zetta-org-remark-question-rung\='.  Both pens used to carry a hue --
warning for question, accent for important, each washed down to the
weight of the default fill.  That asked the reader to decode a colour
vocabulary nobody had told them, and it had nothing to offer a
deliberately monochrome theme, where the two washed out to the same grey.
A wash and a slab need no vocabulary.

Every attribute is written on each refresh rather than left alone,
because `set-face-attribute\=' only writes what it is handed: a session
already running on an older shape of this pen would otherwise keep its
box, overline or underline under the new fill."
    (when (fboundp 'zetta-readable-on)
      (when (facep 'org-remark-highlighter)
        (set-face-attribute 'org-remark-highlighter nil
                            :background brushup-bg-2
                            :underline `(:color ,brushup-bg-4)))
      (when (and (facep 'zetta-org-remark-question-face)
                 (boundp zetta-org-remark-question-rung))
        (let* ((fill (symbol-value zetta-org-remark-question-rung))
               (ink (zetta-readable-on fill)))
          (set-face-attribute 'zetta-org-remark-question-face nil
                              :background fill
                              :foreground ink
                              :box nil
                              :overline nil
                              :underline nil
                              :weight 'unspecified
                              :inverse-video nil)))))

  ;; APPENDED, not prepended.  `brushup-init\=' -- which recomputes
  ;; brushup-bg and the gradient from the newly enabled theme -- sits
  ;; near the END of `brushup-styles\=', so a prepended entry reads the
  ;; PREVIOUS theme\='s palette.  Registering it at all is the fix for the
  ;; pens being tinted exactly once, at load: a session that started on
  ;; a dark theme and switched to a light one was left painting dark
  ;; teal and olive washes across a white page.
  (add-to-list 'brushup-styles '(zetta-org-remark-refresh-pens) t)
  (zetta-org-remark-refresh-pens)

  (org-remark-create "question"
                     'zetta-org-remark-question-face
                     `(CATEGORY "question"
                       org-remark-highlight-date ,(my/org-remark-get-date)))


  ;; Re-pen the highlight at point: prompts with the OTHER pens only
  ;; (upstream org-remark-change includes the current one and offers
  ;; raw function names).  With two pens that is one candidate either
  ;; way: promote default → question, or downgrade question → default
  ;; once groked.
  (defun zetta-org-remark-change-pen ()
    "Switch the pen of the highlight at point, excluding its current pen."
    (interactive)
    (let* ((ov (org-remark-find-dwim))
           (current (and ov (overlay-get ov 'org-remark-label)))
           (type (and ov (overlay-get ov 'org-remark-type))))
      (unless ov (user-error "No highlight at point"))
      (let* ((label-of (lambda (fn)
                         (string-remove-prefix "org-remark-mark-"
                                               (symbol-name fn))))
             ;; upstream registers sample pens (yellow, red-line) and
             ;; the label-less base pen; only offer the deliberate ones
             (noise '("org-remark-mark" "yellow" "red-line"))
             (candidates
              (seq-filter
               (lambda (fn)
                 (let ((label (funcall label-of fn)))
                   (and (eql type (function-get fn 'org-remark-type))
                        (not (string= label current))
                        (not (member label noise)))))
               org-remark-available-pens))
             (table (mapcar (lambda (fn) (cons (funcall label-of fn) fn))
                            candidates))
             (choice (completing-read
                      (format "Change pen (%s → ): " current)
                      table nil t)))
        (org-remark-change (cdr (assoc choice table))))))

  :bind (("C-c n m" . org-remark-mark-default)
         ("C-c n q" . org-remark-mark-question)
         ("C-c n l" . org-remark-mark-line)
         :map org-remark-mode-map
         ("C-c n o" . org-remark-open)
         ("C-c n ]" . org-remark-view-next)
         ("C-c n [" . org-remark-view-prev)
         ("C-c n r" . org-remark-remove)
         ("C-c n d" . org-remark-delete)
         ("C-c n c" . zetta-org-remark-change-pen)))
;;; org-remark.el ends here
