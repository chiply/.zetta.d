;;; org-remark.el --- Configure org-remark -*- lexical-binding: t; -*-

;; TODO cleanup my-org-remark-notes-file-name

(use-package org-remark
  :demand t
  :after org

  :config
  (require 'org-remark-global-tracking)
  (org-remark-global-tracking-mode +1)

  (defun my-org-remark-transform-org-link-to-filename ()
    (let ((link-parts (split-string (org-store-link nil) "\\]\\[")))
      (string-replace
       "#" ""
       (concat
        (nth 1 (split-string (nth 0 link-parts) "\\[\\["))
        ": "
        (nth 0 (split-string (nth 1 link-parts) "\\]\\]"))))))

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
      (my-org-remark-transform-org-link-to-filename)))

  (defun org-remark-elfeed-highlight-link-to-source (filename _point)
    (when (equal major-mode 'elfeed-show-mode)
      (org-store-link nil)))

  ;; NOTE to appease logseq
  (defun my-org-remark-sanitize-notes-file-name (filename)
    (string-replace
     "?" "%3F"
     (string-replace
      ":" "--"
      (string-replace
       "/" "--"
       filename))))

  (defun my-org-remark-notes-file-name-url (url)
    (my-org-remark-sanitize-notes-file-name
     (let ((url-parsed (url-generic-parse-url url)))
       (concat
        (url-host url-parsed)
        (url-filename url-parsed)
        "-annotations.org"))))

  ;; TODO cleanup references to logseq dir, maybe use a directory
  (defun my-org-remark-notes-file-name ()
    (cond
     ;; Logseq files
     ((and buffer-file-name
           (string-match-p (expand-file-name "~/logseq/graphs/") buffer-file-name))
      (concat (file-name-sans-extension buffer-file-name) "-annotations.org"))
     ;; Elfeed
     ((eq major-mode 'elfeed-show-mode)
      (message "major mode is elfeed-show-mode")
      (expand-file-name
       (concat
        "~/logseq/pages/(highlights elfeed) "
        (let ((link-parts (split-string (org-store-link nil) "\\]\\[")))
          (my-org-remark-sanitize-notes-file-name
           (concat (nth 0 (split-string (nth 1 link-parts) "\\]\\]"))
                   "-annotations.org"))))))
     ;; Wombag
     ((eq major-mode 'wombag-show-mode)
      (expand-file-name
       (concat
        "~/logseq/pages/(highlights wombag) "
        (my-org-remark-notes-file-name-url
         (alist-get 'url wombag-show-entry)))))
     ;; Wombag
     ((eq major-mode 'pubmed-show-mode)
      (expand-file-name
       (concat
        "~/logseq/pages/(highlights pubmed) "
        (my-org-remark-notes-file-name-url
         (pubmed-extract-pmid)))))
     ;; Eww
     ((eq major-mode 'eww-mode)
      (expand-file-name
       (concat
        "~/logseq/pages/(highlights eww) "
        (my-org-remark-notes-file-name-url
         (eww-current-url)))))
     ;; if it is a file
     (buffer-file-name "marginalia.org")
     ;; otherwise
     (t (expand-file-name "marginalia.org" user-emacs-directory))))

  (setq org-remark-notes-file-name 'my-org-remark-notes-file-name)

  ;; EWW eww-readable integration
  (defun my-advice-eww-show-mode-org-remark (&rest _args)
    (org-remark-auto-on))

  (advice-add #'eww-readable :after #'my-advice-eww-show-mode-org-remark)

  ;; activate modes
  (org-remark-wombag-mode)
  (org-remark-elfeed-mode)
  (org-remark-pubmed-mode)
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
