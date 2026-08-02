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

  (add-to-list 'brushup-styles
               '(set-face-attribute
                 'org-remark-highlighter nil
                 :background brushup-bg-2
                 :underline brushup-bg-4
                 ))

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

  :bind (("C-c n m" . org-remark-mark-default)
         ("C-c n l" . org-remark-mark-line)
         :map org-remark-mode-map
         ("C-c n o" . org-remark-open)
         ("C-c n ]" . org-remark-view-next)
         ("C-c n [" . org-remark-view-prev)
         ("C-c n r" . org-remark-remove)
         ("C-c n d" . org-remark-delete)))
;;; org-remark.el ends here
